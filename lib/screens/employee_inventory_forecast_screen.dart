import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';

/// Inventory Forecast Screen
///
/// Data sources:
///   • RawMaterials  — current stock, restock_level, unit_description
///   • InventoryLogs — quantity_added per material over time (replenishment history)
///   • Orders        — completed orders → products → bill_of_materials → qty consumed
///   • Products      — bill_of_materials: [{material_id, quantity_per_unit}]
///
/// Algorithm (linear consumption rate + MAPE accuracy):
///   1. Split last 90 days into three 30-day periods.
///   2. Compute daily consumption rate per period from completed Orders + BOM.
///   3. For each of the two most-recent periods, treat the previous period's rate
///      as the "forecast" and the actual period rate as the "actual", then compute
///      absolute percentage errors.  Average them → MAPE for this material.
///   4. Overall daily rate = consumed over full 90-day window / 90.
///   5. Days until stockout  = current_stock / daily_rate  (∞ if rate ≈ 0).
///   6. Days until restock   = (current_stock - restock_level) / daily_rate.
///   7. Recommended order qty = (daily_rate × 30) − current_stock  (30-day buffer).
///
/// MAPE thresholds:
///   • Excellent  : MAPE < 10 %
///   • Good       : MAPE 10–25 %
///   • Fair       : MAPE 25–50 %
///   • Poor       : MAPE ≥ 50 %  (or unavailable)

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
  String _filter = 'All';      // All | Critical | At Risk | Healthy
  String _sort   = 'Days Left'; // Days Left | Name | Consumption | MAPE

  static const _windowDays = 90;
  static const _periodDays = 30; // each of the 3 sub-periods

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

      // Period boundaries (newest → oldest)
      // p1: [now-30d, now)      — most recent period
      // p2: [now-60d, now-30d)  — middle period
      // p3: [now-90d, now-60d)  — oldest period
      final nowTs    = Timestamp.fromDate(now);
      final p1Start  = Timestamp.fromDate(now.subtract(const Duration(days: 30)));
      final p2Start  = Timestamp.fromDate(now.subtract(const Duration(days: 60)));
      final p3Start  = Timestamp.fromDate(now.subtract(const Duration(days: 90)));

      // 1. Fetch all raw materials
      final matSnap  = await db.collection('RawMaterials').get();
      final materials = {
        for (final d in matSnap.docs) d.id: d.data(),
      };

      // 2. Fetch all products (for BOM lookup)
      final prodSnap = await db.collection('Products').get();
      final bomByProductId   = <String, List<Map<String, dynamic>>>{};
      final bomByProductName = <String, List<Map<String, dynamic>>>{};
      for (final d in prodSnap.docs) {
        final bom = (d.data()['bill_of_materials'] as List?)
            ?.cast<Map<String, dynamic>>() ??
            [];
        bomByProductId[d.id] = bom;
        final name = d.data()['product_name']?.toString() ?? '';
        if (name.isNotEmpty) bomByProductName[name] = bom;
      }

      // Helper: accumulate consumed-per-material for orders within [from, to).
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
              ?.cast<Map<String, dynamic>>() ??
              [];
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

      // 3. Fetch completed orders once; filter client-side per period.
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

      // 4. Replenishment history (full 90-day window, used as fallback rate).
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

      // 5. Build forecast items with MAPE
      final items = <_ForecastItem>[];
      for (final entry in materials.entries) {
        final matId   = entry.key;
        final data    = entry.value;
        final name    = data['material_name']?.toString() ?? matId;
        final unit    = data['unit_description']?.toString() ?? '';
        final stock   = (data['current_stock'] as num?)?.toDouble() ?? 0;
        final restock = (data['restock_level'] as num?)?.toDouble() ?? 0;

        final c1 = consumedP1[matId] ?? 0.0; // newest 30 days
        final c2 = consumedP2[matId] ?? 0.0; // middle  30 days
        final c3 = consumedP3[matId] ?? 0.0; // oldest  30 days

        // Daily rates per period
        final r1 = c1 / _periodDays;
        final r2 = c2 / _periodDays;
        final r3 = c3 / _periodDays;

        // Overall 90-day rate (for stockout projection)
        final totalConsumed = c1 + c2 + c3;
        final replenished   = replenishedPerMaterial[matId] ?? 0;
        final dailyRate = totalConsumed > 0
            ? totalConsumed / _windowDays
            : (replenished > 0 ? replenished / _windowDays : 0.0);

        // ── MAPE Calculation ─────────────────────────────────────────────
        // We have three periods of actual consumption rates: r3 (oldest), r2, r1.
        // Treat each older period as the "naive forecast" for the next:
        //   • Forecast for period 2 = r3;  actual = r2
        //   • Forecast for period 1 = r2;  actual = r1
        // APE = |actual − forecast| / actual × 100  (skip when actual ≈ 0)
        double? mape;
        {
          final errors = <double>[];
          if (r2 > 0.001 && r3 > 0) {
            errors.add(((r2 - r3) / r2).abs() * 100);
          }
          if (r1 > 0.001 && r2 > 0) {
            errors.add(((r1 - r2) / r1).abs() * 100);
          }
          if (errors.isNotEmpty) {
            mape = errors.reduce((a, b) => a + b) / errors.length;
          }
        }

        // Stockout / restock projections
        final daysUntilStockout = dailyRate > 0.001
            ? (stock / dailyRate)
            : double.infinity;
        final daysUntilRestock  = (dailyRate > 0.001 && stock > restock)
            ? ((stock - restock) / dailyRate)
            : (stock <= restock ? 0.0 : double.infinity);

        final recommended30 = dailyRate > 0
            ? math.max(0.0, (dailyRate * 30) - stock)
            : 0.0;

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
          mape:              mape,
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
        // Null MAPE goes last; otherwise highest error first.
          final ma = a.mape ?? double.infinity;
          final mb = b.mape ?? double.infinity;
          return mb.compareTo(ma);
        default: // Days Left
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
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.gold),
            SizedBox(height: 16),
            Text('Analysing inventory…',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
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
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                  onPressed: _load,
                  style: AppTheme.primaryButton(),
                  child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 52, color: Colors.white24),
            SizedBox(height: 14),
            Text('No materials found',
                style: TextStyle(color: Colors.white54, fontSize: 14)),
          ],
        ),
      );
    }

    final filtered = _filtered;
    final critical  = _countByUrgency(_Urgency.critical);
    final atRisk    = _countByUrgency(_Urgency.atRisk);
    final healthy   = _countByUrgency(_Urgency.healthy);

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.gold,
      backgroundColor: const Color(0xFF1a1a2e),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── Header ────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Inventory Forecast',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _load,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: const Icon(Icons.refresh_rounded,
                              color: Colors.white70, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Summary cards ──────────────────────────────────────
                  SizedBox(
                    height: 76,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _SummaryTile(
                          label: 'Critical',
                          count: critical,
                          color: const Color(0xFFF44336),
                          icon: Icons.warning_amber_rounded,
                          isActive: _filter == 'Critical',
                          onTap: () => setState(() => _filter =
                          _filter == 'Critical' ? 'All' : 'Critical'),
                        ),
                        _SummaryTile(
                          label: 'At Risk',
                          count: atRisk,
                          color: Colors.orange,
                          icon: Icons.access_time_rounded,
                          isActive: _filter == 'At Risk',
                          onTap: () => setState(() => _filter =
                          _filter == 'At Risk' ? 'All' : 'At Risk'),
                        ),
                        _SummaryTile(
                          label: 'Healthy',
                          count: healthy,
                          color: const Color(0xFF4CAF50),
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
                          color: Colors.white38,
                          icon: Icons.help_outline_rounded,
                          isActive: false,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Sort row ───────────────────────────────────────────
                  Row(
                    children: [
                      const Text('Sort: ',
                          style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ...['Days Left', 'Name', 'Consumption', 'MAPE']
                          .map((s) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () => setState(() => _sort = s),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _sort == s
                                  ? AppTheme.gold.withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _sort == s
                                    ? AppTheme.gold.withValues(alpha: 0.5)
                                    : Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Text(s,
                                style: TextStyle(
                                    color: _sort == s
                                        ? AppTheme.gold
                                        : Colors.white54,
                                    fontSize: 11,
                                    fontWeight: _sort == s
                                        ? FontWeight.bold
                                        : FontWeight.normal)),
                          ),
                        ),
                      )),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // ── Legends ───────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: _ForecastLegend(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: _MapeLegend(),
            ),
          ),

          // ── List ──────────────────────────────────────────────────────────
          filtered.isEmpty
              ? SliverFillRemaining(
            child: Center(
              child: Text(
                'No materials in "$_filter" category',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 13),
              ),
            ),
          )
              : SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (_, i) => _ForecastCard(item: filtered[i]),
                childCount: filtered.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

enum _Urgency { critical, atRisk, healthy, noData }

/// MAPE accuracy bands for forecast reliability.
enum _MapeGrade { excellent, good, fair, poor, unavailable }

class _ForecastItem {
  final String materialId, name, unit;
  final double currentStock, restockLevel;
  final double dailyRate;
  final double dailyRateP1; // newest 30-day period avg daily rate
  final double dailyRateP2; // middle 30-day period avg daily rate
  final double dailyRateP3; // oldest 30-day period avg daily rate
  final double daysUntilStockout;
  final double daysUntilRestock;
  final double consumed90d;
  final double replenished90d;
  final double recommended30;

  /// Mean Absolute Percentage Error (%) derived from naive period-over-period
  /// forecasting across the three 30-day windows.  Null = insufficient data.
  final double? mape;

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
    required this.mape,
  });

  // ── Urgency ────────────────────────────────────────────────────────────────

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
      case _Urgency.critical: return const Color(0xFFF44336);
      case _Urgency.atRisk:   return Colors.orange;
      case _Urgency.healthy:  return const Color(0xFF4CAF50);
      case _Urgency.noData:   return Colors.white38;
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

  String get daysLabel {
    if (daysUntilStockout.isInfinite) return '∞';
    return daysUntilStockout.toStringAsFixed(0);
  }

  // ── MAPE helpers ───────────────────────────────────────────────────────────

  _MapeGrade get mapeGrade {
    if (mape == null) return _MapeGrade.unavailable;
    if (mape! < 10)   return _MapeGrade.excellent;
    if (mape! < 25)   return _MapeGrade.good;
    if (mape! < 50)   return _MapeGrade.fair;
    return _MapeGrade.poor;
  }

  String get mapeLabel {
    if (mape == null) return 'N/A';
    return '${mape!.toStringAsFixed(1)}%';
  }

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
      case _MapeGrade.excellent:   return const Color(0xFF4CAF50);
      case _MapeGrade.good:        return const Color(0xFF8BC34A);
      case _MapeGrade.fair:        return Colors.orange;
      case _MapeGrade.poor:        return const Color(0xFFF44336);
      case _MapeGrade.unavailable: return Colors.white38;
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _expanded
                ? color.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.1),
            width: _expanded ? 1.3 : 1,
          ),
        ),
        child: Column(
          children: [
            // ── Collapsed row ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  // Days circle
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.15),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            it.daysLabel,
                            style: TextStyle(
                                color: color,
                                fontSize: it.daysLabel.length > 3 ? 10 : 14,
                                fontWeight: FontWeight.bold),
                          ),
                          Text('days',
                              style: TextStyle(
                                  color: color.withValues(alpha: 0.7),
                                  fontSize: 8)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Name + bar + MAPE badge
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(it.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            // Urgency badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: color.withValues(alpha: 0.4)),
                              ),
                              child: Text(it.urgencyLabel,
                                  style: TextStyle(
                                      color: color,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Stock progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: stockPct,
                            minHeight: 5,
                            backgroundColor:
                            Colors.white.withValues(alpha: 0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
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
                                  color: Colors.white54, fontSize: 10),
                            ),
                            const Spacer(),
                            // MAPE inline badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: it.mapeColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: it.mapeColor
                                        .withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.analytics_outlined,
                                      color: it.mapeColor, size: 9),
                                  const SizedBox(width: 3),
                                  Text(
                                    'MAPE ${it.mapeLabel}',
                                    style: TextStyle(
                                        color: it.mapeColor,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600),
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
                    padding: const EdgeInsets.only(left: 8),
                    child: AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(Icons.keyboard_arrow_down,
                          color: Colors.white38, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            // ── Expanded detail ────────────────────────────────────────
            if (_expanded)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(
                        color: Colors.white.withValues(alpha: 0.08),
                        height: 1),
                    const SizedBox(height: 12),

                    // MAPE accuracy panel
                    _MapePanel(item: it),
                    const SizedBox(height: 10),

                    // Period trend sparkline
                    _PeriodTrend(item: it),
                    const SizedBox(height: 10),

                    // Stat chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
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
                          color: Colors.orange,
                        ),
                        _StatChip(
                          label: '90-Day Consumption',
                          value: it.consumed90d > 0
                              ? _fmtNum(it.consumed90d)
                              : 'No order data',
                          color: Colors.blueAccent,
                        ),
                        _StatChip(
                          label: '90-Day Replenishments',
                          value: it.replenished90d > 0
                              ? _fmtNum(it.replenished90d)
                              : 'None logged',
                          color: Colors.tealAccent,
                        ),
                        _StatChip(
                          label: 'Restock Level',
                          value: _fmtNum(it.restockLevel),
                          color: Colors.white54,
                        ),
                      ],
                    ),

                    // Recommendation box
                    if (it.dailyRate > 0.001) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: color.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lightbulb_outline_rounded,
                                color: color, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _buildRecommendation(it),
                                style: TextStyle(
                                    color: color,
                                    fontSize: 12,
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (it.dailyRate < 0.001) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.white38, size: 14),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No consumption data in the last 90 days. '
                                    'Forecast will update once orders using this material are completed.',
                                style: TextStyle(
                                    color: Colors.white38,
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
        ? ' (forecast accuracy: ${it.mapeLabel} MAPE — ${it.mapeGradeLabel})'
        : '';

    if (it.urgency == _Urgency.critical) {
      return 'Urgent: $daysStr$mapeNote. '
          'Order at least ${_fmtNum(orderQty)} ${it.unit} immediately '
          'to cover 30 days at current usage rate.';
    }
    if (it.urgency == _Urgency.atRisk) {
      return 'Reorder soon — $daysStr$mapeNote. '
          'Recommended order quantity for a 30-day buffer: '
          '${_fmtNum(orderQty)} ${it.unit}.';
    }
    return 'Stock is healthy ($daysStr)$mapeNote. '
        'Next 30-day top-up (if needed): ${_fmtNum(orderQty)} ${it.unit}.';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAPE accuracy panel
// ─────────────────────────────────────────────────────────────────────────────

class _MapePanel extends StatelessWidget {
  final _ForecastItem item;
  const _MapePanel({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.mapeColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: color, size: 14),
              const SizedBox(width: 6),
              Text(
                'Forecast Accuracy (MAPE)',
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${item.mapeLabel}  •  ${item.mapeGradeLabel}',
                  style: TextStyle(
                      color: color, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          if (item.mape != null) ...[
            const SizedBox(height: 10),

            // MAPE bar with threshold markers at 10 %, 25 %, 50 %
            LayoutBuilder(builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Track
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 8,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  // Fill
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: FractionallySizedBox(
                      widthFactor: (item.mape! / 100).clamp(0.0, 1.0),
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF4CAF50),
                              const Color(0xFF8BC34A),
                              Colors.orange,
                              const Color(0xFFF44336),
                            ],
                            stops: const [0.0, 0.25, 0.50, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Threshold tick marks
                  for (final pct in [10.0, 25.0, 50.0])
                    Positioned(
                      left: totalWidth * (pct / 100) - 0.5,
                      child: Container(
                          width: 1, height: 8,
                          color: Colors.white.withValues(alpha: 0.4)),
                    ),
                ],
              );
            }),

            const SizedBox(height: 4),

            // Scale labels
            Row(
              children: [
                const Text('0%',
                    style: TextStyle(color: Colors.white24, fontSize: 8)),
                const Spacer(),
                ...[
                  _ScaleTick(pct: 10, label: '10'),
                  _ScaleTick(pct: 25, label: '25'),
                  _ScaleTick(pct: 50, label: '50'),
                ],
                const Spacer(),
                const Text('100%',
                    style: TextStyle(color: Colors.white24, fontSize: 8)),
              ],
            ),

            const SizedBox(height: 8),

            // Period-by-period APE breakdown
            _ApeBreakdown(item: item),

            const SizedBox(height: 6),
            Text(
              'MAPE = average of |actual − forecast| / actual × 100 '
                  'across consecutive 30-day windows. Lower = more reliable forecast.',
              style: TextStyle(
                  color: color.withValues(alpha: 0.6),
                  fontSize: 10,
                  height: 1.4),
            ),
          ] else ...[
            const SizedBox(height: 6),
            const Text(
              'Insufficient multi-period data to calculate MAPE. '
                  'Accuracy will appear once at least two 30-day periods '
                  'have order consumption data.',
              style: TextStyle(color: Colors.white38, fontSize: 10, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small breakdown showing each period's APE contribution.
class _ApeBreakdown extends StatelessWidget {
  final _ForecastItem item;
  const _ApeBreakdown({required this.item});

  String _fmt(double v) => v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final r1 = item.dailyRateP1;
    final r2 = item.dailyRateP2;
    final r3 = item.dailyRateP3;

    // Recompute individual APEs for display
    final ape1 = (r2 > 0.001 && r3 > 0)
        ? ((r2 - r3) / r2).abs() * 100
        : null;
    final ape2 = (r1 > 0.001 && r2 > 0)
        ? ((r1 - r2) / r1).abs() * 100
        : null;

    if (ape1 == null && ape2 == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Period breakdown:',
            style: TextStyle(color: Colors.white38, fontSize: 9)),
        const SizedBox(height: 4),
        if (ape1 != null)
          _ApeRow(
            label: '60–90 d → 30–60 d',
            forecast: _fmt(r3),
            actual: _fmt(r2),
            ape: ape1,
            unit: item.unit,
          ),
        if (ape2 != null)
          _ApeRow(
            label: '30–60 d → last 30 d',
            forecast: _fmt(r2),
            actual: _fmt(r1),
            ape: ape2,
            unit: item.unit,
          ),
      ],
    );
  }
}

class _ApeRow extends StatelessWidget {
  final String label, forecast, actual, unit;
  final double ape;
  const _ApeRow({
    required this.label,
    required this.forecast,
    required this.actual,
    required this.ape,
    required this.unit,
  });

  Color get _apeColor {
    if (ape < 10) return const Color(0xFF4CAF50);
    if (ape < 25) return const Color(0xFF8BC34A);
    if (ape < 50) return Colors.orange;
    return const Color(0xFFF44336);
  }

  @override
  Widget build(BuildContext context) {
    final unitSuffix = unit.isNotEmpty ? ' $unit/d' : '/d';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(color: Colors.white38, fontSize: 9)),
          ),
          Text('F: $forecast$unitSuffix',
              style: const TextStyle(color: Colors.white38, fontSize: 9)),
          const SizedBox(width: 6),
          Text('A: $actual$unitSuffix',
              style: const TextStyle(color: Colors.white54, fontSize: 9)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: _apeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'APE ${ape.toStringAsFixed(1)}%',
              style: TextStyle(
                  color: _apeColor, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Period trend widget
// ─────────────────────────────────────────────────────────────────────────────

class _PeriodTrend extends StatelessWidget {
  final _ForecastItem item;
  const _PeriodTrend({required this.item});

  String _fmtRate(double r) =>
      r < 0.001 ? '—' : r.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final r3 = item.dailyRateP3;
    final r2 = item.dailyRateP2;
    final r1 = item.dailyRateP1;

    String arrow(double prev, double curr) {
      if (prev < 0.001 || curr < 0.001) return '•';
      final diff = curr - prev;
      if (diff.abs() < prev * 0.05) return '→';
      return diff > 0 ? '↑' : '↓';
    }

    Color arrowColor(double prev, double curr) {
      if (prev < 0.001 || curr < 0.001) return Colors.white24;
      final diff = curr - prev;
      if (diff.abs() < prev * 0.05) return Colors.white38;
      return diff > 0 ? Colors.orange : const Color(0xFF4CAF50);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Consumption trend  (avg daily rate per 30-day period)',
            style: TextStyle(color: Colors.white38, fontSize: 10),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _TrendCell(
                  label: '60–90 d ago',
                  rate: _fmtRate(r3),
                  unit: item.unit),
              Text(' ${arrow(r3, r2)} ',
                  style: TextStyle(
                      color: arrowColor(r3, r2),
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              _TrendCell(
                  label: '30–60 d ago',
                  rate: _fmtRate(r2),
                  unit: item.unit),
              Text(' ${arrow(r2, r1)} ',
                  style: TextStyle(
                      color: arrowColor(r2, r1),
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              _TrendCell(
                  label: 'Last 30 d',
                  rate: _fmtRate(r1),
                  unit: item.unit,
                  highlight: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendCell extends StatelessWidget {
  final String label, rate, unit;
  final bool highlight;
  const _TrendCell({
    required this.label,
    required this.rate,
    required this.unit,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: highlight
          ? BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
      )
          : null,
      child: Column(
        children: [
          Text(rate,
              style: TextStyle(
                  color: highlight ? Colors.white : Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(
            '${unit.isNotEmpty ? '$unit/' : ''}day',
            style: const TextStyle(color: Colors.white24, fontSize: 8),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: highlight ? Colors.white54 : Colors.white24,
                  fontSize: 8),
              textAlign: TextAlign.center),
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
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? color.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(count.toString(),
                    style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1)),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 10)),
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
  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: color.withValues(alpha: 0.7),
                  fontSize: 9,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stockout urgency legend
// ─────────────────────────────────────────────────────────────────────────────

class _ForecastLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.white38, size: 12),
          const SizedBox(width: 6),
          Expanded(
            child: Wrap(
              spacing: 12,
              children: [
                _LegendDot(
                    color: const Color(0xFFF44336),
                    label: 'Critical ≤ 7 days'),
                _LegendDot(
                    color: Colors.orange, label: 'At Risk ≤ 21 days'),
                _LegendDot(
                    color: const Color(0xFF4CAF50),
                    label: 'Healthy > 21 days'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAPE legend
// ─────────────────────────────────────────────────────────────────────────────

class _MapeLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.analytics_outlined,
              color: Colors.white38, size: 12),
          const SizedBox(width: 6),
          Expanded(
            child: Wrap(
              spacing: 12,
              children: [
                _LegendDot(
                    color: const Color(0xFF4CAF50),
                    label: 'Excellent < 10%'),
                _LegendDot(
                    color: const Color(0xFF8BC34A),
                    label: 'Good 10–25%'),
                _LegendDot(color: Colors.orange, label: 'Fair 25–50%'),
                _LegendDot(
                    color: const Color(0xFFF44336), label: 'Poor ≥ 50%'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
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
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(color: Colors.white54, fontSize: 10)),
    ],
  );
}

class _ScaleTick extends StatelessWidget {
  final double pct;
  final String label;
  const _ScaleTick({required this.pct, required this.label});

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(color: Colors.white24, fontSize: 8),
  );
}