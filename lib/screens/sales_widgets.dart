// Shared widgets for Sales Record and Sales Report.
// Used by BOTH the employee and admin screens.
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';

// ── Sales Record Table ────────────────────────────────────────────────────────

class SalesRecordTable extends StatefulWidget {
  const SalesRecordTable({super.key});

  @override
  State<SalesRecordTable> createState() => _SalesRecordTableState();
}

class _SalesRecordTableState extends State<SalesRecordTable> {
  String _typeFilter = 'all'; // all | downpayment | balance | cash

  String _fmt(Timestamp? ts) {
    if (ts == null) return '—';
    final d = ts.toDate().toLocal();
    const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${mo[d.month-1]} ${d.day.toString().padLeft(2,'0')}, ${d.year}';
  }

  String _typeLabel(String? t) {
    switch (t) {
      case 'downpayment': return 'Downpayment';
      case 'balance':     return 'Balance';
      case 'cash':        return 'Cash';
      default:            return t ?? '—';
    }
  }

  Color _typeColor(String? t) {
    switch (t) {
      case 'downpayment': return Colors.blueAccent;
      case 'balance':     return AppTheme.gold;
      case 'cash':        return Colors.green;
      default:            return Colors.white54;
    }
  }

  String _methodLabel(String? m) {
    switch (m) {
      case 'gcash':   return 'GCash';
      case 'card':    return 'Card';
      case 'maya':    return 'Maya';
      case 'cash':    return 'Cash';
      case 'online':  return 'Online';
      default:        return m ?? '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('Sales_Records')
        .orderBy('sale_date', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white38));
        }
        if (snap.hasError) {
          return Center(
            child: Text('Error: ${snap.error}',
                style: const TextStyle(color: Colors.redAccent)),
          );
        }

        final allDocs = snap.data?.docs ?? [];
        final docs = _typeFilter == 'all'
            ? allDocs
            : allDocs.where((d) =>
        (d.data() as Map)['payment_type']?.toString() == _typeFilter).toList();

        // Summary row
        final totalCollected = allDocs.fold<double>(
            0, (s, d) => s + ((d.data() as Map)['sale_amount'] as num? ?? 0).toDouble());

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary banner
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  _SummaryChip(
                    label: 'Total Collected',
                    value: '₱${totalCollected.toStringAsFixed(2)}',
                    color: AppTheme.gold,
                  ),
                  const SizedBox(width: 10),
                  _SummaryChip(
                    label: 'Records',
                    value: '${allDocs.length}',
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Filter chips
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip('All', 'all', _typeFilter,
                            (v) => setState(() => _typeFilter = v)),
                    _FilterChip('Downpayment', 'downpayment', _typeFilter,
                            (v) => setState(() => _typeFilter = v)),
                    _FilterChip('Balance', 'balance', _typeFilter,
                            (v) => setState(() => _typeFilter = v)),
                    _FilterChip('Cash', 'cash', _typeFilter,
                            (v) => setState(() => _typeFilter = v)),
                  ],
                ),
              ),
            ),

            // Table header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  top:    BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 3, child: _H('Order')),
                  Expanded(flex: 3, child: _H('Customer')),
                  Expanded(flex: 2, child: _H('Type')),
                  Expanded(flex: 2, child: _H('Method')),
                  Expanded(flex: 2, child: _H('Amount')),
                  Expanded(flex: 3, child: _H('Date')),
                ],
              ),
            ),

            // Rows
            Expanded(
              child: docs.isEmpty
                  ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 40, color: Colors.white24),
                    SizedBox(height: 12),
                    Text('No sales records yet',
                        style: TextStyle(color: Colors.white38, fontSize: 13)),
                  ],
                ),
              )
                  : ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: docs.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                itemBuilder: (_, i) {
                  final d       = docs[i].data() as Map<String, dynamic>;
                  final type    = d['payment_type']?.toString();
                  final method  = d['payment_method']?.toString();
                  final amount  = (d['sale_amount'] as num?)?.toDouble() ?? 0;
                  final orderId = d['order_id']?.toString() ?? '—';
                  final custName = d['customer_name']?.toString() ?? '—';
                  final date    = _fmt(d['sale_date'] as Timestamp?);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text(
                          orderId.length > 10 ? orderId.substring(0, 10) : orderId,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                        )),
                        Expanded(flex: 3, child: Text(
                          custName.length > 12 ? '${custName.substring(0, 10)}…' : custName,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        )),
                        Expanded(flex: 2, child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _typeColor(type).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_typeLabel(type),
                              style: TextStyle(color: _typeColor(type), fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        )),
                        Expanded(flex: 2, child: Text(_methodLabel(method),
                            style: const TextStyle(color: Colors.white54, fontSize: 11))),
                        Expanded(flex: 2, child: Text('₱${amount.toStringAsFixed(2)}',
                            style: const TextStyle(color: AppTheme.gold, fontSize: 13,
                                fontWeight: FontWeight.w600))),
                        Expanded(flex: 3, child: Text(date,
                            style: const TextStyle(color: Colors.white54, fontSize: 11))),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SummaryChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10)),
        Text(value,  style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

class _FilterChip extends StatelessWidget {
  final String label, value, active;
  final ValueChanged<String> onTap;
  const _FilterChip(this.label, this.value, this.active, this.onTap);

  @override
  Widget build(BuildContext context) {
    final sel = value == active;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: sel ? AppTheme.gold.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: sel ? AppTheme.gold.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(label,
            style: TextStyle(
                color: sel ? AppTheme.gold : Colors.white54,
                fontSize: 11,
                fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }
}

class _H extends StatelessWidget {
  final String text;
  const _H(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12));
}

// ── Sales Report ──────────────────────────────────────────────────────────────

class SalesReportView extends StatefulWidget {
  const SalesReportView({super.key});

  @override
  State<SalesReportView> createState() => _SalesReportViewState();
}

class _SalesReportViewState extends State<SalesReportView> {
  // 0 = Today, 1 = This Week, 2 = Monthly (default — original behaviour)
  int _period = 2;

  static const _periodLabels = ['Today', 'This Week', 'Monthly'];

  static String _shortMonth(int m) {
    const names = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return names[m - 1];
  }

  /// Returns true if [dt] falls within the selected period.
  bool _inPeriod(DateTime dt) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_period) {
      case 0: // Today
        return dt.isAfter(today) || dt.isAtSameMomentAs(today);
      case 1: // This week (Mon–Sun)
        final weekStart = today.subtract(Duration(days: today.weekday - 1));
        return dt.isAfter(weekStart.subtract(const Duration(seconds: 1)));
      case 2: // Monthly — no filter, use all docs
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Sales_Records')
          .orderBy('sale_date', descending: false)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white38));
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}',
              style: const TextStyle(color: Colors.redAccent)));
        }

        final allDocs = snap.data?.docs ?? [];

        // Filter docs by selected period
        final docs = allDocs.where((doc) {
          final d  = doc.data() as Map<String, dynamic>;
          final ts = d['sale_date'] as Timestamp?;
          if (ts == null) return _period == 2; // monthly keeps null-date records
          return _inPeriod(ts.toDate().toLocal());
        }).toList();

        double totalRevenue    = 0;
        double downpaymentTotal = 0;
        double balanceTotal     = 0;
        final  orderIds         = <String>{};

        final now = DateTime.now();
        final monthBuckets = List.generate(6, (i) {
          final m = DateTime(now.year, now.month - (5 - i));
          return _MonthBucket(month: m, label: _shortMonth(m.month), total: 0);
        });

        for (final doc in docs) {
          final d      = doc.data() as Map<String, dynamic>;
          final amount = (d['sale_amount'] as num?)?.toDouble() ?? 0;
          final type   = d['payment_type']?.toString() ?? '';
          final ordId  = d['order_id']?.toString() ?? '';

          totalRevenue += amount;
          if (type == 'downpayment') downpaymentTotal += amount;
          if (type == 'balance' || type == 'cash') balanceTotal += amount;
          if (ordId.isNotEmpty) orderIds.add(ordId);

          final ts = d['sale_date'] as Timestamp?;
          if (ts != null) {
            final dt = ts.toDate();
            for (final b in monthBuckets) {
              if (b.month.year == dt.year && b.month.month == dt.month) {
                b.total += amount;
                break;
              }
            }
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sales Report',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),

              // ── Period filter chips ───────────────────────────────────────
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: List.generate(_periodLabels.length, (i) {
                    final isActive = i == _period;
                    return GestureDetector(
                      onTap: () => setState(() => _period = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: EdgeInsets.only(right: i < _periodLabels.length - 1 ? 8 : 0),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppTheme.gold
                              : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          _periodLabels[i],
                          style: TextStyle(
                            color: isActive ? Colors.black : Colors.white70,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),

              // Stats grid — unchanged
              LayoutBuilder(builder: (_, constraints) {
                final narrow = constraints.maxWidth < 400;
                return Wrap(
                  spacing: 10, runSpacing: 10,
                  children: [
                    _ReportCard('Total Revenue', '₱${totalRevenue.toStringAsFixed(2)}', AppTheme.gold, narrow),
                    _ReportCard('Orders', '${orderIds.length}', Colors.blueAccent, narrow),
                    _ReportCard('Downpayments', '₱${downpaymentTotal.toStringAsFixed(2)}', Colors.blue, narrow),
                    _ReportCard('Balance Collected', '₱${balanceTotal.toStringAsFixed(2)}', Colors.green, narrow),
                  ],
                );
              }),
              const SizedBox(height: 24),

              // Chart — unchanged
              const Row(
                children: [
                  Icon(Icons.bar_chart_rounded, color: Colors.blueAccent, size: 14),
                  SizedBox(width: 6),
                  Text('MONTHLY REVENUE',
                      style: TextStyle(color: Colors.white54, fontSize: 11,
                          fontWeight: FontWeight.w600, letterSpacing: 1)),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 160,
                child: CustomPaint(
                  painter: _ChartPainter(buckets: monthBuckets),
                  child: Container(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: monthBuckets
                    .map((b) => Column(
                  children: [
                    Text(b.label,
                        style: const TextStyle(color: Colors.white38, fontSize: 10)),
                    if (b.total > 0)
                      Text('₱${b.total.toStringAsFixed(0)}',
                          style: const TextStyle(color: AppTheme.gold, fontSize: 9)),
                  ],
                ))
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool narrow;
  const _ReportCard(this.label, this.value, this.color, this.narrow);

  @override
  Widget build(BuildContext context) => Container(
    width: narrow ? double.infinity : 160,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

class _MonthBucket {
  final DateTime month;
  final String label;
  double total;
  _MonthBucket({required this.month, required this.label, required this.total});
}

class _ChartPainter extends CustomPainter {
  final List<_MonthBucket> buckets;
  _ChartPainter({required this.buckets});

  @override
  void paint(Canvas canvas, Size size) {
    if (buckets.isEmpty) return;
    final maxVal = buckets.map((b) => b.total).reduce((a, b) => a > b ? a : b);
    final effectiveMax = maxVal == 0 ? 1.0 : maxVal;
    final n     = buckets.length;
    final stepX = size.width / (n - 1).clamp(1, n);

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final points = List.generate(n, (i) => Offset(
      i * stepX,
      size.height - (buckets[i].total / effectiveMax) * size.height * 0.85,
    ));

    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final p in points) { fillPath.lineTo(p.dx, p.dy); }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Colors.blueAccent.withValues(alpha: 0.3), Colors.blueAccent.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      linePath.cubicTo((prev.dx + curr.dx) / 2, prev.dy,
          (prev.dx + curr.dx) / 2, curr.dy, curr.dx, curr.dy);
    }
    canvas.drawPath(linePath, Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke);

    final dotBg   = Paint()..color = const Color(0xFF1a1a2e);
    final dotFill = Paint()..color = Colors.blueAccent;
    for (final p in points) {
      canvas.drawCircle(p, 5, dotBg);
      canvas.drawCircle(p, 4, dotFill);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.buckets != buckets;
}
