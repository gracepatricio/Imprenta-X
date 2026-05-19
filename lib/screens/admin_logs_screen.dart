import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'sales_widgets.dart';
import 'invoice_screen.dart';

// ── Liquid Glass Design Tokens ────────────────────────────────────────────────
class _Glass {
  static const Color surface = Color(0xEEFFFFFF);
  static const Color surfaceMid = Color(0xCCFFFFFF);
  static const Color surfaceThin = Color(0x99FFFFFF);

  static const Color borderMid = Color(0x55FFFFFF);
  static const Color borderDim = Color(0x28FFFFFF);

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textMuted = Color(0xFF9CA3AF);

  static const BoxShadow elevatedShadow = BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 20,
    spreadRadius: -2,
    offset: Offset(0, 6),
  );
  static const BoxShadow rowShadow = BoxShadow(
    color: Color(0x0D000000),
    blurRadius: 8,
    spreadRadius: 0,
    offset: Offset(0, 2),
  );

  static BoxDecoration card({
    Color? color,
    double radius = 14,
    bool elevated = false,
  }) => BoxDecoration(
    color: color ?? surfaceMid,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderMid, width: 0.8),
    boxShadow: [elevated ? elevatedShadow : rowShadow],
  );

  static InputDecoration field(
    String hint, {
    IconData? icon,
  }) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: textMuted, fontSize: 13),
    prefixIcon: icon != null ? Icon(icon, size: 16, color: textMuted) : null,
    filled: true,
    fillColor: const Color(0xFFF9FAFB),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppTheme.gold.withValues(alpha: 0.7)),
    ),
  );
}

// ── iOS-style design tokens ───────────────────────────────────────────────────
class _iOS {
  static const Color groupedBg = Color(0xFFF2F2F7);
  static const Color cellBg = Colors.white;
  static const Color separator = Color(0xFFE5E5EA);
  static const Color label = Color(0xFF000000);
  static const Color label2 = Color(0xFF3C3C43);
  static const Color label3 = Color(0xFF8E8E93);
  static const Color tint = Color(0xFF007AFF);

  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 12,
    spreadRadius: 0,
    offset: Offset(0, 2),
  );

  static BoxDecoration groupedCard({double radius = 12}) => BoxDecoration(
    color: cellBg,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: const [cardShadow],
  );
}

// ── Sub-menu tab enum ─────────────────────────────────────────────────────────
enum _LogsTab { jobQueue, salesRecord, employeeActivity, customerFeedback }

// =============================================================================
// Sub-menu tab bar
// =============================================================================
class _SubMenuTabBar extends StatelessWidget {
  final _LogsTab activeTab;
  final ValueChanged<_LogsTab> onTabChanged;

  const _SubMenuTabBar({required this.activeTab, required this.onTabChanged});

  static const _tabs = [
    (_LogsTab.jobQueue, 'Job Queue', Icons.queue_outlined),
    (_LogsTab.salesRecord, 'Sales Record', Icons.receipt_long_outlined),
    (
      _LogsTab.employeeActivity,
      'Employee Activity',
      Icons.people_outline_rounded,
    ),
    (
      _LogsTab.customerFeedback,
      'Customer Feedback',
      Icons.rate_review_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: const [_Glass.rowShadow],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _tabs.map((t) {
            final isActive = activeTab == t.$1;
            return GestureDetector(
              onTap: () => onTabChanged(t.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF1A1A2E)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      t.$3,
                      size: 14,
                      color: isActive ? Colors.white : _Glass.textSecondary,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      t.$2,
                      style: TextStyle(
                        color: isActive ? Colors.white : _Glass.textSecondary,
                        fontSize: 13,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w500,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// =============================================================================
// AdminLogsScreen
// =============================================================================
class AdminLogsScreen extends StatefulWidget {
  const AdminLogsScreen({super.key});

  @override
  State<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends State<AdminLogsScreen> {
  _LogsTab _activeTab = _LogsTab.jobQueue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SubMenuTabBar(
          activeTab: _activeTab,
          onTabChanged: (tab) => setState(() => _activeTab = tab),
        ),

        const SizedBox(height: 8),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: _Glass.surfaceMid,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _Glass.borderMid, width: 0.8),
            boxShadow: const [_Glass.rowShadow],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _iconForTab(_activeTab),
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _titleForTab(_activeTab),
                      style: const TextStyle(
                        color: _Glass.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _subtitleForTab(_activeTab),
                      style: const TextStyle(
                        color: _Glass.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color.fromARGB(240, 253, 253, 253),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _Glass.borderMid, width: 0.8),
              boxShadow: const [_Glass.rowShadow],
            ),
            child: _buildContent(),
          ),
        ),
      ],
    );
  }

  IconData _iconForTab(_LogsTab t) {
    switch (t) {
      case _LogsTab.jobQueue:
        return Icons.queue_outlined;
      case _LogsTab.salesRecord:
        return Icons.receipt_long_outlined;
      case _LogsTab.employeeActivity:
        return Icons.people_outline_rounded;
      case _LogsTab.customerFeedback:
        return Icons.rate_review_outlined;
    }
  }

  String _titleForTab(_LogsTab t) {
    switch (t) {
      case _LogsTab.jobQueue:
        return 'Job Queue';
      case _LogsTab.salesRecord:
        return 'Sales Record';
      case _LogsTab.employeeActivity:
        return 'Employee Activity';
      case _LogsTab.customerFeedback:
        return 'Customer Feedback';
    }
  }

  String _subtitleForTab(_LogsTab t) {
    switch (t) {
      case _LogsTab.jobQueue:
        return 'Monitor and track all print jobs';
      case _LogsTab.salesRecord:
        return 'View sales data and reports';
      case _LogsTab.employeeActivity:
        return 'Inventory updates by employees';
      case _LogsTab.customerFeedback:
        return 'Feedback submitted by customers';
    }
  }

  Widget _buildContent() {
    switch (_activeTab) {
      case _LogsTab.jobQueue:
        return const _JobQueueTab();
      case _LogsTab.salesRecord:
        return const _SalesRecordSubTab();
      case _LogsTab.employeeActivity:
        return const _InventoryLogsTab();
      case _LogsTab.customerFeedback:
        return const _CustomerFeedbackTab();
    }
  }
}

// =============================================================================
// Job Queue Tab  —  iOS redesign
// =============================================================================
enum _QueueSubTab { pending, active, ready, cancelled, history }

class _JobQueueTab extends StatefulWidget {
  const _JobQueueTab();

  @override
  State<_JobQueueTab> createState() => _JobQueueTabState();
}

class _JobQueueTabState extends State<_JobQueueTab> {
  _QueueSubTab _sub = _QueueSubTab.pending;

  static const _statusTabs = [
    (
      _QueueSubTab.pending,
      'Pending',
      Icons.hourglass_empty_rounded,
      Color(0xFFD97706),
    ),
    (_QueueSubTab.active, 'Active', Icons.bolt_rounded, Color(0xFF2563EB)),
    (
      _QueueSubTab.ready,
      'Ready',
      Icons.check_circle_outline,
      Color(0xFF16A34A),
    ),
    (
      _QueueSubTab.cancelled,
      'Cancelled',
      Icons.cancel_outlined,
      Color(0xFFDC2626),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isHistory = _sub == _QueueSubTab.history;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isHistory)
            Row(
              children: [
                Expanded(
                  child: _IOSSegmentControl<_QueueSubTab>(
                    selected: _sub,
                    items: _statusTabs
                        .map(
                          (t) => _IOSSegmentItem(
                            value: t.$1,
                            label: t.$2,
                            icon: t.$3,
                            accent: t.$4,
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _sub = v),
                  ),
                ),

                const SizedBox(width: 10),

                GestureDetector(
                  onTap: () => setState(() => _sub = _QueueSubTab.history),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6D28D9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Order History',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

          if (!isHistory) const SizedBox(height: 14),

          Expanded(
            child: isHistory
                ? _AdminOrderHistory(
                    onBack: () => setState(() => _sub = _QueueSubTab.pending),
                  )
                : _buildQueueContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueContent() {
    String jobStatus;
    switch (_sub) {
      case _QueueSubTab.pending:
        jobStatus = 'pending';
        break;
      case _QueueSubTab.active:
        jobStatus = 'active';
        break;
      case _QueueSubTab.ready:
        jobStatus = 'completed';
        break;
      case _QueueSubTab.cancelled:
        jobStatus = 'cancelled';
        break;
      default:
        jobStatus = 'pending';
    }
    return _QueueStatusList(jobStatus: jobStatus);
  }
}

// ── iOS Segment Control widget ────────────────────────────────────────────────
class _IOSSegmentItem<T> {
  final T value;
  final String label;
  final IconData icon;
  final Color accent;
  const _IOSSegmentItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.accent,
  });
}

class _IOSSegmentControl<T> extends StatelessWidget {
  final T selected;
  final List<_IOSSegmentItem<T>> items;
  final ValueChanged<T> onChanged;

  const _IOSSegmentControl({
    required this.selected,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFF4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: items.map((item) {
            final isActive = selected == item.value;
            return GestureDetector(
              onTap: () => onChanged(item.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      size: 12,
                      color: isActive ? item.accent : _iOS.label3,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      item.label,
                      style: TextStyle(
                        color: isActive ? item.accent : _iOS.label3,
                        fontSize: 12,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w500,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Single-status queue list ──────────────────────────────────────────────────
class _QueueStatusList extends StatelessWidget {
  final String jobStatus;
  const _QueueStatusList({required this.jobStatus});

  static const Color _amber = Color(0xFFB45309);

  static String _fmtDate(dynamic ts) {
    if (ts == null) return '—';
    try {
      final d = (ts as Timestamp).toDate().toLocal();
      const m = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${m[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) {
      return '—';
    }
  }

  static Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFD97706);
      case 'active':
        return const Color(0xFF2563EB);
      case 'completed':
        return const Color(0xFF16A34A);
      case 'cancelled':
        return const Color(0xFFDC2626);
      default:
        return _Glass.textMuted;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'completed':
        return 'Ready';
      default:
        return s[0].toUpperCase() + s.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Order_Queue')
          .where('job_status', isEqualTo: jobStatus)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: _Glass.textPrimary.withValues(alpha: 0.4),
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
            ),
          );
        }

        final docs = [...(snapshot.data?.docs ?? [])]
          ..sort((a, b) {
            final ta =
                (a.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
            final tb =
                (b.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return ta.compareTo(tb);
          });

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFEFF4),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.queue_outlined,
                    size: 28,
                    color: _iOS.label3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No $jobStatus jobs',
                  style: const TextStyle(
                    color: _iOS.label,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Jobs assigned to this status will appear here.',
                  style: TextStyle(color: _iOS.label3, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                '${docs.length} JOB${docs.length == 1 ? '' : 'S'}',
                style: const TextStyle(
                  color: _iOS.label3,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            Expanded(
              child: ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final orderId = data['order_id']?.toString() ?? '—';
                  final customer = data['customer_name']?.toString() ?? '—';
                  final status = data['job_status']?.toString() ?? jobStatus;
                  final total = (data['total_price'] as num?)?.toDouble() ?? 0;
                  final products =
                      (data['products'] as List?)
                          ?.cast<Map<String, dynamic>>() ??
                      [];
                  final dateStr = _fmtDate(data['created_at']);
                  final statusColor = _statusColor(status);
                  final productSummary = products.isEmpty
                      ? '—'
                      : products
                            .map((p) => '${p['name'] ?? '?'} ×${p['qty'] ?? 1}')
                            .join(', ');

                  return _IOSJobCard(
                    index: i + 1,
                    orderId: orderId,
                    customer: customer,
                    statusLabel: _statusLabel(status),
                    statusColor: statusColor,
                    productSummary: products.isNotEmpty ? productSummary : null,
                    dateStr: dateStr,
                    total: total,
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

// ── iOS Job Card ──────────────────────────────────────────────────────────────
class _IOSJobCard extends StatelessWidget {
  final int index;
  final String orderId;
  final String customer;
  final String statusLabel;
  final Color statusColor;
  final String? productSummary;
  final String dateStr;
  final double total;

  const _IOSJobCard({
    required this.index,
    required this.orderId,
    required this.customer,
    required this.statusLabel,
    required this.statusColor,
    this.productSummary,
    required this.dateStr,
    required this.total,
  });

  static const Color _amber = Color(0xFFB45309);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 32,
          child: Center(
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: _amber.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(color: _amber.withValues(alpha: 0.35)),
              ),
              child: Center(
                child: Text(
                  '$index',
                  style: const TextStyle(
                    color: _amber,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 6),

        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E5EA), width: 0.8),
              boxShadow: const [_iOS.cardShadow],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            orderId,
                            style: const TextStyle(
                              color: _iOS.label,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            customer,
                            style: const TextStyle(
                              color: _iOS.label2,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),

                if (productSummary != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    productSummary!,
                    style: const TextStyle(color: _iOS.label2, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 10),
                Container(height: 0.5, color: _iOS.separator),
                const SizedBox(height: 10),

                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 11,
                      color: _iOS.label3,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dateStr,
                      style: const TextStyle(color: _iOS.label3, fontSize: 12),
                    ),
                    const Spacer(),
                    Text(
                      '₱${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: _amber,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Admin Order History — with Customer ID search + invoice + total/paid/balance
// =============================================================================
class _AdminOrderHistory extends StatefulWidget {
  final VoidCallback onBack;
  const _AdminOrderHistory({required this.onBack});

  @override
  State<_AdminOrderHistory> createState() => _AdminOrderHistoryState();
}

class _AdminOrderHistoryState extends State<_AdminOrderHistory> {
  String _statusFilter = 'all';
  String _search = '';
  final _searchCtrl = TextEditingController();

  static const _statusOpts = [
    ('all', 'All'),
    ('pending', 'Pending'),
    ('active', 'Active'),
    ('ready', 'Ready'),
    ('cancelled', 'Cancelled'),
    ('completed', 'Completed'),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Stream<List<QueryDocumentSnapshot>> _stream() {
    Query q = FirebaseFirestore.instance.collection('Orders');
    if (_statusFilter == 'all') {
      q = q.where(
        'status',
        whereIn: [
          'pending',
          'in_production',
          'ready',
          'completed',
          'cancelled',
        ],
      );
    } else if (_statusFilter == 'active') {
      q = q.where('status', isEqualTo: 'in_production');
    } else if (_statusFilter == 'ready') {
      q = q.where('status', isEqualTo: 'ready');
    } else {
      q = q.where('status', isEqualTo: _statusFilter);
    }
    return q.snapshots().map((snap) {
      final docs = [...snap.docs]
        ..sort((a, b) {
          final ta =
              (a.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
          final tb =
              (b.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
          if (ta == null && tb == null) return 0;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return tb.compareTo(ta);
        });
      return docs;
    });
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':
        return const Color(0xFFD97706);
      case 'in_production':
        return const Color(0xFF2563EB);
      case 'ready':
        return const Color(0xFF16A34A);
      case 'completed':
        return const Color(0xFF6D28D9);
      case 'cancelled':
        return const Color(0xFFDC2626);
      default:
        return _Glass.textMuted;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'in_production':
        return 'Active';
      default:
        return s[0].toUpperCase() + s.substring(1);
    }
  }

  String _fmtDate(dynamic ts) {
    if (ts == null) return '—';
    try {
      final d = (ts as Timestamp).toDate().toLocal();
      const m = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${m[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) {
      return '—';
    }
  }

  Color _filterAccent(String val) {
    switch (val) {
      case 'pending':
        return const Color(0xFFD97706);
      case 'active':
        return const Color(0xFF2563EB);
      case 'ready':
        return const Color(0xFF16A34A);
      case 'cancelled':
        return const Color(0xFFDC2626);
      case 'completed':
        return const Color(0xFF6D28D9);
      default:
        return const Color(0xFF1A1A2E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dropdownAccent = _filterAccent(_statusFilter);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Top bar: Back + Search + Filter ─────────────────────────────
        Row(
          children: [
            GestureDetector(
              onTap: widget.onBack,
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFEFF4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chevron_left_rounded,
                      size: 18,
                      color: _iOS.label2,
                    ),
                    SizedBox(width: 2),
                    Text(
                      'Back',
                      style: TextStyle(
                        color: _iOS.label2,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 10),

            // FIXED: Search now includes customer_uid / customer ID
            Expanded(
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFEFF4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) =>
                      setState(() => _search = v.trim().toLowerCase()),
                  style: const TextStyle(
                    color: _iOS.label,
                    fontSize: 14,
                    letterSpacing: -0.1,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by Order ID or Customer Name',
                    hintStyle: TextStyle(color: _iOS.label3, fontSize: 13),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 16,
                      color: _iOS.label3,
                    ),
                    suffixIcon: _search.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              setState(() => _search = '');
                            },
                            child: const Icon(
                              Icons.clear,
                              size: 16,
                              color: _iOS.label3,
                            ),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 10),

            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _statusFilter == 'all'
                    ? const Color(0xFF1A1A2E)
                    : dropdownAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _statusFilter,
                  isDense: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'sans-serif',
                    letterSpacing: -0.1,
                  ),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  items: _statusOpts.map((opt) {
                    final accent = _filterAccent(opt.$1);
                    return DropdownMenuItem<String>(
                      value: opt.$1,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            opt.$2,
                            style: const TextStyle(
                              color: _iOS.label,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _statusFilter = val);
                  },
                  selectedItemBuilder: (_) => _statusOpts.map((opt) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          opt.$2,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        Expanded(
          child: StreamBuilder<List<QueryDocumentSnapshot>>(
            stream: _stream(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return Center(
                  child: CircularProgressIndicator(
                    color: _Glass.textPrimary.withValues(alpha: 0.4),
                  ),
                );
              }
              if (snap.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snap.error}',
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 12,
                    ),
                  ),
                );
              }

              var docs = snap.data ?? [];

              // FIXED: search checks order_id, customer_name, AND customer_uid
              if (_search.isNotEmpty) {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final id = (data['order_id']?.toString() ?? d.id)
                      .toLowerCase();
                  final name = (data['customer_name']?.toString() ?? '')
                      .toLowerCase();
                  final customerId = (data['customer_uid']?.toString() ?? '')
                      .toLowerCase();
                  return id.contains(_search) ||
                      name.contains(_search) ||
                      customerId.contains(_search);
                }).toList();
              }

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFEFF4),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.history,
                          size: 28,
                          color: _iOS.label3,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'No orders found',
                        style: TextStyle(
                          color: _iOS.label,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Try adjusting the filter or search.',
                        style: TextStyle(color: _iOS.label3, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      '${docs.length} ORDER${docs.length == 1 ? '' : 'S'}',
                      style: const TextStyle(
                        color: _iOS.label3,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final doc = docs[i];
                        final data = doc.data() as Map<String, dynamic>;
                        final orderLabel =
                            data['order_id']?.toString() ?? doc.id;
                        final customer =
                            data['customer_name']?.toString() ?? '—';
                        final status = data['status']?.toString() ?? '';
                        final total =
                            (data['total_price'] as num?)?.toDouble() ?? 0;
                        final paid =
                            (data['amount_paid'] as num?)?.toDouble() ?? 0;
                        final remaining =
                            (data['remaining_balance'] as num?)?.toDouble() ??
                            (total - paid);
                        final products =
                            (data['products'] as List?)
                                ?.cast<Map<String, dynamic>>() ??
                            [];
                        final dateStr = _fmtDate(data['created_at']);
                        final statusColor = _statusColor(status);
                        final invoiceId = data['invoice_id']?.toString();

                        return _IOSOrderHistoryCard(
                          docId: doc.id,
                          orderId: orderLabel,
                          customer: customer,
                          dateStr: dateStr,
                          statusLabel: _statusLabel(status),
                          statusColor: statusColor,
                          products: products,
                          paid: paid,
                          total: total,
                          remaining: remaining,
                          invoiceId: invoiceId,
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── iOS Order History Card — with total/paid/balance + View Invoice ───────────
class _IOSOrderHistoryCard extends StatelessWidget {
  final String docId;
  final String orderId;
  final String customer;
  final String dateStr;
  final String statusLabel;
  final Color statusColor;
  final List<Map<String, dynamic>> products;
  final double paid;
  final double total;
  final double remaining;
  final String? invoiceId;

  const _IOSOrderHistoryCard({
    required this.docId,
    required this.orderId,
    required this.customer,
    required this.dateStr,
    required this.statusLabel,
    required this.statusColor,
    required this.products,
    required this.paid,
    required this.total,
    required this.remaining,
    this.invoiceId,
  });

  static const Color _amber = Color(0xFFB45309);

  @override
  Widget build(BuildContext context) {
    final fullyPaid = remaining < 0.01;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 0.8),
        boxShadow: const [_iOS.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      orderId,
                      style: const TextStyle(
                        color: _iOS.label,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$customer · $dateStr',
                      style: const TextStyle(color: _iOS.label2, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          if (products.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              products
                  .map((p) => '${p['name'] ?? '?'} ×${p['qty'] ?? 1}')
                  .join(', '),
              style: const TextStyle(color: _iOS.label2, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 10),
          Container(height: 0.5, color: _iOS.separator),
          const SizedBox(height: 10),

          // IMPROVED: Total / Paid / Balance — full-width row with better spacing
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _HistoryChipWide(
                    label: 'Total',
                    value: '₱${total.toStringAsFixed(2)}',
                    color: const Color(0xFF374151),
                    bgColor: const Color(0xFFF9FAFB),
                    borderColor: const Color(0xFFE5E7EB),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _HistoryChipWide(
                    label: 'Paid',
                    value: '₱${paid.toStringAsFixed(2)}',
                    color: const Color(0xFF16A34A),
                    bgColor: const Color(0xFFF0FDF4),
                    borderColor: const Color(0xFFBBF7D0),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _HistoryChipWide(
                    label: fullyPaid ? 'Fully Paid' : 'Balance',
                    value: fullyPaid
                        ? '✓ Paid'
                        : '₱${remaining.toStringAsFixed(2)}',
                    color: fullyPaid ? const Color(0xFF16A34A) : _amber,
                    bgColor: fullyPaid
                        ? const Color(0xFFF0FDF4)
                        : const Color(0xFFFFFBEB),
                    borderColor: fullyPaid
                        ? const Color(0xFFBBF7D0)
                        : const Color(0xFFFDE68A),
                    bold: true,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── View Invoice button ────────────────────────────────────
          Builder(
            builder: (ctx) => OutlinedButton.icon(
              onPressed: () async {
                String? invId = invoiceId;
                if (invId == null) {
                  final orderSnap = await FirebaseFirestore.instance
                      .collection('Orders')
                      .doc(docId)
                      .get();
                  invId = orderSnap.data()?['invoice_id']?.toString();
                }
                if (invId != null && ctx.mounted) {
                  Navigator.of(ctx).push(
                    MaterialPageRoute(
                      builder: (_) => InvoiceScreen(invoiceId: invId!),
                    ),
                  );
                } else if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('No invoice for this order')),
                  );
                }
              },
              icon: const Icon(
                Icons.receipt_long_rounded,
                size: 15,
                color: Color(0xFF6D28D9),
              ),
              label: const Text(
                'View Invoice',
                style: TextStyle(
                  color: Color(0xFF6D28D9),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: const Color(0xFF6D28D9).withValues(alpha: 0.4),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 7,
                  horizontal: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Improved wide info chip for order history card ────────────────────────────
class _HistoryChipWide extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final bool bold;

  const _HistoryChipWide({
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: borderColor, width: 1),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: color.withValues(alpha: 0.6),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: bold ? 13 : 12,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

// Keep the old _HistoryChip for backward compatibility if needed
class _HistoryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;

  const _HistoryChip({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          color: color.withValues(alpha: 0.6),
          fontSize: 9,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: bold ? 13 : 12,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    ],
  );
}

// =============================================================================
// Sales Record Sub-Tab
// =============================================================================
enum _SalesSubTab { record, report }

class _SalesRecordSubTab extends StatefulWidget {
  const _SalesRecordSubTab();

  @override
  State<_SalesRecordSubTab> createState() => _SalesRecordSubTabState();
}

class _SalesRecordSubTabState extends State<_SalesRecordSubTab> {
  _SalesSubTab _sub = _SalesSubTab.record;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SalesInnerTab(
                  label: 'Sales Record',
                  icon: Icons.table_rows_outlined,
                  isActive: _sub == _SalesSubTab.record,
                  onTap: () => setState(() => _sub = _SalesSubTab.record),
                ),
                const SizedBox(width: 4),
                _SalesInnerTab(
                  label: 'Sales Report',
                  icon: Icons.bar_chart_rounded,
                  isActive: _sub == _SalesSubTab.report,
                  onTap: () => setState(() => _sub = _SalesSubTab.report),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _sub == _SalesSubTab.record
              ? const SalesRecordTable()
              : const AdminSalesReportView(),
        ),
      ],
    );
  }
}

class _SalesInnerTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _SalesInnerTab({
    required this.label,
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
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1A1A2E) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: isActive ? const Color(0x33FFFFFF) : Colors.transparent,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isActive ? Colors.white : _Glass.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : _Glass.textSecondary,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Employee Activity (Inventory Logs) Tab
// =============================================================================
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
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        title: const Text(
          'Clear All Logs',
          style: TextStyle(
            color: _Glass.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'This will permanently delete all inventory log entries. This cannot be undone.',
          style: TextStyle(color: _Glass.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: _Glass.textSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
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
        for (final doc in snap.docs) batch.delete(doc.reference);
        await batch.commit();
        if (snap.docs.length < batchSize) break;
      }
      messenger.showSnackBar(
        SnackBar(
          content: const Text('All logs cleared'),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Employee Activity',
                      style: TextStyle(
                        color: _Glass.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Inventory updates by employees',
                      style: TextStyle(color: _Glass.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _confirmClearAll(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.delete_sweep_outlined,
                        size: 13,
                        color: Colors.red.shade600,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Clear All',
                        style: TextStyle(
                          color: Colors.red.shade600,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _empCtrl,
                  style: const TextStyle(
                    color: _Glass.textPrimary,
                    fontSize: 13,
                  ),
                  onChanged: (v) =>
                      setState(() => _employeeFilter = v.toLowerCase()),
                  decoration: _Glass.field(
                    'Filter by employee',
                    icon: Icons.person_search_outlined,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _matCtrl,
                  style: const TextStyle(
                    color: _Glass.textPrimary,
                    fontSize: 13,
                  ),
                  onChanged: (v) =>
                      setState(() => _materialFilter = v.toLowerCase()),
                  decoration: _Glass.field(
                    'Filter by material',
                    icon: Icons.inventory_2_outlined,
                  ),
                ),
              ),
              if (_employeeFilter.isNotEmpty || _materialFilter.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: GestureDetector(
                    onTap: () {
                      _empCtrl.clear();
                      _matCtrl.clear();
                      setState(() {
                        _employeeFilter = '';
                        _materialFilter = '';
                      });
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: const Icon(
                        Icons.clear,
                        color: _Glass.textMuted,
                        size: 16,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text('Timestamp', style: _hStyle)),
                Expanded(flex: 2, child: Text('Employee', style: _hStyle)),
                Expanded(flex: 3, child: Text('Material', style: _hStyle)),
                SizedBox(
                  width: 70,
                  child: Text(
                    'Added',
                    style: _hStyle,
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    'New Stock',
                    style: _hStyle,
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    'Method',
                    style: _hStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('InventoryLogs')
                  .orderBy('timestamp', descending: true)
                  .limit(200)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: _Glass.textPrimary.withValues(alpha: 0.4),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: const Icon(
                            Icons.history_toggle_off,
                            size: 32,
                            color: _Glass.textMuted,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No activity logs yet',
                          style: TextStyle(
                            color: _Glass.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Logs appear when employees replenish stock',
                          style: TextStyle(
                            color: _Glass.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final filtered = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final emp =
                      data['updated_by_name']?.toString().toLowerCase() ?? '';
                  final mat =
                      data['material_name']?.toString().toLowerCase() ?? '';
                  return (_employeeFilter.isEmpty ||
                          emp.contains(_employeeFilter)) &&
                      (_materialFilter.isEmpty ||
                          mat.contains(_materialFilter));
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'No logs matching your filter',
                      style: TextStyle(color: _Glass.textMuted, fontSize: 13),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final data = filtered[i].data() as Map<String, dynamic>;
                    return _LogRow(data: data, dateFmt: _dateFmt);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static const _hStyle = TextStyle(
    color: Color(0xFF374151),
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
  );
}

// =============================================================================
// Customer Feedback Tab
// =============================================================================
class _CustomerFeedbackTab extends StatelessWidget {
  const _CustomerFeedbackTab();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Feedback')
            .orderBy('createdAt', descending: true)
            .limit(200)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: _Glass.textPrimary.withValues(alpha: 0.4),
              ),
            );
          }
          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Icon(
                      Icons.rate_review_outlined,
                      size: 32,
                      color: _Glass.textMuted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No customer feedback yet',
                    style: TextStyle(
                      color: _Glass.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Feedback submitted by customers will appear here',
                    style: TextStyle(color: _Glass.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const Text(
                      'Customer Feedback',
                      style: TextStyle(
                        color: _Glass.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Text(
                        '${docs.length}',
                        style: const TextStyle(
                          color: _Glass.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
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
                        ? DateFormat('MMM dd, yyyy hh:mm a').format(ts.toDate())
                        : '—';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xE0F7F7F7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.person_outline,
                                  color: _Glass.textMuted,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  customer,
                                  style: const TextStyle(
                                    color: _Glass.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (rating != null) ...[
                                Row(
                                  children: List.generate(
                                    5,
                                    (s) => Icon(
                                      s < rating
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      color: AppTheme.gold,
                                      size: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                timeStr,
                                style: const TextStyle(
                                  color: _Glass.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            message,
                            style: const TextStyle(
                              color: _Glass.textSecondary,
                              fontSize: 13,
                              height: 1.5,
                            ),
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
      ),
    );
  }
}

// =============================================================================
// Log Row
// =============================================================================
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
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF6B7280);
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
    final qtyDisplay = isPositive ? '+${fmt(qtyAdded)}' : fmt(qtyAdded);
    final qtyColor = isPositive
        ? const Color(0xFF16A34A)
        : isNegative
        ? const Color(0xFFDC2626)
        : _Glass.textMuted;
    final methodColor = _methodColor(method);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isOrderDeduction
            ? const Color(0xE8F5F3FF)
            : const Color(0xE0F7F7F7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOrderDeduction
              ? const Color(0xFFDDD6FE)
              : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              timeStr,
              style: const TextStyle(color: _Glass.textMuted, fontSize: 11),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              isOrderDeduction ? 'Auto (Order)' : employee,
              style: TextStyle(
                color: isOrderDeduction
                    ? const Color(0xFF7C3AED)
                    : _Glass.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  materialName,
                  style: const TextStyle(
                    color: _Glass.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  materialId,
                  style: const TextStyle(
                    color: _Glass.textMuted,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
                if (isOrderDeduction && productName.isNotEmpty)
                  Text(
                    'Product: $productName${orderId.isNotEmpty ? ' · #${orderId.substring(0, orderId.length.clamp(0, 6))}' : ''}',
                    style: const TextStyle(
                      color: Color(0xFF7C3AED),
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              qtyDisplay,
              style: TextStyle(
                color: qtyColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              fmt(newStock),
              style: const TextStyle(
                color: _Glass.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 64,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: methodColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: methodColor.withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  _methodLabel(method),
                  style: TextStyle(
                    color: methodColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
