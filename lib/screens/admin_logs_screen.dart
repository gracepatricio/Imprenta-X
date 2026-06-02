import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'sales_widgets.dart';
import 'sales_import_widget.dart';
import 'invoice_screen.dart';

// =============================================================================
// Design Tokens — Liquid Glass (matches Account screen)
// =============================================================================
class _G {
  static const Color navyBlue = Color(0xFF0F1A2E);
  static const Color surface = Color(0xF8FFFFFF);
  static const Color surfaceMid = Color(0xF0FFFFFF);
  static const Color surfaceThin = Color(0xA0FFFFFF);

  static const Color borderMid = Color(0x70FFFFFF);
  static const Color borderDim = Color(0x30FFFFFF);
  static const Color borderSolid = Color(0xFFE5E7EB);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xCC0F172A);
  static const Color textMuted = Color(0x880F172A);

  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentViolet = Color(0xFF8B5CF6);
  static const Color accentEmerald = Color(0xFF10B981);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentRose = Color(0xFFEF4444);
  static const Color amber = Color(0xFFB45309);

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
  }) => BoxDecoration(
    color: surfaceMid,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: tintBorder ?? borderMid, width: 0.9),
    boxShadow: [elevated ? elevatedShadow : rowShadow],
  );

  static BoxDecoration pill({Color? tint}) => BoxDecoration(
    color: tint != null ? tint.withValues(alpha: 0.15) : surfaceThin,
    borderRadius: BorderRadius.circular(99),
    border: Border.all(
      color: tint != null ? tint.withValues(alpha: 0.50) : borderMid,
      width: 0.9,
    ),
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

  static InputDecoration field(
      String hint, {
        IconData? icon,
      }) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: textMuted, fontSize: 13),
    prefixIcon: icon != null ? Icon(icon, size: 16, color: textMuted) : null,
    filled: true,
    fillColor: surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: borderMid, width: 0.9),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: navyBlue, width: 1.5),
    ),
  );
}

// Reusable frosted-glass card wrapper
class _BlurCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final bool elevated;
  final Color? tintBorder;

  const _BlurCard({
    required this.child,
    this.padding,
    this.radius = 18,
    this.elevated = false,
    this.tintBorder,
  });

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Container(
        decoration: _G.glass(
          radius: radius,
          elevated: elevated,
          tintBorder: tintBorder,
        ),
        padding: padding,
        child: child,
      ),
    ),
  );
}

// =============================================================================
// Sub-menu tab enum
// =============================================================================
enum _LogsTab { jobQueue, salesRecord, employeeActivity, customerFeedback }

// =============================================================================
// AdminLogsScreen — unified header + tabs
// =============================================================================
class AdminLogsScreen extends StatefulWidget {
  const AdminLogsScreen({super.key});

  @override
  State<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends State<AdminLogsScreen> {
  _LogsTab _activeTab = _LogsTab.jobQueue;

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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Unified header card ────────────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              decoration: _G.glass(radius: 20, elevated: true),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _G.navyBlue,
                          borderRadius: BorderRadius.circular(12),
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
                                color: _G.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              _subtitleForTab(_activeTab),
                              style: const TextStyle(
                                color: _G.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Divider
                  Divider(height: 1, color: _G.borderDim),

                  const SizedBox(height: 12),

                  // Tab pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: _tabs.map((t) {
                        final isActive = _activeTab == t.$1;
                        return GestureDetector(
                          onTap: () => setState(() => _activeTab = t.$1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 9,
                            ),
                            decoration: isActive
                                ? _G.solidPill(_G.navyBlue, glow: true)
                                : BoxDecoration(
                              color: _G.surfaceThin,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: _G.borderMid,
                                width: 0.9,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  t.$3,
                                  size: 13,
                                  color: isActive
                                      ? Colors.white
                                      : _G.textSecondary,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  t.$2,
                                  style: TextStyle(
                                    color: isActive
                                        ? Colors.white
                                        : _G.textSecondary,
                                    fontSize: 13,
                                    fontWeight: isActive
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // ── Content area ───────────────────────────────────────────────────
        Expanded(
          child: _BlurCard(radius: 20, elevated: true, child: _buildContent()),
        ),
      ],
    );
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
// Job Queue Tab
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
                  child: _PillSegmentControl<_QueueSubTab>(
                    selected: _sub,
                    items: _statusTabs
                        .map(
                          (t) => _PillSegmentItem(
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
                      horizontal: 16,
                      vertical: 9,
                    ),
                    decoration: _G.solidPill(_G.accentViolet),
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

// ── Pill Segment Control ──────────────────────────────────────────────────────
class _PillSegmentItem<T> {
  final T value;
  final String label;
  final IconData icon;
  final Color accent;
  const _PillSegmentItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.accent,
  });
}

class _PillSegmentControl<T> extends StatelessWidget {
  final T selected;
  final List<_PillSegmentItem<T>> items;
  final ValueChanged<T> onChanged;

  const _PillSegmentControl({
    required this.selected,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _G.surfaceThin,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _G.borderMid, width: 0.9),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: items.map((item) {
            final isActive = selected == item.value;
            return GestureDetector(
              onTap: () => onChanged(item.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: isActive
                    ? BoxDecoration(
                  color: item.accent,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [
                    BoxShadow(
                      color: item.accent.withValues(alpha: 0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                )
                    : const BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.all(Radius.circular(99)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      size: 12,
                      color: isActive ? Colors.white : _G.textMuted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      item.label,
                      style: TextStyle(
                        color: isActive ? Colors.white : _G.textSecondary,
                        fontSize: 12,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w500,
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

// ── Queue status list ─────────────────────────────────────────────────────────
class _QueueStatusList extends StatelessWidget {
  final String jobStatus;
  const _QueueStatusList({required this.jobStatus});

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
        return _G.textMuted;
    }
  }

  String _statusLabel(String s) {
    if (s == 'completed') return 'Ready';
    return s[0].toUpperCase() + s.substring(1);
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
              color: _G.navyBlue.withValues(alpha: 0.5),
              strokeWidth: 2,
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: _G.accentRose, fontSize: 13),
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
                  decoration: _G.glass(radius: 20),
                  child: const Icon(
                    Icons.queue_outlined,
                    size: 28,
                    color: _G.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No $jobStatus jobs',
                  style: const TextStyle(
                    color: _G.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Jobs assigned to this status will appear here.',
                  style: TextStyle(color: _G.textMuted, fontSize: 13),
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
                  color: _G.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                      ? null
                      : products
                      .map((p) => '${p['name'] ?? '?'} ×${p['qty'] ?? 1}')
                      .join(', ');

                  return _JobCard(
                    index: i + 1,
                    orderId: orderId,
                    customer: customer,
                    statusLabel: _statusLabel(status),
                    statusColor: statusColor,
                    productSummary: productSummary,
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

// ── Job Card (glass) ──────────────────────────────────────────────────────────
class _JobCard extends StatelessWidget {
  final int index;
  final String orderId;
  final String customer;
  final String statusLabel;
  final Color statusColor;
  final String? productSummary;
  final String dateStr;
  final double total;

  const _JobCard({
    required this.index,
    required this.orderId,
    required this.customer,
    required this.statusLabel,
    required this.statusColor,
    this.productSummary,
    required this.dateStr,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _G.amber.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: _G.amber.withValues(alpha: 0.35)),
          ),
          child: Center(
            child: Text(
              '$index',
              style: const TextStyle(
                color: _G.amber,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _BlurCard(
            radius: 14,
            padding: const EdgeInsets.all(14),
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
                              color: _G.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            customer,
                            style: const TextStyle(
                              color: _G.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.35),
                          width: 0.8,
                        ),
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
                    style: const TextStyle(
                      color: _G.textSecondary,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                Divider(height: 0.8, color: _G.borderDim),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 11,
                      color: _G.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dateStr,
                      style: const TextStyle(color: _G.textMuted, fontSize: 12),
                    ),
                    const Spacer(),
                    Text(
                      '₱${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: _G.amber,
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
// Admin Order History
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
        return _G.accentViolet;
      case 'cancelled':
        return _G.accentRose;
      default:
        return _G.textMuted;
    }
  }

  String _statusLabel(String s) {
    if (s == 'in_production') return 'Active';
    return s[0].toUpperCase() + s.substring(1);
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
        return _G.accentRose;
      case 'completed':
        return _G.accentViolet;
      default:
        return _G.navyBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: widget.onBack,
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: _G.glass(radius: 99),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chevron_left_rounded,
                      size: 18,
                      color: _G.textSecondary,
                    ),
                    SizedBox(width: 2),
                    Text(
                      'Back',
                      style: TextStyle(
                        color: _G.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    height: 38,
                    decoration: _G.glass(radius: 14),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) =>
                          setState(() => _search = v.trim().toLowerCase()),
                      style: const TextStyle(
                        color: _G.textPrimary,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search by Order ID or Customer Name',
                        hintStyle: const TextStyle(
                          color: _G.textMuted,
                          fontSize: 12.5,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 16,
                          color: _G.textMuted,
                        ),
                        suffixIcon: _search.isNotEmpty
                            ? GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() => _search = '');
                          },
                          child: const Icon(
                            Icons.clear,
                            size: 15,
                            color: _G.textMuted,
                          ),
                        )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: _statusFilter == 'all'
                        ? _G.navyBlue
                        : _filterAccent(_statusFilter),
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: [
                      BoxShadow(
                        color:
                        (_statusFilter == 'all'
                            ? _G.navyBlue
                            : _filterAccent(_statusFilter))
                            .withValues(alpha: 0.30),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
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
                      dropdownColor: _G.surface,
                      borderRadius: BorderRadius.circular(16),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
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
                                  color: _G.textPrimary,
                                  fontSize: 12,
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
                      selectedItemBuilder: (_) => _statusOpts
                          .map(
                            (opt) => Text(
                          opt.$2,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                          .toList(),
                    ),
                  ),
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
                    color: _G.navyBlue.withValues(alpha: 0.5),
                    strokeWidth: 2,
                  ),
                );
              }
              if (snap.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snap.error}',
                    style: const TextStyle(color: _G.accentRose, fontSize: 12),
                  ),
                );
              }

              var docs = snap.data ?? [];
              if (_search.isNotEmpty) {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final id = (data['order_id']?.toString() ?? d.id)
                      .toLowerCase();
                  final name = (data['customer_name']?.toString() ?? '')
                      .toLowerCase();
                  final cid = (data['customer_uid']?.toString() ?? '')
                      .toLowerCase();
                  return id.contains(_search) ||
                      name.contains(_search) ||
                      cid.contains(_search);
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
                        decoration: _G.glass(radius: 20),
                        child: const Icon(
                          Icons.history,
                          size: 28,
                          color: _G.textMuted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'No orders found',
                        style: TextStyle(
                          color: _G.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Try adjusting the filter or search.',
                        style: TextStyle(color: _G.textMuted, fontSize: 13),
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
                        color: _G.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                        final invoiceId = data['invoice_id']?.toString();

                        return _OrderHistoryCard(
                          docId: doc.id,
                          orderId: orderLabel,
                          customer: customer,
                          dateStr: dateStr,
                          statusLabel: _statusLabel(status),
                          statusColor: _statusColor(status),
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

// ── Order History Card ────────────────────────────────────────────────────────
class _OrderHistoryCard extends StatelessWidget {
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

  const _OrderHistoryCard({
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

  @override
  Widget build(BuildContext context) {
    final fullyPaid = remaining < 0.01;

    return _BlurCard(
      radius: 14,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // ← don't stretch taller than needed
        children: [
          // ── Header row: order ID + status badge ──────────────────────────
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
                        color: _G.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$customer · $dateStr',
                      style: const TextStyle(
                        color: _G.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
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

          // ── Products ──────────────────────────────────────────────────────
          if (products.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              products
                  .map((p) => '${p['name'] ?? '?'} ×${p['qty'] ?? 1}')
                  .join(', '),
              style: const TextStyle(color: _G.textSecondary, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 10),
          Divider(height: 0.8, color: _G.borderDim),
          const SizedBox(height: 10),

          // ── Payment chips ─────────────────────────────────────────────────
          // Uses LayoutBuilder so chips reflow to 2-column on narrow screens.
          LayoutBuilder(
            builder: (_, constraints) {
              // Threshold: if each of 3 chips can't fit comfortably (~90px
              // each + gaps), reflow into a 2-col Wrap instead.
              final canFitThree = constraints.maxWidth >= 280;

              final totalChip = _PayChip(
                label: 'Total',
                value: '₱${total.toStringAsFixed(2)}',
                color: _G.textPrimary,
                bgColor: _G.surfaceThin,
                borderColor: _G.borderMid,
              );
              final paidChip = _PayChip(
                label: 'Paid',
                value: '₱${paid.toStringAsFixed(2)}',
                color: _G.accentEmerald,
                bgColor: const Color(0xFFF0FDF4),
                borderColor: const Color(0xFFBBF7D0),
              );
              final balanceChip = _PayChip(
                label: fullyPaid ? 'Fully Paid' : 'Balance',
                value: fullyPaid
                    ? '✓ Paid'
                    : '₱${remaining.toStringAsFixed(2)}',
                color: fullyPaid ? _G.accentEmerald : _G.amber,
                bgColor: fullyPaid
                    ? const Color(0xFFF0FDF4)
                    : const Color(0xFFFFFBEB),
                borderColor: fullyPaid
                    ? const Color(0xFFBBF7D0)
                    : const Color(0xFFFDE68A),
                bold: true,
              );

              if (canFitThree) {
                return Row(
                  children: [
                    Expanded(child: totalChip),
                    const SizedBox(width: 6),
                    Expanded(child: paidChip),
                    const SizedBox(width: 6),
                    Expanded(child: balanceChip),
                  ],
                );
              }

              // Narrow fallback: total + paid side by side, balance full-width
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: totalChip),
                      const SizedBox(width: 6),
                      Expanded(child: paidChip),
                    ],
                  ),
                  const SizedBox(height: 6),
                  balanceChip,
                ],
              );
            },
          ),

          const SizedBox(height: 10),

          // ── View Invoice button ───────────────────────────────────────────
          Builder(
            builder: (ctx) => GestureDetector(
              onTap: () async {
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
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _G.accentViolet.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: _G.accentViolet.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 14,
                      color: _G.accentViolet,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'View Invoice',
                      style: TextStyle(
                        color: _G.accentViolet,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Payment chip ──────────────────────────────────────────────────────────────
// Removed IntrinsicHeight wrapper — chip sizes itself from its own content.
class _PayChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final bool bold;

  const _PayChip({
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: borderColor, width: 0.9),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, // ← key: don't expand height
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: color.withValues(alpha: 0.55),
            fontSize: 9,
            fontWeight: FontWeight.w700,
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
          maxLines: 1,
        ),
      ],
    ),
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
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _G.surfaceThin,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: _G.borderMid, width: 0.9),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SalesPillTab(
                      label: 'Sales Record',
                      icon: Icons.table_rows_outlined,
                      isActive: _sub == _SalesSubTab.record,
                      onTap: () => setState(() => _sub = _SalesSubTab.record),
                    ),
                    const SizedBox(width: 4),
                    _SalesPillTab(
                      label: 'Sales Report',
                      icon: Icons.bar_chart_rounded,
                      isActive: _sub == _SalesSubTab.report,
                      onTap: () => setState(() => _sub = _SalesSubTab.report),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (_sub == _SalesSubTab.record) const SalesImportButton(),
            ],
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

class _SalesPillTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _SalesPillTab({
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: isActive
            ? _G.solidPill(_G.navyBlue)
            : const BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.all(Radius.circular(99)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isActive ? Colors.white : _G.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : _G.textSecondary,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
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
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        contentPadding: EdgeInsets.zero,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: 360,
              decoration: BoxDecoration(
                color: _G.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _G.borderMid, width: 0.9),
                boxShadow: const [_G.elevatedShadow],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _G.accentRose.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color: _G.accentRose.withValues(alpha: 0.30),
                              width: 0.9,
                            ),
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: _G.accentRose,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Clear All Logs',
                          style: TextStyle(
                            color: _G.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: _G.borderMid),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'This will permanently delete all inventory log entries. This cannot be undone.',
                          style: TextStyle(
                            color: _G.textSecondary,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(ctx, false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: _G.glass(radius: 99),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: _G.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => Navigator.pop(ctx, true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: _G.solidPill(_G.accentRose),
                                child: const Text(
                                  'Clear All',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
          content: const Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 15,
              ),
              SizedBox(width: 8),
              Text('All logs cleared'),
            ],
          ),
          backgroundColor: _G.accentEmerald,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: _G.accentRose,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.all(16),
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
                        color: _G.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Inventory updates by employees',
                      style: TextStyle(color: _G.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _confirmClearAll(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _G.accentRose.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: _G.accentRose.withValues(alpha: 0.35),
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
                  style: const TextStyle(color: _G.textPrimary, fontSize: 13),
                  onChanged: (v) =>
                      setState(() => _employeeFilter = v.toLowerCase()),
                  decoration: _G.field(
                    'Filter by employee',
                    icon: Icons.person_search_outlined,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _matCtrl,
                  style: const TextStyle(color: _G.textPrimary, fontSize: 13),
                  onChanged: (v) =>
                      setState(() => _materialFilter = v.toLowerCase()),
                  decoration: _G.field(
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
                      decoration: _G.glass(radius: 12),
                      child: const Icon(
                        Icons.clear,
                        color: _G.textMuted,
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
              color: _G.surfaceThin,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _G.borderMid, width: 0.9),
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
                      color: _G.navyBlue.withValues(alpha: 0.5),
                      strokeWidth: 2,
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
                          decoration: _G.glass(radius: 22),
                          child: const Icon(
                            Icons.history_toggle_off,
                            size: 32,
                            color: _G.textMuted,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No activity logs yet',
                          style: TextStyle(
                            color: _G.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Logs appear when employees replenish stock',
                          style: TextStyle(
                            color: _G.textSecondary,
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
                      style: TextStyle(color: _G.textMuted, fontSize: 13),
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
    color: _G.textSecondary,
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

  static const Color _feedbackAmber = Color(0xFFB45309);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('OrderReviews')
            .orderBy('created_at', descending: true)
            .limit(200)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: _G.navyBlue.withValues(alpha: 0.5),
                strokeWidth: 2,
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
                    decoration: _G.glass(radius: 22),
                    child: const Icon(
                      Icons.rate_review_outlined,
                      size: 32,
                      color: _G.textMuted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No customer feedback yet',
                    style: TextStyle(
                      color: _G.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Order reviews submitted by customers will appear here',
                    style: TextStyle(color: _G.textSecondary, fontSize: 13),
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
                        color: _G.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: _G.pill(),
                      child: Text(
                        '${docs.length}',
                        style: const TextStyle(
                          color: _G.textSecondary,
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
                    final customer = data['customer_name']?.toString() ?? '—';
                    final message = data['message']?.toString() ?? '';
                    final rating = (data['rating'] as num?)?.toInt();
                    final orderId = data['order_id']?.toString() ?? '';
                    final productName = data['product_name']?.toString() ?? '';
                    final ts = data['created_at'] as Timestamp?;
                    final timeStr = ts != null
                        ? DateFormat('MMM dd, yyyy hh:mm a').format(ts.toDate())
                        : '—';
                    final isRead = data['read'] == true;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: _BlurCard(
                        radius: 14,
                        padding: const EdgeInsets.all(14),
                        tintBorder: isRead
                            ? _G.borderMid
                            : _G.accentAmber.withValues(alpha: 0.45),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _G.navyBlue.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _G.navyBlue.withValues(
                                        alpha: 0.18,
                                      ),
                                      width: 0.9,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.person_rounded,
                                    color: _G.navyBlue,
                                    size: 17,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customer,
                                        style: const TextStyle(
                                          color: _G.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (orderId.isNotEmpty ||
                                          productName.isNotEmpty)
                                        Text(
                                          [
                                            if (orderId.isNotEmpty) orderId,
                                            if (productName.isNotEmpty)
                                              productName,
                                          ].join(' · '),
                                          style: const TextStyle(
                                            color: _feedbackAmber,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      _CustomerIdText(data: data),
                                    ],
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
                                        color: _feedbackAmber,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (!isRead)
                                  GestureDetector(
                                    onTap: () => FirebaseFirestore.instance
                                        .collection('OrderReviews')
                                        .doc(docs[i].id)
                                        .update({'read': true}),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _G.accentEmerald.withValues(
                                          alpha: 0.10,
                                        ),
                                        borderRadius: BorderRadius.circular(99),
                                        border: Border.all(
                                          color: _G.accentEmerald.withValues(
                                            alpha: 0.35,
                                          ),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_rounded,
                                            color: _G.accentEmerald,
                                            size: 12,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Mark read',
                                            style: TextStyle(
                                              color: _G.accentEmerald,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              timeStr,
                              style: const TextStyle(
                                color: _G.textMuted,
                                fontSize: 11,
                              ),
                            ),
                            if (message.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _G.surfaceThin,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _G.borderDim,
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  message,
                                  style: const TextStyle(
                                    color: _G.textSecondary,
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
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
        return _G.accentViolet;
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
        ? _G.accentEmerald
        : isNegative
        ? _G.accentRose
        : _G.textMuted;
    final methodColor = _methodColor(method);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isOrderDeduction
            ? _G.accentViolet.withValues(alpha: 0.05)
            : _G.surfaceThin,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isOrderDeduction
              ? _G.accentViolet.withValues(alpha: 0.20)
              : _G.borderDim,
          width: 0.9,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              timeStr,
              style: const TextStyle(color: _G.textMuted, fontSize: 11),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              isOrderDeduction ? 'Auto (Order)' : employee,
              style: TextStyle(
                color: isOrderDeduction ? _G.accentViolet : _G.textPrimary,
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
                    color: _G.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  materialId,
                  style: const TextStyle(
                    color: _G.textMuted,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
                if (isOrderDeduction && productName.isNotEmpty)
                  Text(
                    'Product: $productName${orderId.isNotEmpty ? ' · #${orderId.substring(0, orderId.length.clamp(0, 6))}' : ''}',
                    style: const TextStyle(
                      color: _G.accentViolet,
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
                color: _G.textPrimary,
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: methodColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: methodColor.withValues(alpha: 0.35),
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

// =============================================================================
// Customer ID resolver widget
// =============================================================================
class _CustomerIdText extends StatelessWidget {
  final Map<String, dynamic> data;
  const _CustomerIdText({required this.data});

  @override
  Widget build(BuildContext context) {
    final stored = data['customer_id']?.toString() ?? '';
    if (stored.isNotEmpty) return _label(stored);

    final uid = data['customer_uid']?.toString() ?? '';
    if (uid.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('User').doc(uid).get(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final cid =
            (snap.data?.data() as Map<String, dynamic>?)?['customer_id']
                ?.toString() ??
                '';
        if (cid.isEmpty) return const SizedBox.shrink();
        return _label(cid);
      },
    );
  }

  Widget _label(String id) => Text(
    'ID: $id',
    style: const TextStyle(
      color: _G.textMuted,
      fontSize: 11,
      fontFamily: 'monospace',
    ),
  );
}