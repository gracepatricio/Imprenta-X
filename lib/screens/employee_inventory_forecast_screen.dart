import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'sales_import_widget.dart' show showSalesImportSheet;

// ─────────────────────────────────────────────────────────────────────────────
// DOUBLE EXPONENTIAL SMOOTHING  — Holt's Linear Trend method
//
//  Phase 1 — Demand Forecasting (per product)
//    Init:   L₁ = X₁   T₁ = X₂ − X₁
//    Level:  Lₜ = α·Xₜ + (1−α)·(Lₜ₋₁ + Tₜ₋₁)
//    Trend:  Tₜ = β·(Lₜ − Lₜ₋₁) + (1−β)·Tₜ₋₁
//    Fore:   F{t+m} = Lₜ + m·Tₜ   (clamped ≥ 0)
//    MAPE  = mean( |Xₜ − Fₜ| / Xₜ ) × 100  over non-zero actuals
//    α, β  auto-selected per product by minimising MAPE (grid search)
//
//  Phase 2 — Dependent Demand (BOM explosion)
//    material_need  = Σ products  F{t+1}(product) × BOM_qty_per_unit
// ─────────────────────────────────────────────────────────────────────────────

// ── Colours ───────────────────────────────────────────────────────────────────
const _navy    = Color(0xFF0F1A2E);
const _rose    = Color(0xFFEF4444);
const _amber   = Color(0xFFB45309);
const _emerald = Color(0xFF10B981);
const _lime    = Color(0xFF65A30D);
const _slate   = Color(0xFF475569);
const _muted   = Color(0x880F172A);
const _border  = Color(0x30000000);


// ── DES algorithm ─────────────────────────────────────────────────────────────

class _DES {
  final double L;      // level  Lₜ at last fitted point
  final double T;      // trend  Tₜ at last fitted point
  final double alpha;
  final double beta;
  final double? mape;
  final List<double> fits;    // one-step-ahead F values for t=2..n
  final List<double> actuals; // corresponding actual X values

  const _DES({
    required this.L, required this.T,
    required this.alpha, required this.beta,
    required this.mape,
    required this.fits, required this.actuals,
  });

  // Forecast m periods ahead from the end of the fitted series.
  double forecast(int m) => math.max(0.0, L + T * m);
}

/// Fit Holt's Linear Trend DES to [series] with given α, β.
/// Leading zeros are trimmed so the model starts at the first real observation.
_DES _fitHolt(List<double> series, double alpha, double beta) {
  final first = series.indexWhere((v) => v > 0.001);
  final data  = first >= 0 ? series.sublist(first) : <double>[];
  final n     = data.length;

  if (n == 0) {
    return _DES(L: 0, T: 0, alpha: alpha, beta: beta,
        mape: null, fits: [], actuals: []);
  }

  double L = data[0];
  double T = n >= 2 ? data[1] - data[0] : 0.0;
  final fits    = <double>[];
  final actuals = <double>[];
  final apes    = <double>[];

  for (int t = 1; t < n; t++) {
    final f  = math.max(0.0, L + T);   // one-step forecast (m = 1)
    final x  = data[t];
    fits.add(f);
    actuals.add(x);
    if (x > 0.001) apes.add(((x - f) / x).abs() * 100.0);
    final lastL = L;
    L = alpha * x + (1 - alpha) * (L + T);
    T = beta  * (L - lastL) + (1 - beta) * T;
  }

  final mape = apes.isEmpty
      ? null
      : apes.reduce((a, b) => a + b) / apes.length;

  return _DES(L: L, T: T, alpha: alpha, beta: beta,
      mape: mape, fits: fits, actuals: actuals);
}

/// Return the best-fitting (α, β) for [series] by grid search over MAPE.
_DES _bestFit(List<double> series) {
  const alphas = [0.1, 0.2, 0.3, 0.4, 0.5];
  const betas  = [0.05, 0.1, 0.15, 0.2, 0.25];
  _DES? best;
  double bestMape = double.infinity;
  for (final a in alphas) {
    for (final b in betas) {
      final r = _fitHolt(series, a, b);
      if (r.mape != null && r.mape! < bestMape) {
        bestMape = r.mape!;
        best     = r;
      }
    }
  }
  return best ?? _fitHolt(series, 0.2, 0.1);
}

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

/// One product that contributes demand to a raw material via BOM.
class _Source {
  final String name;
  final double forecastQty; // F{t+1} in product units
  final double qpu;         // BOM: sqft (or base units) per product unit
  final double? mape;
  final double alpha, beta;
  final double contribution; // forecastQty × qpu  (in raw material base units)
  const _Source({
    required this.name, required this.forecastQty, required this.qpu,
    required this.mape, required this.alpha, required this.beta,
    required this.contribution,
  });
}

/// Urgency of a raw material's stock situation.
enum _Status { critical, atRisk, healthy, noDemand }

class _Material {
  final String id, name, unit;
  final double stock, restock;
  final double forecastUnits; // next-30d forecast in stocking units
  final double dailyRate;
  final double daysLeft, daysToRestock;
  final double? weightedMape;
  final List<_Source> sources;
  final List<double> periods; // 36-period history in stocking units
  // true when forecast derives from restock_level proxy, not real sales
  final bool synthetic;

  const _Material({
    required this.id, required this.name, required this.unit,
    required this.stock, required this.restock,
    required this.forecastUnits, required this.dailyRate,
    required this.daysLeft, required this.daysToRestock,
    required this.weightedMape, required this.sources, required this.periods,
    this.synthetic = false,
  });

  _Status get status {
    if (dailyRate < 0.001) return _Status.noDemand;
    // If stock hasn't been entered yet (synthetic baseline + zero stock),
    // show At Risk instead of Critical so the screen doesn't alarm before
    // the admin has had a chance to enter their actual stock levels.
    if (stock <= 0) return synthetic ? _Status.atRisk : _Status.critical;
    if (daysLeft <= 7) return _Status.critical;
    if (daysLeft <= 21 || stock <= restock) return _Status.atRisk;
    return _Status.healthy;
  }

  Color get statusColor {
    switch (status) {
      case _Status.critical: return _rose;
      case _Status.atRisk:   return _amber;
      case _Status.healthy:  return _emerald;
      case _Status.noDemand: return _slate;
    }
  }

  String get statusLabel {
    switch (status) {
      case _Status.critical: return 'Critical';
      case _Status.atRisk:   return 'At Risk';
      case _Status.healthy:  return 'Healthy';
      case _Status.noDemand: return 'No Demand';
    }
  }

  String get mapeText => weightedMape == null
      ? '—' : '${weightedMape!.toStringAsFixed(1)}%';

  Color get mapeColor {
    final m = weightedMape;
    if (m == null) return _muted;
    if (m < 10)   return _emerald;
    if (m < 25)   return _lime;
    if (m < 50)   return _amber;
    return _rose;
  }

  String get mapeGrade {
    final m = weightedMape;
    if (m == null) return '—';
    if (m < 10)   return 'Excellent';
    if (m < 25)   return 'Good';
    if (m < 50)   return 'Fair';
    return 'Poor';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class EmployeeInventoryForecastScreen extends StatefulWidget {
  const EmployeeInventoryForecastScreen({super.key});
  @override
  State<EmployeeInventoryForecastScreen> createState() => _ForecastState();
}

class _ForecastState extends State<EmployeeInventoryForecastScreen> {
  bool   _loading = true;
  String? _error;
  List<_Material> _all = [];
  String _filter = 'All';
  String _sort   = 'Days Left';

  static const _nPeriods   = 36; // 3 years × 12 months
  static const _periodDays = 30;

  @override
  void initState() { super.initState(); _load(); }

  // ── Load & compute ──────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final db  = FirebaseFirestore.instance;
      final now = DateTime.now();

      // Period boundaries: limits[0] = 3 yrs ago, limits[36] = now
      final limits = List.generate(_nPeriods + 1, (k) =>
          Timestamp.fromDate(now.subtract(
              Duration(days: _periodDays * (_nPeriods - k)))));

      int? periodOf(Timestamp ts) {
        if (ts.compareTo(limits[0]) < 0) return null;
        if (ts.compareTo(limits[_nPeriods]) >= 0) return null;
        for (int i = _nPeriods - 1; i >= 0; i--) {
          if (ts.compareTo(limits[i]) >= 0) return i;
        }
        return null;
      }

      // ── Fetch all data ─────────────────────────────────────────────────────
      // Order_Queue holds the live job queue; Orders may hold archived ones.
      // Query both so no completed orders are missed.
      final [matSnap, prodSnap, ordSnap, oqSnap, srSnap] = await Future.wait([
        db.collection('RawMaterials').get(),
        db.collection('Products').get(),
        db.collection('Orders').where('status', isEqualTo: 'completed').get(),
        db.collection('Order_Queue').where('status', isEqualTo: 'completed').get(),
        db.collection('Sales_Records').get(),
      ]);

      final mats = {for (final d in matSnap.docs) d.id: d.data()};

      // ── BOM catalog: keyed by product doc-ID (primary) and name (fallback) ─
      final bomById   = <String, List<Map<String, dynamic>>>{};
      final bomByName = <String, List<Map<String, dynamic>>>{};
      final nameById  = <String, String>{};
      for (final d in prodSnap.docs) {
        final bom  = (d.data()['bill_of_materials'] as List?)
            ?.cast<Map<String, dynamic>>() ?? [];
        final name = (d.data()['product_name']?.toString() ?? '').trim();
        if (name.isEmpty) continue;
        bomById[d.id]                = bom;
        bomByName[name.toLowerCase()] = bom;
        nameById[d.id]               = name;
      }

      // ── Accumulate per-period product sales ────────────────────────────────
      // key  = product doc-id when BOM is found by id, else lowercase name
      // This keeps duplicate-proof aggregation even when both sources fire.
      final sales   = <String, List<double>>{};
      final display = <String, String>{};
      final bomKey  = <String, List<Map<String, dynamic>>>{};

      void addSale(String key, String label,
                   List<Map<String, dynamic>> bom, int idx, double qty) {
        sales.putIfAbsent(key, () => List.filled(_nPeriods, 0.0));
        display.putIfAbsent(key, () => label);
        bomKey.putIfAbsent(key, () => bom);
        sales[key]![idx] += qty;
      }

      // Combine Orders + Order_Queue, deduplicated by Firestore doc id
      final seen   = <String>{};
      final allOrd = [...ordSnap.docs, ...oqSnap.docs]
          .where((d) => seen.add(d.id)).toList();

      for (final doc in allOrd) {
        final ts = doc.data()['created_at'] as Timestamp?;
        if (ts == null) continue;
        final idx = periodOf(ts); if (idx == null) continue;
        for (final p in (doc.data()['products'] as List? ?? [])
            .cast<Map<String, dynamic>>()) {
          final name = (p['name']?.toString() ?? '').trim();
          final pid  = p['product_id']?.toString() ?? '';
          final qty  = (p['qty'] as num?)?.toDouble() ?? 1.0;
          if (qty <= 0) continue;
          final bom = bomById[pid] ?? bomByName[name.toLowerCase()] ?? [];
          if (bom.isEmpty) continue; // skip products with no BOM
          final key   = pid.isNotEmpty && bomById.containsKey(pid)
              ? pid : name.toLowerCase();
          final label = nameById[pid] ?? name;
          addSale(key, label, bom, idx, qty);
        }
      }

      // Sales_Records (CSV imports)
      for (final doc in srSnap.docs) {
        final ts = doc.data()['sale_date'] as Timestamp?;
        if (ts == null) continue;
        final idx = periodOf(ts); if (idx == null) continue;
        for (final p in (doc.data()['products'] as List? ?? [])
            .cast<Map<String, dynamic>>()) {
          final name = (p['name']?.toString() ?? '').trim();
          final qty  = (p['qty'] as num?)?.toDouble() ?? 1.0;
          if (name.isEmpty || qty <= 0) continue;
          final bom = bomByName[name.toLowerCase()] ?? [];
          if (bom.isEmpty) continue;
          addSale(name.toLowerCase(), name, bom, idx, qty);
        }
      }

      // ── Phase 1: DES per product ──────────────────────────────────────────
      final holt = <String, _DES>{};
      for (final e in sales.entries) { holt[e.key] = _bestFit(e.value); }

      // ── Phase 2: BOM explosion → per-material consumption series + sources ─
      // periodSqft[matId][p] = base-unit consumption in period p (summed over products)
      final periodSqft = <String, List<double>>{
        for (final id in mats.keys) id: List.filled(_nPeriods, 0.0),
      };
      // sources for display (product-level breakdown)
      final sourcesMap = <String, List<_Source>>{};

      for (final e in sales.entries) {
        final key  = e.key;
        final des  = holt[key]!;
        final fQty = des.forecast(1);
        final bom  = bomKey[key] ?? [];

        for (final b in bom) {
          final mid = b['material_id']?.toString() ?? '';
          final qpu = (b['quantity_per_unit'] as num?)?.toDouble() ?? 1.0;
          if (mid.isEmpty || !periodSqft.containsKey(mid)) continue;

          // Always accumulate historical consumption regardless of fQty
          for (int p = 0; p < _nPeriods; p++) {
            periodSqft[mid]![p] += e.value[p] * qpu;
          }

          // Only add to sources display if forecast is meaningful
          if (fQty >= 0.001) {
            final contrib = fQty * qpu;
            sourcesMap.putIfAbsent(mid, () => []).add(_Source(
              name: display[key] ?? key,
              forecastQty: fQty, qpu: qpu,
              mape: des.mape, alpha: des.alpha, beta: des.beta,
              contribution: contrib,
            ));
          }
        }
      }

      // ── Phase 3: DES on each material's aggregated consumption history ─────
      // Running DES on the material series directly is more stable than
      // chaining product DES → BOM explosion, especially with sparse data.
      final materialDES = <String, _DES>{};
      for (final id in mats.keys) {
        materialDES[id] =
            _bestFit(periodSqft[id] ?? List.filled(_nPeriods, 0.0));
      }

      // ── Build _Material per raw material ───────────────────────────────────
      final result = <_Material>[];
      for (final e in mats.entries) {
        final id       = e.key;
        final d        = e.value;
        final name     = d['material_name']?.toString() ?? id;
        final su       = d['stocking_unit']?.toString() ?? '';
        final sqftPer  = (d['unit_size_sqft'] as num?)?.toDouble() ?? 0;
        final unitDesc = d['unit_description']?.toString() ?? '';
        final unit     = unitDesc.isNotEmpty ? unitDesc : su;
        final hasConv  = sqftPer > 0.001 && su.isNotEmpty;

        double toSU(double v) => hasConv ? v / sqftPer : v;

        final rawStock   = (d['current_stock'] as num?)?.toDouble() ?? 0;
        final rawRestock = (d['restock_level'] as num?)?.toDouble() ?? 0;
        final stock   = hasConv ? rawStock   / sqftPer : rawStock;
        final restock = hasConv ? rawRestock / sqftPer : rawRestock;

        // Use the material-level DES for the primary forecast
        final mDes = materialDES[id]!;
        double fRaw = mDes.forecast(1); // base units next period
        bool isSynthetic = false;

        // Synthetic DES fallback — no real BOM-linked sales found.
        // Build a 12-period constant series equal to restock_level and run DES
        // on it so every material has a proper Holt forecast. This baseline is
        // replaced automatically once real sales data arrives.
        if (fRaw < 0.001 && rawRestock > 0.001) {
          final synth = List.generate(_nPeriods, (i) =>
              i < _nPeriods - 12 ? 0.0 : rawRestock);
          fRaw = _bestFit(synth).forecast(1); // ≈ rawRestock, trend ≈ 0
          isSynthetic = true;
        }

        final fSU      = toSU(fRaw);
        final daily    = fSU / _periodDays;
        final daysLeft = daily > 0.001 ? stock / daily : double.infinity;
        final daysRest = daily > 0.001 && stock > restock
            ? (stock - restock) / daily
            : (stock <= restock ? 0.0 : double.infinity);

        final srcs = sourcesMap[id] ?? [];

        // Weighted MAPE from sources; fall back to material-level DES MAPE
        double? wMape;
        final withMape = srcs.where((s) => s.mape != null).toList();
        if (withMape.isNotEmpty) {
          final totalC = withMape.fold<double>(
              0.0, (acc, s) => acc + s.contribution);
          if (totalC > 0) {
            wMape = withMape.fold<double>(
                0.0, (acc, s) => acc + s.mape! * s.contribution / totalC);
          }
        } else {
          wMape = mDes.mape;
        }

        final ps = (periodSqft[id] ?? List.filled(_nPeriods, 0.0))
            .map(toSU).toList();

        result.add(_Material(
          id: id, name: name, unit: unit,
          stock: stock, restock: restock,
          forecastUnits: fSU, dailyRate: daily,
          daysLeft: daysLeft, daysToRestock: daysRest,
          // No accuracy metric for synthetic baseline forecasts
          weightedMape: isSynthetic ? null : wMape,
          sources: srcs, periods: ps,
          synthetic: isSynthetic,
        ));
      }

      setState(() { _all = result; _loading = false; });
    } catch (e, st) {
      setState(() { _error = '$e\n$st'; _loading = false; });
    }
  }

  // ── Filtered / sorted list ──────────────────────────────────────────────────

  List<_Material> get _visible {
    var list = _all.where((m) {
      switch (_filter) {
        case 'Critical':  return m.status == _Status.critical;
        case 'At Risk':   return m.status == _Status.atRisk;
        case 'Healthy':   return m.status == _Status.healthy;
        case 'No Demand': return m.status == _Status.noDemand;
        default:          return true;
      }
    }).toList();
    list.sort((a, b) {
      switch (_sort) {
        case 'Name':     return a.name.compareTo(b.name);
        case 'Forecast': return b.forecastUnits.compareTo(a.forecastUnits);
        case 'MAPE':
          final ma = a.weightedMape ?? double.infinity;
          final mb = b.weightedMape ?? double.infinity;
          return ma.compareTo(mb);
        default:
          final da = a.daysLeft.isInfinite ? 99999.0 : a.daysLeft;
          final db = b.daysLeft.isInfinite ? 99999.0 : b.daysLeft;
          return da.compareTo(db);
      }
    });
    return list;
  }

  int _cnt(_Status s) => _all.where((m) => m.status == s).length;

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return _splash('Running DES forecast…');
    if (_error != null) return _errView();
    if (_all.isEmpty) return _splash('No raw materials found.');

    return Column(children: [
      _header(),
      Expanded(
        child: _visible.isEmpty
            ? Center(child: Text('No "$_filter" materials.',
                style: const TextStyle(color: _muted)))
            : RefreshIndicator(
                onRefresh: _load, color: _navy,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  itemCount: _visible.length,
                  separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) => _MatCard(mat: _visible[i]),
                )),
      ),
    ]);
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _header() {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Title row
        Row(children: [
          const Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Inventory Forecast',
                  style: TextStyle(color: _navy, fontSize: 15,
                      fontWeight: FontWeight.w800)),
              SizedBox(height: 1),
              Text("Holt's DES (α+β auto) · 3-yr history · BOM explosion",
                  style: TextStyle(color: _muted, fontSize: 10)),
            ],
          )),
          _HdrBtn('Import', Icons.upload_file_rounded, _navy, () async {
            await showSalesImportSheet(context);
            if (mounted) _load();
          }),
          const SizedBox(width: 6),
          _HdrBtn('Diagnose', Icons.troubleshoot_rounded, _amber, () =>
              _openDiag(context)),
          const SizedBox(width: 6),
          _HdrBtn('Refresh', Icons.refresh_rounded, _slate, _load),
        ]),
        const SizedBox(height: 10),

        // Status summary chips
        SingleChildScrollView(scrollDirection: Axis.horizontal,
          child: Row(children: [
            _SChip('Critical',  _cnt(_Status.critical),  _rose,    _filter == 'Critical',
                () => _setFilter('Critical')),
            _SChip('At Risk',   _cnt(_Status.atRisk),    _amber,   _filter == 'At Risk',
                () => _setFilter('At Risk')),
            _SChip('Healthy',   _cnt(_Status.healthy),   _emerald, _filter == 'Healthy',
                () => _setFilter('Healthy')),
            _SChip('No Demand', _cnt(_Status.noDemand),  _slate,   _filter == 'No Demand',
                () => _setFilter('No Demand')),
          ]),
        ),
        const SizedBox(height: 8),

        // Sort row
        SingleChildScrollView(scrollDirection: Axis.horizontal,
          child: Row(children: [
            const Text('Sort: ', style: TextStyle(color: _muted, fontSize: 11)),
            ...['Days Left', 'Name', 'Forecast', 'MAPE'].map((s) =>
              Padding(padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(onTap: () => setState(() => _sort = s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _sort == s ? _navy : Colors.transparent,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                          color: _sort == s ? _navy : _border)),
                    child: Text(s, style: TextStyle(
                      color: _sort == s ? Colors.white : _slate,
                      fontSize: 11,
                      fontWeight: _sort == s
                          ? FontWeight.w700 : FontWeight.w500)),
                  ),
                )),
            ),
          ]),
        ),
      ]),
    );
  }

  void _setFilter(String f) =>
      setState(() => _filter = _filter == f ? 'All' : f);

  void _openDiag(BuildContext ctx) => showModalBottomSheet(
    context: ctx, isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _DiagSheet(),
  );

  Widget _splash(String msg) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      if (_loading)
        const CircularProgressIndicator(color: _navy, strokeWidth: 2),
      if (!_loading)
        const Icon(Icons.inventory_2_outlined, size: 40, color: _muted),
      const SizedBox(height: 14),
      Text(msg, style: const TextStyle(color: _muted, fontSize: 13)),
    ],
  ));

  Widget _errView() => Center(child: Padding(
    padding: const EdgeInsets.all(20),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, color: _rose, size: 44),
      const SizedBox(height: 12),
      Text(_error!, style: const TextStyle(color: _slate, fontSize: 11),
          textAlign: TextAlign.center),
      const SizedBox(height: 16),
      ElevatedButton.icon(onPressed: _load,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(backgroundColor: _navy,
              foregroundColor: Colors.white)),
    ]),
  ));
}

// ─────────────────────────────────────────────────────────────────────────────
// Material card
// ─────────────────────────────────────────────────────────────────────────────

class _MatCard extends StatefulWidget {
  final _Material mat;
  const _MatCard({required this.mat});
  @override
  State<_MatCard> createState() => _MatCardState();
}

class _MatCardState extends State<_MatCard> {
  bool _open = false;

  static String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v < 1 ? v.toStringAsFixed(3) : v.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final m     = widget.mat;
    final color = m.statusColor;
    final dLabel = m.daysLeft.isInfinite ? '∞' : m.daysLeft.toStringAsFixed(0);

    // Stock bar
    final sPct = m.restock > 0
        ? (m.stock / (m.restock * 3)).clamp(0.0, 1.0)
        : (m.stock > 0 ? 1.0 : 0.0);

    return GestureDetector(
      onTap: () => setState(() => _open = !_open),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: _open ? color.withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
              width: _open ? 1.2 : 0.8),
          boxShadow: const [BoxShadow(
              color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Collapsed row ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Days badge
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.10),
                  border: Border.all(color: color.withValues(alpha: 0.4))),
                child: Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(dLabel, style: TextStyle(color: color,
                        fontSize: dLabel.length > 3 ? 9 : 14,
                        fontWeight: FontWeight.w800)),
                    Text('days', style: TextStyle(
                        color: color.withValues(alpha: 0.6), fontSize: 7)),
                  ],
                )),
              ),
              const SizedBox(width: 10),

              // Main info
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + status badge
                  Row(children: [
                    Expanded(child: Text(m.name,
                        style: const TextStyle(color: _navy,
                            fontSize: 13, fontWeight: FontWeight.w700),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (m.synthetic) ...[
                      const SizedBox(width: 4),
                      _Badge('~Est', _slate),
                    ],
                    const SizedBox(width: 6),
                    _Badge(m.statusLabel, color),
                  ]),
                  const SizedBox(height: 5),

                  // Stock bar
                  ClipRRect(borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: sPct, minHeight: 5,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation(color))),
                  const SizedBox(height: 4),

                  // Stock numbers + MAPE badge
                  Row(children: [
                    Text(
                      m.unit.isEmpty
                          ? 'Stock: ${_fmt(m.stock)}'
                          : 'Stock: ${_fmt(m.stock)} ${m.unit}',
                      style: const TextStyle(
                          color: _slate, fontSize: 11)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: m.mapeColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: m.mapeColor.withValues(alpha: 0.35),
                            width: 0.7)),
                      child: Text('MAPE ${m.mapeText}',
                          style: TextStyle(color: m.mapeColor,
                              fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ]),

                  // Forecast pill
                  if (m.forecastUnits > 0.001) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${m.synthetic ? 'Est. baseline' : 'Forecast'} next 30d: '
                      '${_fmt(m.forecastUnits)}'
                      '${m.unit.isNotEmpty ? ' ${m.unit}' : ''}',
                      style: TextStyle(
                          color: m.synthetic
                              ? _slate.withValues(alpha: 0.7)
                              : _navy.withValues(alpha: 0.65),
                          fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ],
              )),

              // Chevron
              Padding(padding: const EdgeInsets.only(left: 4, top: 2),
                child: AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more,
                      color: _muted, size: 18))),
            ]),
          ),

          // ── Expanded detail ────────────────────────────────────────────────
          if (_open) ...[
            Divider(height: 1,
                color: color.withValues(alpha: 0.20)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                // ── Key stats grid ─────────────────────────────────────────
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _StatBox('Forecast (30d)',
                    m.forecastUnits < 0.001 ? 'No demand'
                        : '${_fmt(m.forecastUnits)} ${m.unit}',
                    _navy),
                  _StatBox('Days to Stockout',
                    m.daysLeft.isInfinite ? '∞'
                        : '~${m.daysLeft.toStringAsFixed(0)} d', color),
                  _StatBox('Days to Restock Lvl',
                    m.daysToRestock <= 0 ? 'Already below!'
                        : m.daysToRestock.isInfinite ? '∞'
                        : '~${m.daysToRestock.toStringAsFixed(0)} d',
                    _amber),
                  _StatBox('Restock Level',
                    '${_fmt(m.restock)} ${m.unit}', _slate),
                  _StatBox('MAPE', '${m.mapeText}  ${m.mapeGrade}',
                    m.mapeColor),
                  _StatBox('Suggest Reorder',
                    math.max(0, m.forecastUnits - m.stock) < 0.001
                        ? 'None' : '${_fmt(math.max(0, m.forecastUnits - m.stock))} ${m.unit}',
                    _emerald),
                ]),
                const SizedBox(height: 12),

                // ── DES explanation ────────────────────────────────────────
                sectionLabel('Double Exponential Smoothing  (Holt\'s Linear Trend)'),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    _mono('Init:     L₁ = X₁,  T₁ = X₂ − X₁'),
                    _mono('Level:    Lₜ = α·Xₜ + (1−α)·(Lₜ₋₁ + Tₜ₋₁)'),
                    _mono('Trend:    Tₜ = β·(Lₜ − Lₜ₋₁) + (1−β)·Tₜ₋₁'),
                    _mono('Forecast: F{t+m} = Lₜ + m·Tₜ'),
                    _mono('MAPE: mean(|Xₜ−Fₜ|/Xₜ)×100  over non-zero periods'),
                    const SizedBox(height: 4),
                    Text('α and β are auto-selected per product to minimise MAPE.',
                        style: TextStyle(color: _slate.withValues(alpha: 0.7),
                            fontSize: 9, fontStyle: FontStyle.italic)),
                  ]),
                ),
                const SizedBox(height: 12),

                // ── BOM source products ────────────────────────────────────
                sectionLabel('BOM Explosion — Contributing Products'),
                const SizedBox(height: 6),
                if (m.sources.isEmpty)
                  m.synthetic ? _syntheticNote(m) : _noDemandNote()
                else
                  _sourcesTable(m),
                const SizedBox(height: 12),

                // ── Period history table ───────────────────────────────────
                sectionLabel('Consumption History  (last 12 of 36 periods)'),
                const SizedBox(height: 6),
                _periodTable(m),
                const SizedBox(height: 8),

                // ── Recommendation ─────────────────────────────────────────
                _recoBox(m, color),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  // ── Sub-widgets ─────────────────────────────────────────────────────────────

  Widget _sourcesTable(_Material m) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
          child: Row(children: [
            _th('Product', flex: 4),
            _th('α / β',   flex: 2),
            _th('F(t+1)',  flex: 2, right: true),
            _th('× qpu',   flex: 2, right: true),
            _th('Demand',  flex: 2, right: true),
            _th('MAPE',    flex: 2, right: true),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        for (int i = 0; i < m.sources.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                _td(m.sources[i].name, flex: 4, bold: true),
                _td('${m.sources[i].alpha}/${m.sources[i].beta}',
                    flex: 2, mono: true),
                _td(m.sources[i].forecastQty.toStringAsFixed(1),
                    flex: 2, right: true),
                _td('× ${m.sources[i].qpu.toStringAsFixed(2)}',
                    flex: 2, right: true),
                _td(m.sources[i].contribution.toStringAsFixed(2),
                    flex: 2, right: true, bold: true),
                _td(m.sources[i].mape == null
                    ? '—'
                    : '${m.sources[i].mape!.toStringAsFixed(1)}%',
                    flex: 2, right: true,
                    color: m.sources[i].mape == null ? _muted
                        : m.sources[i].mape! < 10 ? _emerald
                        : m.sources[i].mape! < 25 ? _lime
                        : m.sources[i].mape! < 50 ? _amber : _rose),
              ]),
            ]),
          ),
          if (i < m.sources.length - 1)
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
        ],
        // Total row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(8))),
          child: Row(children: [
            const Expanded(flex: 4,
                child: Text('Total forecast need',
                    style: TextStyle(color: _slate, fontSize: 10,
                        fontWeight: FontWeight.w700))),
            const Expanded(flex: 2, child: SizedBox()),
            const Expanded(flex: 2, child: SizedBox()),
            const Expanded(flex: 2, child: SizedBox()),
            Expanded(flex: 2,
                child: Text(_fmt(m.forecastUnits),
                    textAlign: TextAlign.right,
                    style: TextStyle(color: _navy.withValues(alpha: 0.9),
                        fontSize: 11, fontWeight: FontWeight.w800))),
            Expanded(flex: 2,
                child: Text(
                  m.weightedMape == null ? '—'
                      : '${m.weightedMape!.toStringAsFixed(1)}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: m.mapeColor,
                      fontSize: 10, fontWeight: FontWeight.w700))),
          ]),
        ),
      ]),
    );
  }

  Widget _periodTable(_Material m) {
    final ps    = m.periods;
    final start = math.max(0, ps.length - 12);
    final slice = ps.sublist(start);

    return Container(
      decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
          child: Row(children: [
            _th('Period', flex: 3),
            _th('Actual Consumption', flex: 4, right: true),
            _th(m.unit.isNotEmpty ? m.unit : 'units', flex: 3, right: true),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        for (int i = 0; i < slice.length; i++) ...[
          Builder(builder: (_) {
            final v      = slice[i];
            final fromEnd = slice.length - 1 - i;
            final label  = fromEnd == 0 ? 'P1  last 30d'
                : fromEnd == 1 ? 'P2  30–60d ago'
                : fromEnd == 2 ? 'P3  60–90d ago'
                : 'P${fromEnd + 1}  ${(fromEnd + 1) * 30}d+';
            return Container(
              color: fromEnd < 3
                  ? _navy.withValues(alpha: 0.02) : null,
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              child: Row(children: [
                Expanded(flex: 3, child: Text(label,
                    style: TextStyle(
                      color: fromEnd < 3 ? _navy.withValues(alpha: 0.75) : _slate,
                      fontSize: 10,
                      fontWeight: fromEnd < 3
                          ? FontWeight.w700 : FontWeight.w400))),
                Expanded(flex: 4, child: Text(
                    v < 0.001 ? '—' : _fmt(v),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: v > 0.001 ? _navy : _muted,
                      fontSize: 10,
                      fontWeight: v > 0.001
                          ? FontWeight.w600 : FontWeight.w400))),
                const Expanded(flex: 3, child: SizedBox()),
              ]),
            );
          }),
          if (i < slice.length - 1)
            const Divider(height: 1, color: Color(0xFFF8FAFC)),
        ],
        // Forecast row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
              color: _navy.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(8))),
          child: Row(children: [
            const Expanded(flex: 3,
                child: Text('Forecast P0  next 30d',
                    style: TextStyle(color: _navy, fontSize: 10,
                        fontWeight: FontWeight.w800))),
            Expanded(flex: 4, child: Text(
                m.forecastUnits < 0.001 ? '0' : _fmt(m.forecastUnits),
                textAlign: TextAlign.right,
                style: const TextStyle(color: _navy, fontSize: 11,
                    fontWeight: FontWeight.w800))),
            const Expanded(flex: 3, child: SizedBox()),
          ]),
        ),
      ]),
    );
  }

  Widget _recoBox(_Material m, Color color) {
    String text;
    if (m.dailyRate < 0.001) {
      text = m.sources.isEmpty
          ? 'No BOM-linked product sales found. Add bill_of_materials in '
            'Admin → Products, then Import sales data to get a demand forecast.'
          : 'Demand is present but too low to forecast meaningful consumption. '
            'Stock should be sufficient unless demand spikes unexpectedly.';
    } else if (m.synthetic) {
      final dStr = m.daysLeft.isInfinite
          ? 'no foreseeable stockout'
          : '~${m.daysLeft.toStringAsFixed(0)} days until stockout (estimated)';
      final u = m.unit.isNotEmpty ? m.unit : 'units';
      final need = math.max(0.0, m.forecastUnits - m.stock);
      if (m.status == _Status.critical) {
        text = 'URGENT — $dStr. Estimated reorder: ${_fmt(need)} $u. '
            '(Baseline forecast — import real sales to improve accuracy.)';
      } else if (m.status == _Status.atRisk) {
        text = 'Reorder soon — $dStr. Recommended: ${_fmt(need)} $u. '
            '(Baseline forecast — import real sales to improve accuracy.)';
      } else {
        text = 'Stock OK ($dStr). '
            '${need < 0.001 ? 'No top-up needed.' : 'Top-up if needed: ${_fmt(need)} $u.'} '
            '(Baseline forecast — import real sales to improve accuracy.)';
      }
    } else {
      final dStr = m.daysLeft.isInfinite
          ? 'no foreseeable stockout'
          : '~${m.daysLeft.toStringAsFixed(0)} days until stockout';
      final mNote = m.weightedMape != null
          ? ' · MAPE ${m.mapeText} (${m.mapeGrade})' : '';
      final need = math.max(0.0, m.forecastUnits - m.stock);
      final u    = m.unit.isNotEmpty ? m.unit : 'units';
      if (m.status == _Status.critical) {
        text = 'URGENT — $dStr$mNote. Order ≥${_fmt(need)} $u now.';
      } else if (m.status == _Status.atRisk) {
        text = 'Reorder soon — $dStr$mNote. Recommended: ${_fmt(need)} $u.';
      } else {
        text = 'Stock OK ($dStr)$mNote. '
            '${need < 0.001 ? 'No top-up needed.' : 'Top-up if needed: ${_fmt(need)} $u.'}';
      }
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.lightbulb_outline, color: color, size: 14),
        const SizedBox(width: 7),
        Expanded(child: Text(text,
            style: TextStyle(color: color.withValues(alpha: 0.85),
                fontSize: 11, height: 1.4))),
      ]),
    );
  }

  Widget _syntheticNote(_Material m) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.auto_graph_rounded, color: _slate, size: 14),
      const SizedBox(width: 8),
      Expanded(child: Text(
        'No BOM-linked sales found. This forecast is a DES baseline derived '
        'from the restock level (${_fmt(m.restock)} ${m.unit}/month). '
        'Import real sales data or complete orders to replace this estimate.',
        style: const TextStyle(color: _slate, fontSize: 10, height: 1.4))),
    ]),
  );

  Widget _noDemandNote() => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0))),
    child: Row(children: [
      const Icon(Icons.info_outline, color: _muted, size: 14),
      const SizedBox(width: 8),
      const Expanded(child: Text(
        'No product in the catalog has a BOM entry for this material, '
        'or no sales exist for products that use it. '
        'Check Admin → Products → Bill of Materials.',
        style: TextStyle(color: _slate, fontSize: 10, height: 1.4))),
    ]),
  );

  Widget _th(String t, {int flex = 1, bool right = false}) =>
      Expanded(flex: flex, child: Text(t,
          textAlign: right ? TextAlign.right : TextAlign.left,
          style: const TextStyle(color: _muted, fontSize: 9,
              fontWeight: FontWeight.w700)));

  Widget _td(String t, {int flex = 1, bool right = false,
    bool bold = false, bool mono = false, Color? color}) =>
      Expanded(flex: flex, child: Text(t,
          textAlign: right ? TextAlign.right : TextAlign.left,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color ?? _slate,
            fontSize: 10,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            fontFamily: mono ? 'monospace' : null)));

  static Widget _mono(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(t, style: const TextStyle(
        color: _slate, fontSize: 9.5, fontFamily: 'monospace', height: 1.5)));

  static Widget sectionLabel(String t) => Text(t,
      style: const TextStyle(color: _navy, fontSize: 11,
          fontWeight: FontWeight.w700));
}

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _HdrBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _HdrBtn(this.label, this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color.withValues(alpha: 0.85)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.85),
            fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    ));
}

class _SChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  const _SChip(this.label, this.count, this.color, this.active, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: active ? _navy : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: active ? _navy : const Color(0xFFE2E8F0))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8,
            decoration: BoxDecoration(
                color: active ? color.withValues(alpha: 0.8) : color,
                shape: BoxShape.circle)),
        const SizedBox(width: 7),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$count', style: TextStyle(
            color: active ? Colors.white : _navy,
            fontSize: 15, fontWeight: FontWeight.w800, height: 1)),
          Text(label, style: TextStyle(
            color: active
                ? Colors.white.withValues(alpha: 0.7) : _slate,
            fontSize: 9)),
        ]),
      ]),
    ));
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.40))),
    child: Text(label, style: TextStyle(
        color: color, fontSize: 9, fontWeight: FontWeight.w700)));
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatBox(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.20))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(
          color: color.withValues(alpha: 0.7),
          fontSize: 9, fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(
          color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    ]));
}

// ─────────────────────────────────────────────────────────────────────────────
// Diagnostic sheet
// ─────────────────────────────────────────────────────────────────────────────

class _DiagSheet extends StatefulWidget {
  const _DiagSheet();
  @override
  State<_DiagSheet> createState() => _DiagSheetState();
}

class _DiagSheetState extends State<_DiagSheet> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _res;

  @override
  void initState() { super.initState(); _run(); }

  Future<void> _run() async {
    try {
      final db       = FirebaseFirestore.instance;
      final prodSnap = await db.collection('Products').get();
      final matSnap  = await db.collection('RawMaterials').get();
      final srSnap   = await db.collection('Sales_Records').get();
      final ordSnap  = await db.collection('Orders')
          .where('status', isEqualTo: 'completed').get();

      final bomByName = <String, List>{};
      final allNames  = <String>{};
      for (final d in prodSnap.docs) {
        final bom  = (d.data()['bill_of_materials'] as List?) ?? [];
        final name = (d.data()['product_name']?.toString() ?? '').trim();
        if (name.isEmpty) continue;
        allNames.add(name);
        bomByName[name.toLowerCase()] = bom;
      }
      final validMats = matSnap.docs.map((d) => d.id).toSet();

      final matched   = <String, int>{};
      final unmatched = <String, int>{};
      final noBom     = <String, int>{};
      final badMat    = <String, int>{};
      int csvDocs = 0, csvLines = 0, ordDocs = ordSnap.docs.length, ordMatch = 0;

      for (final doc in ordSnap.docs) {
        bool hit = false;
        for (final p in (doc.data()['products'] as List? ?? [])
            .cast<Map<String, dynamic>>()) {
          final name = (p['name']?.toString() ?? '').trim();
          final bom  = bomByName[name.toLowerCase()] ?? [];
          if (bom.isNotEmpty) {
            hit = true;
            for (final b in bom.cast<Map<String, dynamic>>()) {
              final mid = b['material_id']?.toString() ?? '';
              if (mid.isNotEmpty && !validMats.contains(mid)) {
                badMat[mid] = (badMat[mid] ?? 0) + 1;
              }
            }
          }
        }
        if (hit) ordMatch++;
      }

      for (final doc in srSnap.docs) {
        final items = (doc.data()['products'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        if (items.isEmpty) continue;
        csvDocs++;
        for (final item in items) {
          csvLines++;
          final name = (item['name']?.toString() ?? '').trim();
          if (name.isEmpty) continue;
          final bom = bomByName[name.toLowerCase()] ?? [];
          if (bom.isEmpty) {
            if (allNames.any((n) => n.toLowerCase() == name.toLowerCase())) {
              noBom[name] = (noBom[name] ?? 0) + 1;
            } else {
              unmatched[name] = (unmatched[name] ?? 0) + 1;
            }
          } else {
            final qty = (item['qty'] as num?)?.toInt() ?? 0;
            matched[name] = (matched[name] ?? 0) + qty;
            for (final b in bom.cast<Map<String, dynamic>>()) {
              final mid = b['material_id']?.toString() ?? '';
              if (mid.isNotEmpty && !validMats.contains(mid)) {
                badMat[mid] = (badMat[mid] ?? 0) + 1;
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {
        _res = {
          'products': allNames.length, 'materials': validMats.length,
          'csvDocs': csvDocs, 'csvLines': csvLines,
          'ordDocs': ordDocs, 'ordMatch': ordMatch,
          'matched': matched, 'unmatched': unmatched,
          'noBom': noBom, 'badMat': badMat,
        };
        _loading = false;
      });
      }
    } catch (e) {
      if (mounted) { setState(() { _error = e.toString(); _loading = false; }); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
          color: Color(0xFFFAFAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(children: [
        // Handle + header
        Center(child: Container(margin: const EdgeInsets.only(top: 12),
            width: 36, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2)))),
        Padding(padding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
          child: Row(children: [
            const Icon(Icons.troubleshoot_rounded,
                color: Color(0xFFB45309), size: 20),
            const SizedBox(width: 10),
            const Expanded(child: Text('Forecast Diagnostic',
                style: TextStyle(color: _navy, fontSize: 15,
                    fontWeight: FontWeight.w800))),
            IconButton(onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded,
                    color: _muted, size: 20)),
          ])),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(
              strokeWidth: 2, color: _navy))
          : _error != null
              ? Center(child: Text(_error!,
                  style: const TextStyle(color: _rose, fontSize: 11)))
              : _body()),
      ]),
    );
  }

  Widget _body() {
    final r = _res!;
    final matched   = r['matched']   as Map<String, int>;
    final unmatched = r['unmatched'] as Map<String, int>;
    final noBom     = r['noBom']     as Map<String, int>;
    final badMat    = r['badMat']    as Map<String, int>;

    return ListView(padding: const EdgeInsets.all(18), children: [
      _sec('Overview'),
      _row('Products in catalog',      '${r['products']}'),
      _row('Raw materials',             '${r['materials']}'),
      _row('Sales Records (CSV docs)', '${r['csvDocs']}'),
      _row('Total CSV line items',     '${r['csvLines']}'),
      _row('Completed Orders',         '${r['ordDocs']}'),
      _row('Orders with BOM match',    '${r['ordMatch']}'),
      const SizedBox(height: 14),

      _sec('Matched ✓', color: _emerald),
      matched.isEmpty
          ? _hint('None matched yet — import CSV sales data.')
          : Column(children: matched.entries.map((e) =>
              _row(e.key, 'qty: ${e.value}', color: _emerald)).toList()),
      const SizedBox(height: 14),

      _sec('NOT in Catalog ✗', color: _rose),
      unmatched.isEmpty
          ? _hint('All CSV product names matched the catalog.')
          : Column(children: [
              _hint('Fix: make sure product_name in CSV exactly matches '
                  'the product_name in Products.'),
              ...unmatched.entries.map((e) =>
                  _row('"${e.key}"', '${e.value} items', color: _rose)),
            ]),
      const SizedBox(height: 14),

      _sec('In Catalog — No BOM ⚠', color: _amber),
      noBom.isEmpty
          ? _hint('All matched products have BOM entries.')
          : Column(children: [
              _hint('Add bill_of_materials in Admin → Products.'),
              ...noBom.entries.map((e) =>
                  _row(e.key, '${e.value} items', color: _amber)),
            ]),
      const SizedBox(height: 14),

      _sec('Invalid BOM material_id ✗', color: _rose),
      badMat.isEmpty
          ? _hint('All BOM material IDs are valid.')
          : Column(children: [
              _hint('Fix: check material_id in BOM matches the '
                  'RawMaterials document ID exactly.'),
              ...badMat.entries.map((e) =>
                  _row('"${e.key}"', '${e.value} entries', color: _rose)),
            ]),
      const SizedBox(height: 24),
    ]);
  }

  Widget _sec(String t, {Color color = _navy}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: TextStyle(color: color, fontSize: 12,
        fontWeight: FontWeight.w800)));

  Widget _row(String l, String v, {Color? color}) =>
      Padding(padding: const EdgeInsets.only(bottom: 5),
        child: Row(children: [
          Expanded(child: Text(l, style: TextStyle(
              color: color ?? const Color(0xFF374151), fontSize: 12,
              fontWeight: color != null ? FontWeight.w600 : FontWeight.w400))),
          Text(v, style: TextStyle(
              color: color ?? _slate, fontSize: 12,
              fontWeight: FontWeight.w600)),
        ]));

  Widget _hint(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Text(t, style: const TextStyle(
          color: _slate, fontSize: 10, height: 1.5))));
}
