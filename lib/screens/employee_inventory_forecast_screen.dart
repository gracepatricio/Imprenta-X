import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';

/// Inventory Forecast Screen — Employee side
///
/// Forecasting aligned with the TechnoTams thesis specification:
///   • Double Exponential Smoothing (DES) — Brown's method
///       S'_t  = α·X_t  + (1−α)·S'_{t-1}
///       S''_t = α·S'_t + (1−α)·S''_{t-1}
///       a_t   = 2·S'_t − S''_t
///       b_t   = α/(1−α) · (S'_t − S''_t)
///       F_{t+m} = a_t + b_t · m
///   • MAPE = (1/n) Σ |X_t − F_t| / X_t × 100%
///     (accumulated over one-step-ahead DES forecasts, not naïve period diff)

// ── Liquid Glass Design Tokens ───────────────────────────────────────────────
class _Glass {
  static const Color surface     = Color(0xF8FFFFFF);
  static const Color surfaceMid  = Color(0xF0FFFFFF);
  static const Color surfaceThin = Color(0xA0FFFFFF);

  static const Color borderMid = Color(0x70FFFFFF);
  static const Color borderDim = Color(0x30FFFFFF);

  static const Color textPrimary   = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xCC0F172A);
  static const Color textMuted     = Color(0x880F172A);

  static const Color accentEmerald = Color(0xFF10B981);
  static const Color accentRose    = Color(0xFFEF4444);
  static const Color accentAmber   = Color(0xFFB45309);

  static const BoxShadow elevatedShadow = BoxShadow(
    color: Color(0x22000000),
    blurRadius: 32,
    spreadRadius: -4,
    offset: Offset(0, 8),
  );
  static const BoxShadow rowShadow = BoxShadow(
    color: Color(0x10000000),
    blurRadius: 10,
    offset: Offset(0, 3),
  );

  static BoxDecoration glass({
    double radius = 16,
    bool elevated = false,
    Color? tintBorder,
  }) =>
      BoxDecoration(
        color: surfaceMid,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: tintBorder ?? borderMid, width: 0.9),
        boxShadow: [elevated ? elevatedShadow : rowShadow],
      );

  static BoxDecoration solidPill(Color color, {bool glow = false}) =>
      BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: glow ? 0.38 : 0.22),
            blurRadius: glow ? 16 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      );
}

const Color _navyBlue   = Color(0xFF0F1A2E);
final _blurFilter = ImageFilter.blur(sigmaX: 14, sigmaY: 14);

// ─────────────────────────────────────────────────────────────────────────────
// DES helper
// ─────────────────────────────────────────────────────────────────────────────

/// Result of running DES over a series of observations.
class _DesResult {
  /// Level component at the last fitted data point.
  final double aLast;

  /// Trend component at the last fitted data point.
  final double bLast;

  /// MAPE (%) over the one-step-ahead in-sample forecasts.
  /// Null when there are fewer than 2 data points (no forecast comparisons).
  final double? mape;

  /// One-step-ahead DES forecasts for t = 2 … n  (same length as [actuals]).
  final List<double> forecasts;

  /// Actual values for t = 2 … n, paired with [forecasts].
  final List<double> actuals;

  const _DesResult({
    required this.aLast,
    required this.bLast,
    required this.mape,
    required this.forecasts,
    required this.actuals,
  });

  /// DES forecast m periods ahead from the last fitted point.
  ///   F_{last+m} = a_last + b_last × m
  double forecastAhead(int m) => aLast + bLast * m;
}

/// Runs Double Exponential Smoothing (Brown's method) over [series].
///
/// Formulas from the TechnoTams thesis (Pradnyani et al., 2024):
///   S'_t  = α·X_t  + (1−α)·S'_{t-1}        — first smoothing
///   S''_t = α·S'_t + (1−α)·S''_{t-1}        — second smoothing
///   a_t   = 2·S'_t  − S''_t                  — level estimate
///   b_t   = α/(1−α) · (S'_t − S''_t)         — trend estimate
///   F_{t+m} = a_t + b_t · m                  — m-step-ahead forecast
///   MAPE  = (1/n) Σ |X_t − F_t| / X_t × 100 — accuracy metric
///
/// Initialization: S'_1 = S''_1 = X_1  (standard Brown initialization).
/// [alpha] must be in the open interval (0, 1).
_DesResult _runDes(List<double> series, {double alpha = 0.5}) {
  assert(alpha > 0 && alpha < 1,
  'Smoothing constant α must be in (0, 1). Got: $alpha');

  final n = series.length;
  if (n == 0) {
    return const _DesResult(
      aLast: 0, bLast: 0, mape: null, forecasts: [], actuals: [],
    );
  }

  // ── Initialization: S'_1 = S''_1 = X_1 ───────────────────────────────────
  double sp  = series[0]; // S'_t
  double spp = series[0]; // S''_t

  // Compute a_1, b_1 from initialization
  double a = 2 * sp - spp;
  double b = (alpha / (1 - alpha)) * (sp - spp);

  final forecasts = <double>[];
  final actuals   = <double>[];
  final apes      = <double>[];

  // ── Iterate t = 2 … n ─────────────────────────────────────────────────────
  for (int t = 1; t < n; t++) {
    // One-step-ahead forecast using level & trend from previous step (m = 1)
    final double forecastT = a + b * 1;
    final double actualT   = series[t];

    forecasts.add(forecastT);
    actuals.add(actualT);

    // APE for this step: |X_t − F_t| / X_t × 100
    // Guard against division by zero when actual consumption is essentially 0
    if (actualT > 0.001) {
      apes.add(((actualT - forecastT) / actualT).abs() * 100);
    }

    // ── Update smoothing values ─────────────────────────────────────────────
    // S'_t  = α·X_t  + (1−α)·S'_{t-1}
    sp  = alpha * actualT + (1 - alpha) * sp;
    // S''_t = α·S'_t + (1−α)·S''_{t-1}
    spp = alpha * sp      + (1 - alpha) * spp;

    // ── Recompute level and trend ───────────────────────────────────────────
    // a_t = 2·S'_t − S''_t
    a = 2 * sp - spp;
    // b_t = α/(1−α) · (S'_t − S''_t)
    b = (alpha / (1 - alpha)) * (sp - spp);
  }

  // MAPE = (1/n) Σ APE_t
  final double? mape = apes.isEmpty
      ? null
      : apes.reduce((x, y) => x + y) / apes.length;

  return _DesResult(
    aLast: a,
    bLast: b,
    mape: mape,
    forecasts: forecasts,
    actuals: actuals,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class EmployeeInventoryForecastScreen extends StatefulWidget {
  const EmployeeInventoryForecastScreen({super.key});

  @override
  State<EmployeeInventoryForecastScreen> createState() =>
      _EmployeeInventoryForecastScreenState();
}

class _EmployeeInventoryForecastScreenState
    extends State<EmployeeInventoryForecastScreen> {
  // ── State ──────────────────────────────────────────────────────────────────
  bool _loading = true;
  String? _error;

  List<_ForecastItem> _items = [];

  // Filter / sort
  String _filter = 'All';       // All | Critical | At Risk | Healthy
  String _sort   = 'Days Left'; // Days Left | Name | Consumption | MAPE

  static const _windowDays = 90;
  static const _periodDays = 30;

  /// DES smoothing constant α — fixed in (0, 1) per thesis specification.
  static const double _alpha = 0.5;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error   = null;
    });
    try {
      final db  = FirebaseFirestore.instance;
      final now = DateTime.now();

      final nowTs   = Timestamp.fromDate(now);
      final p1Start = Timestamp.fromDate(now.subtract(const Duration(days: 30)));
      final p2Start = Timestamp.fromDate(now.subtract(const Duration(days: 60)));
      final p3Start = Timestamp.fromDate(now.subtract(const Duration(days: 90)));

      final matSnap   = await db.collection('RawMaterials').get();
      final materials = {
        for (final d in matSnap.docs) d.id: d.data(),
      };

      final prodSnap = await db.collection('Products').get();
      final bomByProductId   = <String, List<Map<String, dynamic>>>{};
      final bomByProductName = <String, List<Map<String, dynamic>>>{};
      for (final d in prodSnap.docs) {
        final bom = (d.data()['bill_of_materials'] as List?)
            ?.cast<Map<String, dynamic>>() ?? [];
        bomByProductId[d.id] = bom;
        final name = d.data()['product_name']?.toString() ?? '';
        if (name.isNotEmpty) bomByProductName[name] = bom;
      }

      void accumulateOrders(
          List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
          Timestamp from,
          Timestamp to,
          Map<String, double> target,
          ) {
        for (final orderDoc in docs) {
          final createdAt = orderDoc.data()['created_at'] as Timestamp?;
          if (createdAt == null) continue;
          if (createdAt.compareTo(from) < 0) continue;
          if (createdAt.compareTo(to) >= 0) continue;

          final products = (orderDoc.data()['products'] as List?)
              ?.cast<Map<String, dynamic>>() ?? [];
          for (final p in products) {
            final pid  = p['product_id']?.toString() ?? '';
            final name = p['name']?.toString() ?? '';
            final qty  = (p['qty'] as num?)?.toDouble() ?? 1;
            final bom  = bomByProductId[pid] ?? bomByProductName[name] ?? [];
            for (final bomItem in bom) {
              final matId = bomItem['material_id']?.toString() ?? '';
              final qpu   = (bomItem['quantity_per_unit'] as num?)?.toDouble() ?? 1;
              if (matId.isEmpty) continue;
              target[matId] = (target[matId] ?? 0) + qty * qpu;
            }
          }
        }
      }

      final orderSnap = await db
          .collection('Orders')
          .where('status', isEqualTo: 'completed')
          .get();

      final consumedP1 = <String, double>{};
      final consumedP2 = <String, double>{};
      final consumedP3 = <String, double>{};

      accumulateOrders(orderSnap.docs, p1Start, nowTs,   consumedP1);
      accumulateOrders(orderSnap.docs, p2Start, p1Start, consumedP2);
      accumulateOrders(orderSnap.docs, p3Start, p2Start, consumedP3);

      final replenishedPerMaterial = <String, double>{};
      final logSnap = await db.collection('InventoryLogs').get();
      for (final d in logSnap.docs) {
        final ts = d.data()['timestamp'] as Timestamp?;
        if (ts != null && ts.compareTo(p3Start) < 0) continue;
        final matId = d.data()['material_id']?.toString() ?? '';
        final qty   = (d.data()['quantity_added'] as num?)?.toDouble() ?? 0;
        if (matId.isEmpty) continue;
        replenishedPerMaterial[matId] =
            (replenishedPerMaterial[matId] ?? 0) + qty;
      }

      final items = <_ForecastItem>[];
      for (final entry in materials.entries) {
        final matId   = entry.key;
        final data    = entry.value;
        final name    = data['material_name']?.toString() ?? matId;
        final unit    = data['unit_description']?.toString() ?? '';
        final stock   = (data['current_stock'] as num?)?.toDouble() ?? 0;
        final restock = (data['restock_level'] as num?)?.toDouble() ?? 0;

        // ── Period consumption totals ──────────────────────────────────────
        final c1 = consumedP1[matId] ?? 0.0; // last 30 d
        final c2 = consumedP2[matId] ?? 0.0; // 30–60 d ago
        final c3 = consumedP3[matId] ?? 0.0; // 60–90 d ago

        // Average daily rates per period (these are X_t for DES)
        final r1 = c1 / _periodDays; // X_3 — most recent (last 30 d)
        final r2 = c2 / _periodDays; // X_2 — middle period
        final r3 = c3 / _periodDays; // X_1 — oldest period

        // ── Double Exponential Smoothing ───────────────────────────────────
        // Series fed chronologically oldest → newest: [r3, r2, r1]
        // DES needs at least 2 non-zero points to produce a meaningful model.
        final hasSufficientData = (r3 > 0.001 || r2 > 0.001 || r1 > 0.001);
        final desSeries = [r3, r2, r1];
        final des = hasSufficientData
            ? _runDes(desSeries, alpha: _alpha)
            : _DesResult(
            aLast: 0, bLast: 0, mape: null, forecasts: [], actuals: []);

        // ── Daily rate for stockout / restock estimates ────────────────────
        // Use the DES one-step-ahead forecast for next period as the forward
        // rate; fall back to the raw 90-day average when DES has no data.
        final totalConsumed = c1 + c2 + c3;
        final replenished   = replenishedPerMaterial[matId] ?? 0;

        double dailyRate;
        if (hasSufficientData) {
          // DES forecast 1 period ahead (= next 30 d), converted to daily
          final forecastNext30 = des.forecastAhead(1).clamp(0.0, double.infinity);
          dailyRate = forecastNext30 / _periodDays;
        } else {
          dailyRate = totalConsumed > 0
              ? totalConsumed / _windowDays
              : (replenished > 0 ? replenished / _windowDays : 0.0);
        }

        final daysUntilStockout = dailyRate > 0.001
            ? (stock / dailyRate)
            : double.infinity;
        final daysUntilRestock  = (dailyRate > 0.001 && stock > restock)
            ? ((stock - restock) / dailyRate)
            : (stock <= restock ? 0.0 : double.infinity);

        // ── 30-day recommended order quantity ─────────────────────────────
        // Based on the DES forecast for the next period minus current stock.
        final forecastNext30 = hasSufficientData
            ? des.forecastAhead(1).clamp(0.0, double.infinity)
            : dailyRate * 30;
        final recommended30 = math.max(0.0, forecastNext30 - stock);

        items.add(_ForecastItem(
          materialId:        matId,
          name:              name,
          unit:              unit,
          currentStock:      stock,
          restockLevel:      restock,
          dailyRate:         dailyRate,
          dailyRateP1:       r1,
          dailyRateP2:       r2,
          dailyRateP3:       r3,
          daysUntilStockout: daysUntilStockout,
          daysUntilRestock:  daysUntilRestock,
          consumed90d:       totalConsumed,
          replenished90d:    replenished,
          recommended30:     recommended30,
          desResult:         des,
        ));
      }

      setState(() {
        _items   = items;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error   = e.toString();
        _loading = false;
      });
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<_ForecastItem> get _filtered {
    var list = _items.where((it) {
      switch (_filter) {
        case 'Critical': return it.urgency == _Urgency.critical;
        case 'At Risk':  return it.urgency == _Urgency.atRisk;
        case 'Healthy':  return it.urgency == _Urgency.healthy;
        default:         return true;
      }
    }).toList();

    list.sort((a, b) {
      switch (_sort) {
        case 'Name':
          return a.name.compareTo(b.name);
        case 'Consumption':
          return b.dailyRate.compareTo(a.dailyRate);
        case 'MAPE':
          final ma = a.mape ?? double.infinity;
          final mb = b.mape ?? double.infinity;
          return mb.compareTo(ma);
        default:
          final da = a.daysUntilStockout.isInfinite ? 99999 : a.daysUntilStockout;
          final db = b.daysUntilStockout.isInfinite ? 99999 : b.daysUntilStockout;
          return da.compareTo(db);
      }
    });

    return list;
  }

  int _countByUrgency(_Urgency u) =>
      _items.where((it) => it.urgency == u).length;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: _navyBlue.withValues(alpha: 0.4),
              strokeWidth: 2,
            ),
            const SizedBox(height: 14),
            const Text(
              'Analysing inventory…',
              style: TextStyle(color: _Glass.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  color: _Glass.accentRose, size: 44),
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                    color: _Glass.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _load,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: _Glass.solidPill(_navyBlue, glow: true),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded,
                          size: 14, color: Colors.white),
                      SizedBox(width: 6),
                      Text('Retry',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: _Glass.glass(radius: 22),
              child: const Icon(Icons.inventory_2_outlined,
                  size: 32, color: _Glass.textMuted),
            ),
            const SizedBox(height: 20),
            const Text('No materials found',
                style: TextStyle(
                    color: _Glass.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    final filtered = _filtered;
    final critical = _countByUrgency(_Urgency.critical);
    final atRisk   = _countByUrgency(_Urgency.atRisk);
    final healthy  = _countByUrgency(_Urgency.healthy);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: _blurFilter,
        child: Container(
          decoration: _Glass.glass(radius: 20, elevated: true),
          child: Column(
            children: [
              // ── Forecast header band ─────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFAFBFC),
                  border: Border(
                    bottom: BorderSide(
                        color: _Glass.borderDim, width: 0.8),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row
                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Inventory Forecast',
                                style: TextStyle(
                                  color: _Glass.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              SizedBox(height: 1),
                              Text(
                                'DES model · 90-day history · MAPE accuracy',
                                style: TextStyle(
                                    color: _Glass.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _load,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: _Glass.surfaceThin,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                  color: _Glass.borderMid, width: 0.9),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh_rounded,
                                    size: 14,
                                    color: _Glass.textSecondary),
                                SizedBox(width: 6),
                                Text('Refresh',
                                    style: TextStyle(
                                        color: _Glass.textSecondary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Urgency summary tiles ──────────────────────────────
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _SummaryTile(
                            label: 'Critical',
                            count: critical,
                            color: _Glass.accentRose,
                            icon: Icons.warning_amber_rounded,
                            isActive: _filter == 'Critical',
                            onTap: () => setState(() => _filter =
                            _filter == 'Critical' ? 'All' : 'Critical'),
                          ),
                          _SummaryTile(
                            label: 'At Risk',
                            count: atRisk,
                            color: _Glass.accentAmber,
                            icon: Icons.access_time_rounded,
                            isActive: _filter == 'At Risk',
                            onTap: () => setState(() => _filter =
                            _filter == 'At Risk' ? 'All' : 'At Risk'),
                          ),
                          _SummaryTile(
                            label: 'Healthy',
                            count: healthy,
                            color: _Glass.accentEmerald,
                            icon: Icons.check_circle_outline_rounded,
                            isActive: _filter == 'Healthy',
                            onTap: () => setState(() => _filter =
                            _filter == 'Healthy' ? 'All' : 'Healthy'),
                          ),
                          _SummaryTile(
                            label: 'No Data',
                            count: _items
                                .where((i) => i.urgency == _Urgency.noData)
                                .length,
                            color: _Glass.textMuted,
                            icon: Icons.help_outline_rounded,
                            isActive: false,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Sort chips ─────────────────────────────────────────
                    Row(
                      children: [
                        const Text('Sort: ',
                            style: TextStyle(
                                color: _Glass.textMuted, fontSize: 11)),
                        ...['Days Left', 'Name', 'Consumption', 'MAPE']
                            .map((s) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () => setState(() => _sort = s),
                            child: AnimatedContainer(
                              duration:
                              const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: _sort == s
                                    ? _navyBlue
                                    : _Glass.surfaceThin,
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: _sort == s
                                      ? Colors.white
                                      .withValues(alpha: 0.20)
                                      : _Glass.borderMid,
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                s,
                                style: TextStyle(
                                  color: _sort == s
                                      ? Colors.white
                                      : _Glass.textSecondary,
                                  fontSize: 12,
                                  fontWeight: _sort == s
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        )),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // ── Legends ────────────────────────────────────────────
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: const [
                        _LegendDot(
                            color: _Glass.accentRose,
                            label: 'Critical ≤7d'),
                        _LegendDot(
                            color: _Glass.accentAmber,
                            label: 'At Risk ≤21d'),
                        _LegendDot(
                            color: _Glass.accentEmerald,
                            label: 'Healthy >21d'),
                        _LegendDot(
                            color: _Glass.accentEmerald,
                            label: 'MAPE Excellent <10%'),
                        _LegendDot(
                            color: Color(0xFF65A30D),
                            label: 'Good 10–25%'),
                        _LegendDot(
                            color: _Glass.accentAmber,
                            label: 'Fair 25–50%'),
                        _LegendDot(
                            color: _Glass.accentRose,
                            label: 'Poor ≥50%'),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Cards list ───────────────────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                  child: Text(
                    'No materials in "$_filter" category',
                    style: const TextStyle(
                        color: _Glass.textMuted, fontSize: 13),
                  ),
                )
                    : RefreshIndicator(
                  onRefresh: _load,
                  color: _navyBlue,
                  backgroundColor: _Glass.surface,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 8),
                    itemBuilder: (_, i) =>
                        _ForecastCard(item: filtered[i]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

enum _Urgency   { critical, atRisk, healthy, noData }
enum _MapeGrade { excellent, good, fair, poor, unavailable }

class _ForecastItem {
  final String materialId, name, unit;
  final double currentStock, restockLevel;

  /// Forward daily rate derived from the DES forecast for the next period.
  final double dailyRate;

  /// Raw daily rates per 30-day window (used for the trend display).
  final double dailyRateP1, dailyRateP2, dailyRateP3;

  final double daysUntilStockout, daysUntilRestock;
  final double consumed90d, replenished90d, recommended30;

  /// Full DES result (forecasts, actuals, MAPE, level/trend).
  final _DesResult desResult;

  const _ForecastItem({
    required this.materialId,
    required this.name,
    required this.unit,
    required this.currentStock,
    required this.restockLevel,
    required this.dailyRate,
    required this.dailyRateP1,
    required this.dailyRateP2,
    required this.dailyRateP3,
    required this.daysUntilStockout,
    required this.daysUntilRestock,
    required this.consumed90d,
    required this.replenished90d,
    required this.recommended30,
    required this.desResult,
  });

  // ── Convenience passthrough ────────────────────────────────────────────────

  double? get mape => desResult.mape;

  _Urgency get urgency {
    if (dailyRate < 0.001) return _Urgency.noData;
    if (daysUntilStockout <= 7 || currentStock <= 0) return _Urgency.critical;
    if (daysUntilStockout <= 21 || currentStock <= restockLevel) {
      return _Urgency.atRisk;
    }
    return _Urgency.healthy;
  }

  Color get urgencyColor {
    switch (urgency) {
      case _Urgency.critical: return _Glass.accentRose;
      case _Urgency.atRisk:   return _Glass.accentAmber;
      case _Urgency.healthy:  return _Glass.accentEmerald;
      case _Urgency.noData:   return _Glass.textMuted;
    }
  }

  String get urgencyLabel {
    switch (urgency) {
      case _Urgency.critical: return 'Critical';
      case _Urgency.atRisk:   return 'At Risk';
      case _Urgency.healthy:  return 'Healthy';
      case _Urgency.noData:   return 'No Data';
    }
  }

  String get daysLabel => daysUntilStockout.isInfinite
      ? '∞'
      : daysUntilStockout.toStringAsFixed(0);

  _MapeGrade get mapeGrade {
    if (mape == null) return _MapeGrade.unavailable;
    if (mape! < 10)   return _MapeGrade.excellent;
    if (mape! < 25)   return _MapeGrade.good;
    if (mape! < 50)   return _MapeGrade.fair;
    return _MapeGrade.poor;
  }

  String get mapeLabel =>
      mape == null ? 'N/A' : '${mape!.toStringAsFixed(1)}%';

  String get mapeGradeLabel {
    switch (mapeGrade) {
      case _MapeGrade.excellent:   return 'Excellent';
      case _MapeGrade.good:        return 'Good';
      case _MapeGrade.fair:        return 'Fair';
      case _MapeGrade.poor:        return 'Poor';
      case _MapeGrade.unavailable: return 'No Data';
    }
  }

  Color get mapeColor {
    switch (mapeGrade) {
      case _MapeGrade.excellent:   return _Glass.accentEmerald;
      case _MapeGrade.good:        return const Color(0xFF65A30D);
      case _MapeGrade.fair:        return _Glass.accentAmber;
      case _MapeGrade.poor:        return _Glass.accentRose;
      case _MapeGrade.unavailable: return _Glass.textMuted;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Forecast card
// ─────────────────────────────────────────────────────────────────────────────

class _ForecastCard extends StatefulWidget {
  final _ForecastItem item;
  const _ForecastCard({required this.item});

  @override
  State<_ForecastCard> createState() => _ForecastCardState();
}

class _ForecastCardState extends State<_ForecastCard> {
  bool _expanded = false;

  String _fmtNum(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final it       = widget.item;
    final color    = it.urgencyColor;
    final stockPct = it.restockLevel > 0
        ? (it.currentStock / (it.restockLevel * 3)).clamp(0.0, 1.0)
        : (it.currentStock > 0 ? 1.0 : 0.0);

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _expanded
              ? color.withValues(alpha: 0.04)
              : _Glass.surfaceMid,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _expanded
                ? color.withValues(alpha: 0.35)
                : _Glass.borderMid,
            width: _expanded ? 1.0 : 0.8,
          ),
          boxShadow: const [_Glass.rowShadow],
        ),
        child: Column(
          children: [
            // ── Collapsed row ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  // Days circle
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.10),
                      border: Border.all(
                          color: color.withValues(alpha: 0.35)),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            it.daysLabel,
                            style: TextStyle(
                              color: color,
                              fontSize:
                              it.daysLabel.length > 3 ? 9 : 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'days',
                            style: TextStyle(
                              color: color.withValues(alpha: 0.6),
                              fontSize: 7,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Name + bar + badges
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                it.name,
                                style: const TextStyle(
                                  color: _Glass.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Urgency badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                    color: color.withValues(alpha: 0.35),
                                    width: 0.8),
                              ),
                              child: Text(
                                it.urgencyLabel,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),

                        // Stock progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: stockPct,
                            minHeight: 4,
                            backgroundColor: _Glass.borderMid
                                .withValues(alpha: 0.4),
                            valueColor:
                            AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                        const SizedBox(height: 4),

                        Row(
                          children: [
                            Text(
                              it.unit.isNotEmpty
                                  ? 'Stock: ${_fmtNum(it.currentStock)} × ${it.unit}'
                                  : 'Stock: ${_fmtNum(it.currentStock)}',
                              style: const TextStyle(
                                  color: _Glass.textSecondary,
                                  fontSize: 11),
                            ),
                            const Spacer(),
                            // MAPE inline badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: it.mapeColor
                                    .withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: it.mapeColor
                                        .withValues(alpha: 0.30),
                                    width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.analytics_outlined,
                                      color: it.mapeColor, size: 8),
                                  const SizedBox(width: 3),
                                  Text(
                                    'MAPE ${it.mapeLabel}',
                                    style: TextStyle(
                                      color: it.mapeColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Chevron
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(Icons.keyboard_arrow_down,
                          color: _Glass.textMuted, size: 16),
                    ),
                  ),
                ],
              ),
            ),

            // ── Expanded detail ────────────────────────────────────────────
            if (_expanded)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(color: _Glass.borderDim, height: 1),
                    const SizedBox(height: 10),

                    // MAPE accuracy panel
                    _MapePanel(item: it),
                    const SizedBox(height: 8),

                    // Period trend sparkline
                    _PeriodTrend(item: it),
                    const SizedBox(height: 8),

                    // Stat chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _StatChip(
                          label: 'Days to Stockout',
                          value: it.daysUntilStockout.isInfinite
                              ? '∞ (no usage)'
                              : '~${it.daysUntilStockout.toStringAsFixed(0)} days',
                          color: color,
                        ),
                        _StatChip(
                          label: 'Days to Restock Level',
                          value: it.dailyRate < 0.001
                              ? '—'
                              : it.daysUntilRestock <= 0
                              ? 'Already below!'
                              : '~${it.daysUntilRestock.toStringAsFixed(0)} days',
                          color: _Glass.accentAmber,
                        ),
                        _StatChip(
                          label: '90-Day Consumption',
                          value: it.consumed90d > 0
                              ? _fmtNum(it.consumed90d)
                              : 'No order data',
                          color: const Color(0xFF1D4ED8),
                        ),
                        _StatChip(
                          label: '90-Day Replenishments',
                          value: it.replenished90d > 0
                              ? _fmtNum(it.replenished90d)
                              : 'None logged',
                          color: _Glass.accentEmerald,
                        ),
                        _StatChip(
                          label: 'Restock Level',
                          value: _fmtNum(it.restockLevel),
                          color: _Glass.textSecondary,
                        ),
                        _StatChip(
                          label: 'DES Next-30d Forecast',
                          value: it.desResult.aLast > 0.001 || it.desResult.bLast.abs() > 0.001
                              ? '${_fmtNum(it.desResult.forecastAhead(1).clamp(0, double.infinity))} ${it.unit}'
                              : 'Insufficient data',
                          color: _navyBlue,
                        ),
                      ],
                    ),

                    // Recommendation box
                    if (it.dailyRate > 0.001) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: color.withValues(alpha: 0.20),
                              width: 0.8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lightbulb_outline_rounded,
                                color: color, size: 14),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                _buildRecommendation(it),
                                style: TextStyle(
                                    color: color,
                                    fontSize: 11,
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (it.dailyRate < 0.001) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _Glass.surfaceThin,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: _Glass.borderMid, width: 0.8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: _Glass.textMuted, size: 13),
                            SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                'No consumption data in the last 90 days. '
                                    'Forecast will update once orders using this material are completed.',
                                style: TextStyle(
                                    color: _Glass.textMuted,
                                    fontSize: 11,
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _buildRecommendation(_ForecastItem it) {
    final orderQty = it.recommended30;
    final daysStr  = it.daysUntilStockout.isInfinite
        ? 'no foreseeable stockout'
        : '~${it.daysUntilStockout.toStringAsFixed(0)} days until stockout';
    final mapeNote = it.mape != null
        ? ' (MAPE ${it.mapeLabel} — ${it.mapeGradeLabel})'
        : '';

    if (it.urgency == _Urgency.critical) {
      return 'Urgent: $daysStr$mapeNote. '
          'Order at least ${_fmtNum(orderQty)} ${it.unit} immediately '
          'to cover the next 30 days per DES forecast.';
    }
    if (it.urgency == _Urgency.atRisk) {
      return 'Reorder soon — $daysStr$mapeNote. '
          'DES-recommended order for a 30-day buffer: '
          '${_fmtNum(orderQty)} ${it.unit}.';
    }
    return 'Stock is healthy ($daysStr)$mapeNote. '
        'DES next-30d top-up (if needed): ${_fmtNum(orderQty)} ${it.unit}.';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAPE accuracy panel  — now shows true DES one-step-ahead APE breakdown
// ─────────────────────────────────────────────────────────────────────────────

class _MapePanel extends StatelessWidget {
  final _ForecastItem item;
  const _MapePanel({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.mapeColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.20), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: color, size: 13),
              const SizedBox(width: 5),
              Text(
                'Forecast Accuracy (MAPE)',
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${item.mapeLabel}  •  ${item.mapeGradeLabel}',
                  style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),

          if (item.mape != null) ...[
            const SizedBox(height: 8),

            // MAPE bar with threshold markers
            LayoutBuilder(builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Container(
                      height: 6,
                      color: _Glass.borderMid.withValues(alpha: 0.4),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: FractionallySizedBox(
                      widthFactor:
                      (item.mape! / 100).clamp(0.0, 1.0),
                      child: Container(
                        height: 6,
                        decoration: const BoxDecoration(
                          borderRadius:
                          BorderRadius.all(Radius.circular(3)),
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF10B981),
                              Color(0xFF65A30D),
                              Color(0xFFB45309),
                              Color(0xFFEF4444),
                            ],
                            stops: [0.0, 0.25, 0.50, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  for (final pct in [10.0, 25.0, 50.0])
                    Positioned(
                      left: totalWidth * (pct / 100) - 0.5,
                      child: Container(
                        width: 1,
                        height: 6,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              );
            }),

            const SizedBox(height: 4),
            const Row(
              children: [
                Text('0%',
                    style:
                    TextStyle(color: _Glass.textMuted, fontSize: 8)),
                Spacer(),
                Text('10',
                    style:
                    TextStyle(color: _Glass.textMuted, fontSize: 8)),
                SizedBox(width: 24),
                Text('25',
                    style:
                    TextStyle(color: _Glass.textMuted, fontSize: 8)),
                SizedBox(width: 24),
                Text('50',
                    style:
                    TextStyle(color: _Glass.textMuted, fontSize: 8)),
                Spacer(),
                Text('100%',
                    style:
                    TextStyle(color: _Glass.textMuted, fontSize: 8)),
              ],
            ),

            const SizedBox(height: 6),

            // DES one-step-ahead APE breakdown
            _DesApeBreakdown(item: item),

            const SizedBox(height: 4),
            Text(
              'MAPE = (1/n) Σ |X_t − F_t| / X_t × 100  '
                  'where F_t is the DES one-step-ahead forecast  (α = 0.5).',
              style: TextStyle(
                  color: color.withValues(alpha: 0.65),
                  fontSize: 9,
                  height: 1.4),
            ),
          ] else ...[
            const SizedBox(height: 5),
            const Text(
              'Need at least two 30-day periods with order data to compute MAPE.',
              style: TextStyle(
                  color: _Glass.textMuted,
                  fontSize: 10,
                  height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shows each DES one-step-ahead APE, sourced directly from [_DesResult].
class _DesApeBreakdown extends StatelessWidget {
  final _ForecastItem item;
  const _DesApeBreakdown({required this.item});

  Color _apeColor(double v) {
    if (v < 10) return _Glass.accentEmerald;
    if (v < 25) return const Color(0xFF65A30D);
    if (v < 50) return _Glass.accentAmber;
    return _Glass.accentRose;
  }

  @override
  Widget build(BuildContext context) {
    final des      = item.desResult;
    final sfx      = item.unit.isNotEmpty ? ' ${item.unit}/d' : '/d';

    // forecasts[i] and actuals[i] are paired; actuals[0]=r2, actuals[1]=r1
    // label index: step 0 = t2 (30–60d), step 1 = t3 (last 30d)
    final stepLabels = ['60–90d → 30–60d', '30–60d → last 30d'];

    if (des.forecasts.isEmpty) return const SizedBox.shrink();

    String f(double v) => v.toStringAsFixed(2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('DES one-step APE breakdown:',
            style: TextStyle(color: _Glass.textMuted, fontSize: 9)),
        const SizedBox(height: 3),
        for (int i = 0; i < des.forecasts.length; i++) ...[
          Builder(builder: (_) {
            final forecast = des.forecasts[i];
            final actual   = des.actuals[i];
            final ape      = actual > 0.001
                ? ((actual - forecast) / actual).abs() * 100
                : null;
            final label    = i < stepLabels.length
                ? stepLabels[i]
                : 'Step ${i + 1}';

            return Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label,
                        style: const TextStyle(
                            color: _Glass.textMuted, fontSize: 9)),
                  ),
                  Text('F: ${f(forecast)}$sfx',
                      style: const TextStyle(
                          color: _Glass.textMuted, fontSize: 9)),
                  const SizedBox(width: 5),
                  Text('A: ${f(actual)}$sfx',
                      style: const TextStyle(
                          color: _Glass.textSecondary, fontSize: 9)),
                  const SizedBox(width: 5),
                  if (ape != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: _apeColor(ape).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'APE ${ape.toStringAsFixed(1)}%',
                        style: TextStyle(
                            color: _apeColor(ape),
                            fontSize: 9,
                            fontWeight: FontWeight.w700),
                      ),
                    )
                  else
                    const Text('APE —',
                        style: TextStyle(
                            color: _Glass.textMuted, fontSize: 9)),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Period trend widget  — now shows DES forecast alongside actual
// ─────────────────────────────────────────────────────────────────────────────

class _PeriodTrend extends StatelessWidget {
  final _ForecastItem item;
  const _PeriodTrend({required this.item});

  String _fmtRate(double r) =>
      r < 0.001 ? '—' : r.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final r3 = item.dailyRateP3; // X_1 — oldest
    final r2 = item.dailyRateP2; // X_2
    final r1 = item.dailyRateP1; // X_3 — most recent

    // DES forecasts for t=2 and t=3 (one-step-ahead)
    final des       = item.desResult;
    final f2 = des.forecasts.isNotEmpty ? des.forecasts[0] : null; // forecast for X_2 period
    final f3 = des.forecasts.length > 1  ? des.forecasts[1] : null; // forecast for X_3 period
    // DES forecast one period beyond available data (next 30d)
    final fNext = (r3 > 0.001 || r2 > 0.001 || r1 > 0.001)
        ? des.forecastAhead(1).clamp(0.0, double.infinity)
        : null;

    String arrow(double prev, double curr) {
      if (prev < 0.001 || curr < 0.001) return '•';
      final diff = curr - prev;
      if (diff.abs() < prev * 0.05) return '→';
      return diff > 0 ? '↑' : '↓';
    }

    Color arrowColor(double prev, double curr) {
      if (prev < 0.001 || curr < 0.001) return _Glass.textMuted;
      final diff = curr - prev;
      if (diff.abs() < prev * 0.05) return _Glass.textSecondary;
      return diff > 0 ? _Glass.accentAmber : _Glass.accentEmerald;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _Glass.surfaceThin,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _Glass.borderMid, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Consumption trend  (avg daily rate per 30-day window)',
            style: TextStyle(color: _Glass.textMuted, fontSize: 9),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _TrendCell(
                label: '60–90 d ago',
                rate: _fmtRate(r3),
                unit: item.unit,
              ),
              Text(
                ' ${arrow(r3, r2)} ',
                style: TextStyle(
                  color: arrowColor(r3, r2),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              _TrendCell(
                label: '30–60 d ago',
                rate: _fmtRate(r2),
                unit: item.unit,
                desRate: f2 != null ? _fmtRate(f2) : null,
              ),
              Text(
                ' ${arrow(r2, r1)} ',
                style: TextStyle(
                  color: arrowColor(r2, r1),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              _TrendCell(
                label: 'Last 30 d',
                rate: _fmtRate(r1),
                unit: item.unit,
                highlight: true,
                desRate: f3 != null ? _fmtRate(f3) : null,
              ),
              Text(
                ' → ',
                style: TextStyle(
                  color: _navyBlue.withValues(alpha: 0.5),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              _TrendCell(
                label: 'Next 30 d (DES)',
                rate: fNext != null
                    ? _fmtRate(fNext / 30) // convert period total back to daily
                    : '—',
                unit: item.unit,
                isDes: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendCell extends StatelessWidget {
  final String label, rate, unit;
  final String? desRate; // DES one-step forecast for this cell's period
  final bool highlight;
  final bool isDes;      // true for the forward-looking DES cell

  const _TrendCell({
    required this.label,
    required this.rate,
    required this.unit,
    this.desRate,
    this.highlight = false,
    this.isDes = false,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: isDes
          ? BoxDecoration(
        color: _navyBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: _navyBlue.withValues(alpha: 0.25), width: 0.8),
      )
          : highlight
          ? BoxDecoration(
        color: _navyBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border:
        Border.all(color: _Glass.borderMid, width: 0.8),
      )
          : null,
      child: Column(
        children: [
          // Actual rate
          Text(
            rate,
            style: TextStyle(
              color: isDes
                  ? _navyBlue
                  : highlight
                  ? _Glass.textPrimary
                  : _Glass.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            '${unit.isNotEmpty ? '$unit/' : ''}day',
            style: const TextStyle(color: _Glass.textMuted, fontSize: 7),
          ),
          // DES forecast sub-label (shown on actual-period cells)
          if (desRate != null) ...[
            const SizedBox(height: 2),
            Text(
              'F: $desRate',
              style: TextStyle(
                color: _navyBlue.withValues(alpha: 0.6),
                fontSize: 7,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              color: isDes
                  ? _navyBlue.withValues(alpha: 0.7)
                  : highlight
                  ? _Glass.textSecondary
                  : _Glass.textMuted,
              fontSize: 7,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary tile
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryTile extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _SummaryTile({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? _navyBlue : _Glass.surfaceMid,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? Colors.white.withValues(alpha: 0.20)
                : _Glass.borderMid,
            width: 0.8,
          ),
          boxShadow: const [_Glass.rowShadow],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? color.withValues(alpha: 0.9) : color,
              size: 14,
            ),
            const SizedBox(width: 7),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count.toString(),
                  style: TextStyle(
                    color: isActive ? Colors.white : _Glass.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive
                        ? Colors.white.withValues(alpha: 0.7)
                        : _Glass.textSecondary,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat chip
// ─────────────────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: color.withValues(alpha: 0.20), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 9,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Legend dot
// ─────────────────────────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
              color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(
              color: _Glass.textMuted, fontSize: 9)),
    ],
  );
}