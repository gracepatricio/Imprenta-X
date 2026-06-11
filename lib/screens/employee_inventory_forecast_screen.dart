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
//    α, β  auto-selected per product by minimising MAPE (grid search 56 pts)
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
const _indigo  = Color(0xFF6366F1);


// ── DES algorithm ─────────────────────────────────────────────────────────────

class _DES {
  final double L;
  final double T;
  final double alpha;
  final double beta;
  final double? mape;
  final List<double> fits;
  final List<double> actuals;

  const _DES({
    required this.L, required this.T,
    required this.alpha, required this.beta,
    required this.mape,
    required this.fits, required this.actuals,
  });

  // Forecast m periods ahead; clamp ≥ 0.
  double forecast(int m) => math.max(0.0, L + T * m);
}

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
    final f  = math.max(0.0, L + T);
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

// Grid search with 56 (α, β) combinations — wider range for better fit.
_DES _bestFit(List<double> series) {
  const alphas = [0.05, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7];
  const betas  = [0.01, 0.05, 0.1, 0.15, 0.2, 0.3, 0.4];
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

class _Source {
  final String name;
  final double forecastQty;
  final double qpu;
  final double? mape;
  final double alpha, beta;
  final double contribution;
  const _Source({
    required this.name, required this.forecastQty, required this.qpu,
    required this.mape, required this.alpha, required this.beta,
    required this.contribution,
  });
}

enum _Status { critical, atRisk, healthy, overstock, noDemand }

enum _TrendDir { up, down, flat }

class _Material {
  final String id, name, unit;
  final double stock, restock;
  // Multi-horizon forecasts (in stocking units).
  final double forecast7d, forecast30d, forecast90d;
  final double dailyRate;
  final double daysLeft, daysToRestock;
  // Smarter reorder: enough to cover 30d demand + restore safety stock buffer.
  final double reorderQty;
  final double? weightedMape;
  final List<_Source> sources;
  final List<double> periods;
  final bool synthetic;
  // Raw Holt trend component from the material-level DES (per period).
  final double trendSlope;
  // In-sample 1-step-ahead forecast vs actual for up to 6 recent periods.
  // Both in stocking units, oldest-first. Aligned: accActuals[i] ↔ accFitted[i].
  final List<double> accActuals;
  final List<double> accFitted;

  const _Material({
    required this.id, required this.name, required this.unit,
    required this.stock, required this.restock,
    required this.forecast7d, required this.forecast30d, required this.forecast90d,
    required this.dailyRate,
    required this.daysLeft, required this.daysToRestock,
    required this.reorderQty,
    required this.weightedMape, required this.sources, required this.periods,
    this.synthetic = false,
    this.trendSlope = 0.0,
    this.accActuals = const [],
    this.accFitted  = const [],
  });

  // Convenience alias used in legacy call-sites.
  double get forecastUnits => forecast30d;

  _Status get status {
    if (dailyRate < 0.001) return _Status.noDemand;
    if (stock <= 0) return synthetic ? _Status.atRisk : _Status.critical;
    if (daysLeft > 90 && stock > restock * 2 && restock > 0) return _Status.overstock;
    if (daysLeft <= 7) return _Status.critical;
    if (daysLeft <= 21 || stock <= restock) return _Status.atRisk;
    return _Status.healthy;
  }

  Color get statusColor {
    switch (status) {
      case _Status.critical:  return _rose;
      case _Status.atRisk:    return _amber;
      case _Status.healthy:   return _emerald;
      case _Status.overstock: return _indigo;
      case _Status.noDemand:  return _slate;
    }
  }

  String get statusLabel {
    switch (status) {
      case _Status.critical:  return 'Critical';
      case _Status.atRisk:    return 'At Risk';
      case _Status.healthy:   return 'Healthy';
      case _Status.overstock: return 'Overstock';
      case _Status.noDemand:  return 'No Demand';
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

  _TrendDir get trendDir {
    if (forecast30d < 0.001) return _TrendDir.flat;
    final threshold = forecast30d * 0.05; // 5% of 30d forecast per period
    if (trendSlope > threshold)  return _TrendDir.up;
    if (trendSlope < -threshold) return _TrendDir.down;
    return _TrendDir.flat;
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
  String _search = '';
  bool   _filtersVisible = true;
  final _searchCtrl = TextEditingController();

  static const _nPeriods   = 36;
  static const _periodDays = 30;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  // ── Load & compute ──────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final db  = FirebaseFirestore.instance;
      final now = DateTime.now();

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

      final [matSnap, prodSnap, ordSnap, oqSnap, srSnap] = await Future.wait([
        db.collection('RawMaterials').get(),
        db.collection('Products').get(),
        db.collection('Orders').where('status', isEqualTo: 'completed').get(),
        db.collection('Order_Queue').where('status', isEqualTo: 'completed').get(),
        db.collection('Sales_Records').get(),
      ]);

      final mats = {for (final d in matSnap.docs) d.id: d.data()};

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

      final sales      = <String, List<double>>{};
      final display    = <String, String>{};
      final bomKey     = <String, List<Map<String, dynamic>>>{};
      // Material consumption history built directly from actual order dimensions
      // (width_ft × height_ft × qty) when available, falling back to qty × BOM qpu.
      final periodSqft = <String, List<double>>{
        for (final id in mats.keys) id: List.filled(_nPeriods, 0.0),
      };
      // Tracks total actual sqft and total units per product across all orders
      // that had real dimensions — used to compute average sqft per unit for
      // the sources table instead of the fixed BOM qpu.
      final productSqftTotal  = <String, double>{};
      final productUnitsTotal = <String, double>{};

      void addSale(String key, String label,
                   List<Map<String, dynamic>> bom, int idx, double qty,
                   {double? actualSqft}) {
        sales.putIfAbsent(key, () => List.filled(_nPeriods, 0.0));
        display.putIfAbsent(key, () => label);
        bomKey.putIfAbsent(key, () => bom);
        sales[key]![idx] += qty;
        if (actualSqft != null) {
          productSqftTotal[key]  = (productSqftTotal[key]  ?? 0) + actualSqft;
          productUnitsTotal[key] = (productUnitsTotal[key] ?? 0) + qty;
        }
        for (final b in bom) {
          final mid = b['material_id']?.toString() ?? '';
          final qpu = (b['quantity_per_unit'] as num?)?.toDouble() ?? 1.0;
          if (mid.isEmpty || !periodSqft.containsKey(mid)) continue;
          periodSqft[mid]![idx] += actualSqft ?? (qty * qpu);
        }
      }

      final seen   = <String>{};
      final allOrd = [...ordSnap.docs, ...oqSnap.docs]
          .where((d) => seen.add(d.id)).toList();

      for (final doc in allOrd) {
        final ts = doc.data()['created_at'] as Timestamp?;
        if (ts == null) continue;
        final idx = periodOf(ts); if (idx == null) continue;
        for (final p in (doc.data()['products'] as List? ?? [])
            .cast<Map<String, dynamic>>()) {
          final name     = (p['name']?.toString() ?? '').trim();
          final pid      = p['product_id']?.toString() ?? '';
          final qty      = (p['qty'] as num?)?.toDouble() ?? 1.0;
          final widthFt  = (p['width_ft']  as num?)?.toDouble();
          final heightFt = (p['height_ft'] as num?)?.toDouble();
          if (qty <= 0) continue;
          final bom = bomById[pid] ?? bomByName[name.toLowerCase()] ?? [];
          if (bom.isEmpty) continue;
          final key   = pid.isNotEmpty && bomById.containsKey(pid)
              ? pid : name.toLowerCase();
          final label = nameById[pid] ?? name;
          final actualSqft = (widthFt != null && heightFt != null)
              ? widthFt * heightFt * qty : null;
          addSale(key, label, bom, idx, qty, actualSqft: actualSqft);
        }
      }

      for (final doc in srSnap.docs) {
        final ts = doc.data()['sale_date'] as Timestamp?;
        if (ts == null) continue;
        final idx = periodOf(ts); if (idx == null) continue;
        for (final p in (doc.data()['products'] as List? ?? [])
            .cast<Map<String, dynamic>>()) {
          final name     = (p['name']?.toString() ?? '').trim();
          final qty      = (p['qty'] as num?)?.toDouble() ?? 1.0;
          final widthFt  = (p['width_ft']  as num?)?.toDouble();
          final heightFt = (p['height_ft'] as num?)?.toDouble();
          if (name.isEmpty || qty <= 0) continue;
          final bom = bomByName[name.toLowerCase()] ?? [];
          if (bom.isEmpty) continue;
          final actualSqft = (widthFt != null && heightFt != null)
              ? widthFt * heightFt * qty : null;
          addSale(name.toLowerCase(), name, bom, idx, qty, actualSqft: actualSqft);
        }
      }

      // Phase 1: DES per product.
      final holt = <String, _DES>{};
      for (final e in sales.entries) { holt[e.key] = _bestFit(e.value); }

      // Phase 2: Sources display — which products drive demand for each material.
      // periodSqft is already populated from actual order dimensions in addSale above.
      // effectiveQpu: average actual sqft/unit from real orders when available,
      // falls back to the BOM qpu for products without dimension data.
      final sourcesMap = <String, List<_Source>>{};

      for (final e in sales.entries) {
        final key  = e.key;
        final des  = holt[key]!;
        final fQty = des.forecast(1);
        final bom  = bomKey[key] ?? [];

        final totalSqft  = productSqftTotal[key]  ?? 0.0;
        final totalUnits = productUnitsTotal[key] ?? 0.0;
        final avgSqftPerUnit = (totalUnits > 0) ? totalSqft / totalUnits : null;

        for (final b in bom) {
          final mid      = b['material_id']?.toString() ?? '';
          final bomQpu   = (b['quantity_per_unit'] as num?)?.toDouble() ?? 1.0;
          if (mid.isEmpty || !periodSqft.containsKey(mid)) continue;

          // Use the average real sqft/unit if available; otherwise fall back to BOM qpu.
          final effectiveQpu = avgSqftPerUnit ?? bomQpu;

          if (fQty >= 0.001) {
            final contrib = fQty * effectiveQpu;
            sourcesMap.putIfAbsent(mid, () => []).add(_Source(
              name: display[key] ?? key,
              forecastQty: fQty, qpu: effectiveQpu,
              mape: des.mape, alpha: des.alpha, beta: des.beta,
              contribution: contrib,
            ));
          }
        }
      }

      // Phase 3: DES on each material's aggregated consumption history.
      final materialDES = <String, _DES>{};
      for (final id in mats.keys) {
        materialDES[id] =
            _bestFit(periodSqft[id] ?? List.filled(_nPeriods, 0.0));
      }

      // Build _Material per raw material.
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

        final mDes = materialDES[id]!;
        double fRaw30 = mDes.forecast(1); // next 30d in base units
        bool isSynthetic = false;

        if (fRaw30 < 0.001 && rawRestock > 0.001) {
          final synth = List.generate(_nPeriods, (i) =>
              i < _nPeriods - 12 ? 0.0 : rawRestock);
          fRaw30 = _bestFit(synth).forecast(1);
          isSynthetic = true;
        }

        // Multi-horizon forecasts in stocking units.
        // 7d  ≈ forecast(1) × (7/30)   using the same DES state
        // 30d = forecast(1)  (one full period)
        // 90d = forecast(3)  (three periods ahead)
        final fSU30 = toSU(fRaw30);
        final fSU7  = fSU30 * (7.0 / _periodDays);
        final fRaw90 = isSynthetic ? fRaw30 * 3 : mDes.forecast(3);
        final fSU90 = toSU(math.max(0.0, fRaw90));

        final daily    = fSU30 / _periodDays;
        final daysLeft = daily > 0.001 ? stock / daily : double.infinity;
        final daysRest = daily > 0.001 && stock > restock
            ? (stock - restock) / daily
            : (stock <= restock ? 0.0 : double.infinity);

        // Smarter reorder: order enough for next 30d demand AND restore safety stock.
        final reorderQty = math.max(0.0, fSU30 + restock - stock);

        final srcs = sourcesMap[id] ?? [];

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

        // Build Forecast vs Actual history from material DES in-sample fits.
        // mDes.fits[i] is the 1-step-ahead forecast for the (i+1)th non-zero period.
        // Take up to 6 most recent pairs.
        final rawAccActuals = mDes.actuals.map(toSU).toList();
        final rawAccFitted  = mDes.fits.map(toSU).toList();
        final accStart = rawAccActuals.length > 6
            ? rawAccActuals.length - 6 : 0;
        final accActuals = rawAccActuals.sublist(accStart);
        final accFitted  = rawAccFitted.sublist(accStart);

        result.add(_Material(
          id: id, name: name, unit: unit,
          stock: stock, restock: restock,
          forecast7d:  fSU7,
          forecast30d: fSU30,
          forecast90d: fSU90,
          dailyRate: daily,
          daysLeft: daysLeft, daysToRestock: daysRest,
          reorderQty: reorderQty,
          weightedMape: isSynthetic ? null : wMape,
          sources: srcs, periods: ps,
          synthetic: isSynthetic,
          trendSlope: toSU(mDes.T),
          accActuals: accActuals,
          accFitted:  accFitted,
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
      // Status filter
      switch (_filter) {
        case 'Critical':  if (m.status != _Status.critical)  return false;
        case 'At Risk':   if (m.status != _Status.atRisk)    return false;
        case 'Healthy':   if (m.status != _Status.healthy)   return false;
        case 'Overstock': if (m.status != _Status.overstock) return false;
        case 'No Demand': if (m.status != _Status.noDemand)  return false;
      }
      // Search filter
      if (_search.isNotEmpty &&
          !m.name.toLowerCase().contains(_search.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
    list.sort((a, b) {
      final da = a.daysLeft.isInfinite ? 99999.0 : a.daysLeft;
      final db = b.daysLeft.isInfinite ? 99999.0 : b.daysLeft;
      return da.compareTo(db);
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 0.9),
          boxShadow: const [BoxShadow(
            color: Color(0x22000000),
            blurRadius: 32,
            spreadRadius: -4,
            offset: Offset(0, 8),
          )],
        ),
        child: Column(children: [
          _header(),
          Expanded(
            child: _visible.isEmpty
                ? Center(child: Text(
                    _search.isNotEmpty
                        ? 'No materials matching "$_search".'
                        : 'No "$_filter" materials.',
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
        ]),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _header() {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Title + action buttons + collapse toggle
        Row(children: [
          const Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Inventory Forecast',
                  style: TextStyle(color: _navy, fontSize: 15,
                      fontWeight: FontWeight.w800)),
              SizedBox(height: 1),
              Text("Holt's DES (α+β auto, 56-pt grid) · 3-yr history · BOM explosion",
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
          const SizedBox(width: 6),
          // Collapse / expand search + filter
          GestureDetector(
            onTap: () => setState(() => _filtersVisible = !_filtersVisible),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _filtersVisible
                    ? _navy.withValues(alpha: 0.08)
                    : _navy.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: _navy.withValues(alpha: 0.25)),
              ),
              child: AnimatedRotation(
                turns: _filtersVisible ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 220),
                child: Icon(Icons.expand_more_rounded, size: 14,
                    color: _navy.withValues(alpha: 0.85)),
              ),
            ),
          ),
        ]),

        // Collapsible search bar + status chips
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _filtersVisible
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 10),

                  // Search bar
                  Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: _navy, fontSize: 12),
                      textAlignVertical: TextAlignVertical.center,
                      onChanged: (v) => setState(() => _search = v),
                      decoration: InputDecoration(
                        hintText: 'Search materials…',
                        hintStyle: TextStyle(color: _slate.withValues(alpha: 0.5), fontSize: 12),
                        prefixIcon: const Icon(Icons.search_rounded, size: 16, color: _slate),
                        suffixIcon: _search.isNotEmpty
                            ? GestureDetector(
                                onTap: () { _searchCtrl.clear(); setState(() => _search = ''); },
                                child: const Icon(Icons.close_rounded, size: 14, color: _slate))
                            : null,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Status summary chips (All + each status)
                  SingleChildScrollView(scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      _SChip('All',       _all.length,              _navy,    _filter == 'All',
                          () => _setFilter('All')),
                      _SChip('Critical',  _cnt(_Status.critical),   _rose,    _filter == 'Critical',
                          () => _setFilter('Critical')),
                      _SChip('At Risk',   _cnt(_Status.atRisk),     _amber,   _filter == 'At Risk',
                          () => _setFilter('At Risk')),
                      _SChip('Healthy',   _cnt(_Status.healthy),    _emerald, _filter == 'Healthy',
                          () => _setFilter('Healthy')),
                      _SChip('Overstock', _cnt(_Status.overstock),  _indigo,  _filter == 'Overstock',
                          () => _setFilter('Overstock')),
                      _SChip('No Demand', _cnt(_Status.noDemand),   _slate,   _filter == 'No Demand',
                          () => _setFilter('No Demand')),
                    ]),
                  ),
                ])
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }

  void _setFilter(String f) => setState(() => _filter = f);

  void _openDiag(BuildContext ctx) => showModalBottomSheet(
    context: ctx, isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _DiagSheet(),
  );

  Widget _splash(String msg) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.9),
        boxShadow: const [BoxShadow(
          color: Color(0x22000000),
          blurRadius: 32,
          spreadRadius: -4,
          offset: Offset(0, 8),
        )],
      ),
      child: Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_loading)
            const CircularProgressIndicator(color: _navy, strokeWidth: 2),
          if (!_loading)
            const Icon(Icons.inventory_2_outlined, size: 40, color: _muted),
          const SizedBox(height: 14),
          Text(msg, style: const TextStyle(color: _muted, fontSize: 13)),
        ],
      )),
    ),
  );

  Widget _errView() => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.9),
        boxShadow: const [BoxShadow(
          color: Color(0x22000000),
          blurRadius: 32,
          spreadRadius: -4,
          offset: Offset(0, 8),
        )],
      ),
      child: Center(child: Padding(
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
      )),
    ),
  );
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
              // Main info
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + trend arrow + status badge
                  Row(children: [
                    Expanded(child: Text(m.name,
                        style: const TextStyle(color: _navy,
                            fontSize: 13, fontWeight: FontWeight.w700),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                    // Trend direction icon
                    if (m.dailyRate > 0.001) ...[
                      const SizedBox(width: 4),
                      _TrendIcon(dir: m.trendDir),
                    ],
                    if (m.synthetic) ...[
                      const SizedBox(width: 4),
                      _Badge('~Est', _slate),
                    ],
                    const SizedBox(width: 6),
                    _Badge(m.statusLabel, color),
                  ]),
                  const SizedBox(height: 5),

                  // Stock numbers + MAPE badge
                  Row(children: [
                    Text(
                      m.unit.isEmpty
                          ? 'Stock: ${_fmt(m.stock)}'
                          : 'Stock: ${_fmt(m.stock)} ${m.unit}',
                      style: const TextStyle(color: _slate, fontSize: 11)),
                    const Spacer(),
                    if (m.status != _Status.noDemand && m.weightedMape != null)
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

                  // Forecast next 30d
                  if (m.forecast30d > 0.001) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${m.synthetic ? 'Est. baseline' : 'Forecast'} next 30d: '
                      '${_fmt(m.forecast30d)}'
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
            Divider(height: 1, color: color.withValues(alpha: 0.20)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                // ── Multi-horizon forecast strip ───────────────────────────
                Row(children: [
                  Expanded(child: _HorizonBox('7-day',
                      '${_fmt(m.forecast7d)}${m.unit.isNotEmpty ? ' ${m.unit}' : ''}',
                      _slate)),
                  const SizedBox(width: 6),
                  Expanded(child: _HorizonBox('30-day',
                      '${_fmt(m.forecast30d)}${m.unit.isNotEmpty ? ' ${m.unit}' : ''}',
                      _navy)),
                  const SizedBox(width: 6),
                  Expanded(child: _HorizonBox('90-day',
                      '${_fmt(m.forecast90d)}${m.unit.isNotEmpty ? ' ${m.unit}' : ''}',
                      _indigo)),
                ]),
                const SizedBox(height: 10),

                // ── Key stats grid ─────────────────────────────────────────
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _StatBox('Restock Level',
                    '${_fmt(m.restock)} ${m.unit}', _slate),
                  if (m.status != _Status.noDemand && m.weightedMape != null)
                    _StatBox('MAPE', '${m.mapeText}  ${m.mapeGrade}',
                      m.mapeColor),
                  _StatBox('Suggest Reorder',
                    m.reorderQty < 0.001
                        ? 'None' : '${_fmt(m.reorderQty)} ${m.unit}',
                    _emerald),
                  _StatBox('Trend',
                    m.trendDir == _TrendDir.up   ? '↑ Rising'
                      : m.trendDir == _TrendDir.down ? '↓ Falling'
                      : '→ Stable',
                    m.trendDir == _TrendDir.up   ? _rose
                      : m.trendDir == _TrendDir.down ? _emerald
                      : _slate),
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
                    Text('α and β auto-selected per product (56-pt grid) to minimise MAPE.',
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

                // ── Forecast vs Actual ────────────────────────────────────
                if (m.accActuals.isNotEmpty) ...[
                  sectionLabel('Forecast vs Actual  (last ${m.accActuals.length} periods)'),
                  const SizedBox(height: 6),
                  _accuracyTable(m),
                  const SizedBox(height: 12),
                ],

                // ── Period history table ───────────────────────────────────
                sectionLabel('Consumption History  (last 12 of 36 periods)'),
                const SizedBox(height: 6),
                _periodTable(m),
                const SizedBox(height: 8),

              ]),
            ),
          ],
        ]),
      ),
    );
  }

  // ── Sub-widgets ─────────────────────────────────────────────────────────────

  Widget _accuracyTable(_Material m) {
    final actuals = m.accActuals;
    final fitted  = m.accFitted;
    final n       = actuals.length;
    final unit    = m.unit.isNotEmpty ? ' ${m.unit}' : '';

    return Container(
      decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
          child: Row(children: [
            _th('Period',   flex: 3),
            _th('Actual',   flex: 3, right: true),
            _th('Forecast', flex: 3, right: true),
            _th('Error',    flex: 2, right: true),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        for (int i = 0; i < n; i++) ...[
          Builder(builder: (_) {
            final fromEnd = n - 1 - i; // 0 = most recent period with a fit
            final actual  = actuals[i];
            final fcast   = fitted[i];
            final errPct  = actual > 0.001
                ? ((actual - fcast) / actual * 100).abs() : null;
            final label = fromEnd == 0 ? 'Last 30d'
                : fromEnd == 1 ? '30–60d ago'
                : fromEnd == 2 ? '60–90d ago'
                : '${(fromEnd + 1) * 30}d+ ago';
            final errColor = errPct == null ? _muted
                : errPct < 10  ? _emerald
                : errPct < 25  ? _lime
                : errPct < 50  ? _amber : _rose;
            final isRecent = fromEnd <= 1;
            return Container(
              color: isRecent ? _navy.withValues(alpha: 0.02) : null,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(children: [
                Expanded(flex: 3, child: Text(label,
                    style: TextStyle(
                        color: isRecent ? _navy.withValues(alpha: 0.75) : _slate,
                        fontSize: 10,
                        fontWeight: isRecent ? FontWeight.w700 : FontWeight.w400))),
                Expanded(flex: 3, child: Text(
                    actual < 0.001 ? '—' : '${_fmt(actual)}$unit',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: actual > 0.001 ? _navy : _muted,
                        fontSize: 10, fontWeight: FontWeight.w600))),
                Expanded(flex: 3, child: Text(
                    '${_fmt(fcast)}$unit',
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: _slate, fontSize: 10))),
                Expanded(flex: 2, child: Text(
                    errPct == null ? '—'
                        : '${errPct.toStringAsFixed(1)}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: errColor,
                        fontSize: 10, fontWeight: FontWeight.w700))),
              ]),
            );
          }),
          if (i < n - 1) const Divider(height: 1, color: Color(0xFFF1F5F9)),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(8))),
          child: Text(
            'Forecast = 1-step-ahead in-sample fit using only data before that period.',
            style: TextStyle(color: _slate.withValues(alpha: 0.6),
                fontSize: 9, fontStyle: FontStyle.italic),
          ),
        ),
      ]),
    );
  }

  Widget _sourcesTable(_Material m) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
          child: Row(children: [
            _th('Product', flex: 4),
            _th('α / β',   flex: 2),
            _th('F(t+1)',     flex: 2, right: true),
            _th('× sqft/u',  flex: 2, right: true),
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
                child: Text(_fmt(m.forecast30d),
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
    final maxVal = slice.fold(0.0, math.max);

    return Container(
      decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
          child: Row(children: [
            _th('Period', flex: 3),
            _th('Consumption', flex: 4, right: true),
            _th('Bar', flex: 3, right: false),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        for (int i = 0; i < slice.length; i++) ...[
          Builder(builder: (_) {
            final v       = slice[i];
            final fromEnd = slice.length - 1 - i;
            final label  = fromEnd == 0 ? 'P1  last 30d'
                : fromEnd == 1 ? 'P2  30–60d ago'
                : fromEnd == 2 ? 'P3  60–90d ago'
                : 'P${fromEnd + 1}  ${(fromEnd + 1) * 30}d+';
            final barPct  = maxVal > 0 ? (v / maxVal).clamp(0.0, 1.0) : 0.0;
            return Container(
              color: fromEnd < 3 ? _navy.withValues(alpha: 0.02) : null,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                // Mini bar
                Expanded(flex: 3, child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: barPct,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation(
                          fromEnd < 3 ? _navy.withValues(alpha: 0.6) : _slate.withValues(alpha: 0.35)),
                    ),
                  ),
                )),
              ]),
            );
          }),
          if (i < slice.length - 1)
            const Divider(height: 1, color: Color(0xFFF8FAFC)),
        ],
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
                m.forecast30d < 0.001 ? '0' : _fmt(m.forecast30d),
                textAlign: TextAlign.right,
                style: const TextStyle(color: _navy, fontSize: 11,
                    fontWeight: FontWeight.w800))),
            const Expanded(flex: 3, child: SizedBox()),
          ]),
        ),
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
// Mini sparkline — last 8 periods as bar chart
// ─────────────────────────────────────────────────────────────────────────────

class _MiniSparkline extends StatelessWidget {
  final List<double> periods;
  final Color color;
  const _MiniSparkline({required this.periods, required this.color});

  @override
  Widget build(BuildContext context) {
    final start = math.max(0, periods.length - 8);
    final slice = periods.sublist(start);
    final maxVal = slice.fold(0.0, math.max);
    if (maxVal < 0.001) return const SizedBox.shrink();

    return SizedBox(
      height: 20,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(slice.length, (i) {
          final pct = (slice[i] / maxVal).clamp(0.0, 1.0);
          final isLast = i == slice.length - 1;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Container(
                height: math.max(2, 20 * pct),
                decoration: BoxDecoration(
                  color: isLast
                      ? color.withValues(alpha: 0.85)
                      : color.withValues(alpha: 0.30 + 0.07 * i),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trend direction icon
// ─────────────────────────────────────────────────────────────────────────────

class _TrendIcon extends StatelessWidget {
  final _TrendDir dir;
  const _TrendIcon({required this.dir});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (dir) {
      _TrendDir.up   => (Icons.trending_up_rounded,   _rose),
      _TrendDir.down => (Icons.trending_down_rounded, _emerald),
      _TrendDir.flat => (Icons.trending_flat_rounded, _slate),
    };
    return Icon(icon, size: 14, color: color.withValues(alpha: 0.8));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Multi-horizon box
// ─────────────────────────────────────────────────────────────────────────────

class _HorizonBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _HorizonBox(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.20))),
    child: Column(children: [
      Text(label, style: TextStyle(
          color: color.withValues(alpha: 0.7),
          fontSize: 9, fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      Text(value,
          style: TextStyle(color: color, fontSize: 11,
              fontWeight: FontWeight.w800),
          maxLines: 1, overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center),
    ]),
  );
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
