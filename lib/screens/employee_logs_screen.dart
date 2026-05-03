import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'sales_widgets.dart';

class EmployeeLogsScreen extends StatefulWidget {
  const EmployeeLogsScreen({super.key});

  @override
  State<EmployeeLogsScreen> createState() => _EmployeeLogsScreenState();
}

class _EmployeeLogsScreenState extends State<EmployeeLogsScreen> {
  int _topTab = 0; // 0 = Job Queue, 1 = Sales Record

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PillTabBar(
            tabs: const ['Job Queue', 'Sales Record'],
            active: _topTab,
            onTap: (i) => setState(() => _topTab = i),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _topTab == 0
                ? const _JobQueuePlaceholder()
                : const _SalesSection(),
          ),
        ],
      ),
    );
  }
}

class _SalesSection extends StatefulWidget {
  const _SalesSection();

  @override
  State<_SalesSection> createState() => _SalesSectionState();
}

class _SalesSectionState extends State<_SalesSection> {
  int _subTab = 0; // 0 = Sales Record, 1 = Sales Report

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.glassCard(opacity: 0.13, radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _UnderlineTabBar(
              tabs: const ['Sales Record', 'Sales Report'],
              active: _subTab,
              onTap: (i) => setState(() => _subTab = i),
            ),
          ),
          Divider(
              color: Colors.white.withValues(alpha: 0.1),
              height: 1,
              thickness: 1),
          Expanded(
            child: _subTab == 0
                ? const SalesRecordTable()  // ← from sales_widgets.dart
                : const SalesReportView(),  // ← from sales_widgets.dart
          ),
        ],
      ),
    );
  }
}

class _PillTabBar extends StatelessWidget {
  final List<String> tabs;
  final int active;
  final ValueChanged<int> onTap;
  const _PillTabBar(
      {required this.tabs, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(tabs.length, (i) {
        final isActive = i == active;
        return Padding(
          padding: EdgeInsets.only(right: i < tabs.length - 1 ? 8 : 0),
          child: GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.gold
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                tabs[i],
                style: TextStyle(
                  color: isActive ? Colors.black : Colors.white70,
                  fontWeight:
                  isActive ? FontWeight.w700 : FontWeight.w400,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _UnderlineTabBar extends StatelessWidget {
  final List<String> tabs;
  final int active;
  final ValueChanged<int> onTap;
  const _UnderlineTabBar(
      {required this.tabs, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(tabs.length, (i) {
        final isActive = i == active;
        return GestureDetector(
          onTap: () => onTap(i),
          child: Container(
            margin: EdgeInsets.only(right: i < tabs.length - 1 ? 24 : 0),
            padding: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isActive ? AppTheme.gold : Colors.transparent,
                  width: 2.5,
                ),
              ),
            ),
            child: Text(
              tabs[i],
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white54,
                fontWeight:
                isActive ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _JobQueuePlaceholder extends StatefulWidget {
  const _JobQueuePlaceholder();

  @override
  State<_JobQueuePlaceholder> createState() => _JobQueuePlaceholderState();
}

class _JobQueuePlaceholderState extends State<_JobQueuePlaceholder> {
  String? _statusFilter;

  static const _statuses = [
    'pending',
    'in_production',
    'ready',
    'completed',
    'cancelled',
  ];

  static const _statusLabels = {
    'pending': 'Pending',
    'in_production': 'In Production',
    'ready': 'Ready',
    'completed': 'Completed',
    'cancelled': 'Cancelled',
  };

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':       return Colors.amber;
      case 'in_production': return Colors.blueAccent;
      case 'ready':         return Colors.green;
      case 'completed':     return AppTheme.accent;
      case 'cancelled':     return Colors.redAccent;
      default:              return Colors.white54;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'pending':       return Icons.hourglass_empty;
      case 'in_production': return Icons.precision_manufacturing_outlined;
      case 'ready':         return Icons.check_circle_outline;
      case 'completed':     return Icons.task_alt;
      case 'cancelled':     return Icons.cancel_outlined;
      default:              return Icons.receipt_long_outlined;
    }
  }

  /// Returns the allowed next statuses from the current one
  List<String> _nextStatuses(String current) {
    switch (current) {
      case 'pending':       return ['in_production', 'cancelled'];
      case 'in_production': return ['ready', 'cancelled'];
      case 'ready':         return ['completed', 'cancelled'];
      default:              return [];
    }
  }

  Future<void> _updateStatus(String docId, String newStatus) async {
    await FirebaseFirestore.instance
        .collection('Orders')
        .doc(docId)
        .update({'status': newStatus});
  }

  void _showStatusDialog(BuildContext context, String docId, String current) {
    final nexts = _nextStatuses(current);
    if (nexts.isEmpty) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        title: const Text('Update Order Status',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: nexts.map((s) {
            final color = _statusColor(s);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _updateStatus(docId, s);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Order marked as ${_statusLabels[s] ?? s}'),
                        backgroundColor: color,
                      ));
                    }
                  },
                  icon: Icon(_statusIcon(s), size: 16),
                  label: Text(_statusLabels[s] ?? s),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color.withValues(alpha: 0.18),
                    foregroundColor: color,
                    elevation: 0,
                    side: BorderSide(color: color.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance
        .collection('Orders')
        .orderBy('created_at', descending: true);

    if (_statusFilter != null) {
      query = query.where('status', isEqualTo: _statusFilter);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter chips
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _QueueChip(
                label: 'All',
                isActive: _statusFilter == null,
                color: Colors.white54,
                onTap: () => setState(() => _statusFilter = null),
              ),
              ..._statuses.map((s) => _QueueChip(
                label: _statusLabels[s] ?? s,
                isActive: _statusFilter == s,
                color: _statusColor(s),
                onTap: () => setState(() =>
                _statusFilter = _statusFilter == s ? null : s),
              )),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Orders list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.white));
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inbox_outlined,
                          size: 52, color: Colors.white24),
                      const SizedBox(height: 14),
                      Text(
                        _statusFilter == null
                            ? 'No orders yet'
                            : 'No ${_statusLabels[_statusFilter] ?? _statusFilter} orders',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 14),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final docId = docs[i].id;
                  final status = data['status']?.toString() ?? 'pending';
                  final color = _statusColor(status);
                  final canUpdate = _nextStatuses(status).isNotEmpty;

                  // Product names list
                  final products = data['products'] as List? ?? [];
                  final productNames = products
                      .map((p) => p['name']?.toString() ?? '')
                      .where((n) => n.isNotEmpty)
                      .join(', ');

                  // Timestamp
                  final ts = data['created_at'] as Timestamp?;
                  final dateStr = ts != null
                      ? '${ts.toDate().month}/${ts.toDate().day}/${ts.toDate().year}'
                      : '—';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        // Status icon
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(_statusIcon(status),
                              color: color, size: 18),
                        ),
                        const SizedBox(width: 10),

                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    data['order_id']?.toString() ?? docId,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color:
                                          color.withValues(alpha: 0.4)),
                                    ),
                                    child: Text(
                                      _statusLabels[status] ?? status,
                                      style: TextStyle(
                                          color: color,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                data['customer_name']?.toString() ?? '—',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 11),
                              ),
                              if (productNames.isNotEmpty)
                                Text(
                                  productNames,
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 10),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    '₱${(data['total_price'] as num?)?.toStringAsFixed(2) ?? '—'}',
                                    style: const TextStyle(
                                        color: AppTheme.gold,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  Text(dateStr,
                                      style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 10)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Update status button
                        if (canUpdate)
                          GestureDetector(
                            onTap: () =>
                                _showStatusDialog(context, docId, status),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.gold.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: AppTheme.gold
                                        .withValues(alpha: 0.35)),
                              ),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.swap_horiz_rounded,
                                      color: AppTheme.gold, size: 16),
                                  SizedBox(height: 2),
                                  Text('Update',
                                      style: TextStyle(
                                          color: AppTheme.gold,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 48),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _QueueChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  const _QueueChip({
    required this.label,
    required this.isActive,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isActive
                  ? color.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.15)),
        ),
        child: Text(label,
            style: TextStyle(
                color: isActive ? color : Colors.white60,
                fontSize: 11,
                fontWeight:
                isActive ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }
}