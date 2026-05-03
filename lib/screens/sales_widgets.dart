// Shared widgets for Sales Record and Sales Report.
// Used by BOTH the employee and admin screens.
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';

class SalesRecordTable extends StatelessWidget {
  const SalesRecordTable({super.key});

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '—';
    final d = ts.toDate().toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}, ${d.year}';
  }

  String _formatAmount(num? amount) {
    if (amount == null) return '—';
    return 'P${amount.toStringAsFixed(2)}';
  }

  String _truncate(String value) =>
      value.length > 8 ? '${value.substring(0, 8)}…' : value;

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('Sales_Records')
        .orderBy('sale_date', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white38),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'Error: ${snap.error}',
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }

        final docs = snap.data?.docs ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                ),
                child: const Row(
                  children: [
                    Expanded(flex: 2, child: _HeaderCell('Sales ID')),
                    Expanded(flex: 2, child: _HeaderCell('Order ID')),
                    Expanded(flex: 2, child: _HeaderCell('Payment ID')),
                    Expanded(flex: 2, child: _HeaderCell('Sale Date')),
                    Expanded(flex: 2, child: _HeaderCell('Sale Amount')),
                  ],
                ),
              ),

              if (docs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 40, color: Colors.white24),
                        SizedBox(height: 12),
                        Text(
                          'No sales records found.',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )

              else
                ...docs.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.07),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            _truncate(doc.id),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            _truncate(
                                (d['order_id'] ?? '—').toString()),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            _truncate(
                                (d['payment_id'] ?? '—').toString()),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            _formatDate(d['sale_date'] as Timestamp?),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            _formatAmount(d['sale_amount'] as num?),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    );
  }
}

class SalesReportView extends StatelessWidget {
  const SalesReportView({super.key});

  static String _shortMonth(int m) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return names[m - 1];
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Sales_Records')
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white38),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'Error: ${snap.error}',
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }

        final docs = snap.data?.docs ?? [];

        double totalSales = 0;
        final totalOrders = docs.length;

        final now = DateTime.now();
        final monthBuckets = List.generate(6, (i) {
          final m = DateTime(now.year, now.month - (5 - i));
          return _MonthBucket(
              month: m, label: _shortMonth(m.month), total: 0);
        });

        for (final doc in docs) {
          final d = doc.data() as Map<String, dynamic>;
          final amount =
              (d['sale_amount'] as num?)?.toDouble() ?? 0;
          totalSales += amount;

          final ts = d['sale_date'] as Timestamp?;
          if (ts != null) {
            final dt = ts.toDate();
            for (final b in monthBuckets) {
              if (b.month.year == dt.year &&
                  b.month.month == dt.month) {
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
              const Text(
                'Sales Report',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (ctx, constraints) {
                  final isWide = constraints.maxWidth >= 520;
                  final chart = _LineChart(buckets: monthBuckets);
                  final stats = _StatsColumn(
                    totalSales: totalSales,
                    totalOrders: totalOrders,
                  );
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: chart),
                        const SizedBox(width: 20),
                        stats,
                      ],
                    );
                  }
                  return Column(
                    children: [
                      chart,
                      const SizedBox(height: 20),
                      stats,
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MonthBucket {
  final DateTime month;
  final String label;
  double total;
  _MonthBucket(
      {required this.month, required this.label, required this.total});
}

class _LineChart extends StatelessWidget {
  final List<_MonthBucket> buckets;
  const _LineChart({required this.buckets});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Colors.blueAccent),
            ),
            const SizedBox(width: 6),
            const Text(
              'SALES',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: CustomPaint(
            painter: _ChartPainter(buckets: buckets),
            child: Container(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: buckets
              .map((b) => Text(b.label,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 10)))
              .toList(),
        ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<_MonthBucket> buckets;
  _ChartPainter({required this.buckets});

  @override
  void paint(Canvas canvas, Size size) {
    if (buckets.isEmpty) return;
    final maxVal =
        buckets.map((b) => b.total).reduce((a, b) => a > b ? a : b);
    final effectiveMax = maxVal == 0 ? 1.0 : maxVal;
    final n = buckets.length;
    final stepX = size.width / (n - 1).clamp(1, n);

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(
          Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Points
    final points = List.generate(n, (i) {
      final x = i * stepX;
      final y = size.height -
          (buckets[i].total / effectiveMax) * size.height * 0.85;
      return Offset(x, y);
    });

    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.blueAccent.withValues(alpha: 0.3),
            Colors.blueAccent.withValues(alpha: 0.0),
          ],
        ).createShader(
            Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Smooth line
    final linePaint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final linePath = Path()
      ..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final cp1 = Offset((prev.dx + curr.dx) / 2, prev.dy);
      final cp2 = Offset((prev.dx + curr.dx) / 2, curr.dy);
      linePath.cubicTo(
          cp1.dx, cp1.dy, cp2.dx, cp2.dy, curr.dx, curr.dy);
    }
    canvas.drawPath(linePath, linePaint);

    // Dots
    final dotBg = Paint()..color = const Color(0xFF1a1a2e);
    final dotFill = Paint()..color = Colors.blueAccent;
    for (final p in points) {
      canvas.drawCircle(p, 5, dotBg);
      canvas.drawCircle(p, 4, dotFill);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.buckets != buckets;
}

class _StatsColumn extends StatelessWidget {
  final double totalSales;
  final int totalOrders;

  const _StatsColumn({
    required this.totalSales,
    required this.totalOrders,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatCard(
          label: 'Total Sales',
          value: 'P${totalSales.toStringAsFixed(2)}',
        ),
        const SizedBox(height: 12),
        _StatCard(
          label: 'Total Orders',
          value: totalOrders.toString(),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              )),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              )),
        ],
      ),
    );
  }
}
