import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'sales_widgets.dart';

class AdminLogsScreen extends StatefulWidget {
  const AdminLogsScreen({super.key});

  @override
  State<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends State<AdminLogsScreen> {
  static const _subTabs = [
    'Job Queue',
    'Sales Record',
    'Employee Activity',
    'Customer Feedback',
  ];

  int _activeIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Logs & History',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            SizedBox(height: 2),
            Text('Track activity, sales, and feedback',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 14),

        // Horizontal scrollable tab chips — same pattern as Products
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: List.generate(_subTabs.length, (i) {
              final isActive = i == _activeIndex;
              return GestureDetector(
                onTap: () => setState(() => _activeIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: EdgeInsets.only(
                      right: i < _subTabs.length - 1 ? 8 : 0),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 7),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppTheme.gold
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    _subTabs[i],
                    style: TextStyle(
                      color: isActive ? Colors.black : Colors.white70,
                      fontWeight: isActive
                          ? FontWeight.w700
                          : FontWeight.w400,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 16),

        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildContent() {
    switch (_activeIndex) {
      case 0:
        return const _JobQueueTab();
      case 1:
        return const _SalesRecordSubTab();
      case 2:
        return const _InventoryLogsTab();
      case 3:
        return const _CustomerFeedbackTab();
      default:
        return const _JobQueueTab();
    }
  }
}

class _InventoryLogsTab extends StatefulWidget {
  const _InventoryLogsTab();

  @override
  State<_InventoryLogsTab> createState() => _InventoryLogsTabState();
}

class _InventoryLogsTabState extends State<_InventoryLogsTab> {
  String _employeeFilter = '';
  String _materialFilter = '';
  final _empCtrl = TextEditingController();
  final _matCtrl = TextEditingController();

  static final _dateFmt = DateFormat('MMM dd, yyyy hh:mm a');

  @override
  void dispose() {
    _empCtrl.dispose();
    _matCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        title: const Text('Clear All Logs',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text(
          'This will permanently delete all inventory log entries. This cannot be undone.',
          style: TextStyle(color: Colors.white60, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30))),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      const batchSize = 400;
      while (true) {
        final snap = await FirebaseFirestore.instance
            .collection('InventoryLogs')
            .limit(batchSize)
            .get();
        if (snap.docs.isEmpty) break;
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        if (snap.docs.length < batchSize) break;
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('All logs cleared'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-section header
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Employee Activity',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  Text('Inventory updates by employees',
                      style:
                      TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => _confirmClearAll(context),
              icon: Icon(Icons.delete_sweep_outlined,
                  size: 16, color: Colors.red.shade400),
              label: Text('Clear All',
                  style: TextStyle(
                      fontSize: 12, color: Colors.red.shade400)),
              style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade400),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Filter row
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _empCtrl,
                style:
                const TextStyle(color: Colors.white, fontSize: 13),
                onChanged: (v) =>
                    setState(() => _employeeFilter = v.toLowerCase()),
                decoration: AppTheme.inputDecoration(
                    'Filter by employee',
                    icon: Icons.person_search_outlined),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _matCtrl,
                style:
                const TextStyle(color: Colors.white, fontSize: 13),
                onChanged: (v) =>
                    setState(() => _materialFilter = v.toLowerCase()),
                decoration: AppTheme.inputDecoration(
                    'Filter by material',
                    icon: Icons.inventory_2_outlined),
              ),
            ),
            if (_employeeFilter.isNotEmpty || _materialFilter.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear,
                    color: Colors.white38, size: 18),
                onPressed: () {
                  _empCtrl.clear();
                  _matCtrl.clear();
                  setState(() {
                    _employeeFilter = '';
                    _materialFilter = '';
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 10),

        // Table header
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Expanded(flex: 2, child: Text('Timestamp', style: _h)),
              Expanded(flex: 2, child: Text('Employee', style: _h)),
              Expanded(flex: 3, child: Text('Material', style: _h)),
              SizedBox(
                  width: 70,
                  child: Text('Added',
                      style: _h, textAlign: TextAlign.right)),
              SizedBox(
                  width: 70,
                  child: Text('New Stock',
                      style: _h, textAlign: TextAlign.right)),
              SizedBox(
                  width: 60,
                  child: Text('Method',
                      style: _h, textAlign: TextAlign.center)),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // Log list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('InventoryLogs')
                .orderBy('timestamp', descending: true)
                .limit(200)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child:
                    CircularProgressIndicator(color: Colors.white));
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_toggle_off,
                          size: 56, color: Colors.white24),
                      SizedBox(height: 16),
                      Text('No activity logs yet',
                          style: TextStyle(
                              color: Colors.white60, fontSize: 15)),
                      SizedBox(height: 8),
                      Text(
                          'Logs appear here when employees replenish stock',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                );
              }

              final filtered = docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final emp =
                    data['updated_by_name']?.toString().toLowerCase() ??
                        '';
                final mat =
                    data['material_name']?.toString().toLowerCase() ??
                        '';
                return (_employeeFilter.isEmpty ||
                    emp.contains(_employeeFilter)) &&
                    (_materialFilter.isEmpty ||
                        mat.contains(_materialFilter));
              }).toList();

              if (filtered.isEmpty) {
                return const Center(
                  child: Text(
                    'No logs matching your filter',
                    style: TextStyle(
                        color: Colors.white38, fontSize: 13),
                  ),
                );
              }

              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final data =
                  filtered[i].data() as Map<String, dynamic>;
                  return _LogRow(data: data, dateFmt: _dateFmt);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  static const _h = TextStyle(
      color: Colors.white60,
      fontSize: 11,
      fontWeight: FontWeight.bold);
}

// ── Job Queue Tab ─────────────────────────────────────────────────────────────

class _JobQueueTab extends StatelessWidget {
  const _JobQueueTab();

  static String _fmtDate(dynamic ts) {
    if (ts == null) return '—';
    try {
      final d = (ts as Timestamp).toDate().toLocal();
      const m = ['Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${m[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) {
      return '—';
    }
  }

  static Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':  return Colors.amber;
      case 'active':   return const Color(0xFF42A5F5);
      case 'completed': return const Color(0xFF4CAF50);
      case 'cancelled': return const Color(0xFFF44336);
      default:          return Colors.white60;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Order_Queue holds pending/active jobs; sort client-side by created_at (FCFS)
    final stream = FirebaseFirestore.instance
        .collection('Order_Queue')
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.gold));
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          );
        }

        final docs = [...(snapshot.data?.docs ?? [])]
          ..sort((a, b) {
            final ta = (a.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
            final tb = (b.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return ta.compareTo(tb);
          });

        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.queue_outlined, size: 56, color: Colors.white24),
                SizedBox(height: 16),
                Text('No jobs in queue',
                    style: TextStyle(color: Colors.white60, fontSize: 15)),
                SizedBox(height: 8),
                Text('Jobs appear here once an order is paid',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '${docs.length} job${docs.length == 1 ? '' : 's'} in queue',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final orderId      = data['order_id']?.toString() ?? '—';
                  final customer     = data['customer_name']?.toString() ?? '—';
                  final jobStatus    = data['job_status']?.toString() ?? 'pending';
                  final total        = (data['total_price'] as num?)?.toDouble() ?? 0;
                  final products     = (data['products'] as List?)
                      ?.cast<Map<String, dynamic>>() ?? [];
                  final dateStr      = _fmtDate(data['created_at']);
                  final statusColor  = _statusColor(jobStatus);
                  final productSummary = products.isEmpty
                      ? '—'
                      : products.map((p) => '${p['name'] ?? '?'} ×${p['qty'] ?? 1}').join(', ');

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Position badge
                            Container(
                              width: 30, height: 30,
                              decoration: BoxDecoration(
                                color: AppTheme.gold.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppTheme.gold.withValues(alpha: 0.4)),
                              ),
                              child: Center(
                                child: Text('#${i + 1}',
                                    style: const TextStyle(
                                        color: AppTheme.gold,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(orderId,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                  Text(customer,
                                      style: const TextStyle(
                                          color: Colors.white54, fontSize: 12)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: statusColor.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                jobStatus[0].toUpperCase() + jobStatus.substring(1),
                                style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        if (products.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(productSummary,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined,
                                size: 11, color: Colors.white38),
                            const SizedBox(width: 4),
                            Text(dateStr,
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 11)),

                            const Spacer(),
                            Text(
                              '₱${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: AppTheme.gold,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
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

// ── Sales Record Sub-Tab ──────────────────────────────────────────────────────

class _SalesRecordSubTab extends StatelessWidget {
  const _SalesRecordSubTab();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.glassCard(opacity: 0.13, radius: 18),
      child: const SalesRecordTable(),
    );
  }
}

// ── Customer Feedback Tab ─────────────────────────────────────────────────────

class _CustomerFeedbackTab extends StatelessWidget {
  const _CustomerFeedbackTab();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.glassCard(opacity: 0.13, radius: 18),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Feedback')
            .orderBy('createdAt', descending: true)
            .limit(200)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.white));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rate_review_outlined,
                      size: 56, color: Colors.white24),
                  SizedBox(height: 16),
                  Text('No customer feedback yet',
                      style:
                      TextStyle(color: Colors.white60, fontSize: 15)),
                  SizedBox(height: 8),
                  Text('Feedback submitted by customers will appear here',
                      style:
                      TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Text(
                  'Customer Feedback  (${docs.length})',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
              Divider(
                  color: Colors.white.withValues(alpha: 0.1),
                  height: 1,
                  thickness: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data =
                    docs[i].data() as Map<String, dynamic>;
                    final customer =
                        data['customerName']?.toString() ??
                            data['userName']?.toString() ??
                            '—';
                    final message =
                        data['message']?.toString() ??
                            data['feedback']?.toString() ??
                            '—';
                    final rating = (data['rating'] as num?)?.toInt();
                    final ts = data['createdAt'] as Timestamp?;
                    final timeStr = ts != null
                        ? DateFormat('MMM dd, yyyy hh:mm a')
                        .format(ts.toDate())
                        : '—';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person_outline,
                                  color: Colors.white54, size: 14),
                              const SizedBox(width: 6),
                              Text(customer,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              const Spacer(),
                              if (rating != null)
                                Row(
                                  children: List.generate(
                                    5,
                                        (s) => Icon(
                                      s < rating
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: AppTheme.gold,
                                      size: 13,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              Text(timeStr,
                                  style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(message,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13,
                                  height: 1.4)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final DateFormat dateFmt;

  const _LogRow({required this.data, required this.dateFmt});

  String _methodLabel(String method) {
    switch (method) {
      case 'qr_scan':
        return 'QR';
      case 'admin_edit':
        return 'Admin';
      case 'order_deduction':
        return 'Order';
      default:
        return 'Manual';
    }
  }

  Color _methodColor(String method) {
    switch (method) {
      case 'qr_scan':
        return AppTheme.accent;
      case 'admin_edit':
        return AppTheme.gold;
      case 'order_deduction':
        return const Color(0xFFAB47BC);
      default:
        return Colors.white60;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = data['timestamp'] as Timestamp?;
    final timeStr = ts != null ? dateFmt.format(ts.toDate()) : '—';
    final employee = data['updated_by_name']?.toString() ?? '—';
    final materialName = data['material_name']?.toString() ?? '—';
    final materialId = data['material_id']?.toString() ?? '';
    final qtyAdded = (data['quantity_added'] as num?) ?? 0;
    final newStock = (data['new_stock'] as num?) ?? 0;
    final method = data['update_method']?.toString() ?? 'manual';
    final productName = data['product_name']?.toString() ?? '';
    final orderId = data['order_id']?.toString() ?? '';
    final isOrderDeduction = method == 'order_deduction';

    String fmt(num v) =>
        v == v.toInt() ? v.toInt().toString() : v.toStringAsFixed(2);

    final isPositive = qtyAdded > 0;
    final isNegative = qtyAdded < 0;
    final qtyDisplay =
    isPositive ? '+${fmt(qtyAdded)}' : fmt(qtyAdded);
    final qtyColor = isPositive
        ? const Color(0xFF4CAF50)
        : isNegative
        ? const Color(0xFFF44336)
        : Colors.white60;

    final methodColor = _methodColor(method);

    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding:
      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isOrderDeduction
            ? const Color(0xFFAB47BC).withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: isOrderDeduction
              ? const Color(0xFFAB47BC).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(timeStr,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 11)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              isOrderDeduction ? 'Auto (Order)' : employee,
              style: TextStyle(
                  color: isOrderDeduction
                      ? const Color(0xFFAB47BC)
                      : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(materialName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(materialId,
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontFamily: 'monospace')),
                if (isOrderDeduction && productName.isNotEmpty)
                  Text(
                    'Product: $productName${orderId.isNotEmpty ? ' · #${orderId.substring(0, orderId.length.clamp(0, 6))}' : ''}',
                    style: const TextStyle(
                        color: Color(0xFFCE93D8), fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(qtyDisplay,
                style: TextStyle(
                    color: qtyColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.right),
          ),
          SizedBox(
            width: 70,
            child: Text(fmt(newStock),
                style: const TextStyle(
                    color: Colors.white, fontSize: 12),
                textAlign: TextAlign.right),
          ),
          SizedBox(
            width: 60,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: methodColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: methodColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  _methodLabel(method),
                  style: TextStyle(
                      color: methodColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}