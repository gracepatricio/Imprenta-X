import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'sales_widgets.dart';
import 'sales_import_widget.dart';
import 'invoice_screen.dart';
import 'design_file_viewer.dart';

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
  const AdminLogsScreen({super.key, this.initialJobStatus});
  final String? initialJobStatus;

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
        return 'View-only snapshot of current job queue';
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
        // ── Unified header card ──────────────────────────────────────────
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
                      // Read-only badge for Job Queue tab
                      if (_activeTab == _LogsTab.jobQueue)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _G.accentAmber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: _G.accentAmber.withValues(alpha: 0.40),
                              width: 0.8,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.visibility_outlined,
                                size: 11,
                                color: _G.amber,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'View Only',
                                style: TextStyle(
                                  color: _G.amber,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
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

        // ── Content area ─────────────────────────────────────────────────
        Expanded(
          child: _BlurCard(radius: 20, elevated: true, child: _buildContent()),
        ),
      ],
    );
  }

  Widget _buildContent() {
    switch (_activeTab) {
      case _LogsTab.jobQueue:
        // Use the shared read-only queue widget — same data source as employee
        return const AdminReadOnlyJobQueueTab();
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
// AdminReadOnlyJobQueueTab
// Mirrors the employee _JobQueueSection exactly (same Orders collection query)
// but strips all action buttons / status-change logic.
// =============================================================================
enum _AdminQueueSubTab { pending, active, ready, cancelled, history }

class AdminReadOnlyJobQueueTab extends StatefulWidget {
  const AdminReadOnlyJobQueueTab({super.key});

  @override
  State<AdminReadOnlyJobQueueTab> createState() =>
      _AdminReadOnlyJobQueueTabState();
}

class _AdminReadOnlyJobQueueTabState extends State<AdminReadOnlyJobQueueTab> {
  _AdminQueueSubTab _sub = _AdminQueueSubTab.pending;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  final Map<_AdminQueueSubTab, int> _counts = {};
  final List<StreamSubscription<QuerySnapshot>> _countSubs = [];

  static const _statusTabs = [
    (
      _AdminQueueSubTab.pending,
      'Pending',
      Icons.hourglass_empty_rounded,
      Color(0xFFD97706),
    ),
    (_AdminQueueSubTab.active, 'Active', Icons.bolt_rounded, Color(0xFF2563EB)),
    (
      _AdminQueueSubTab.ready,
      'Ready',
      Icons.check_circle_outline,
      Color(0xFF16A34A),
    ),
    (
      _AdminQueueSubTab.cancelled,
      'Cancelled',
      Icons.cancel_outlined,
      Color(0xFFDC2626),
    ),
  ];

  String get _ordersStatus {
    switch (_sub) {
      case _AdminQueueSubTab.pending:
        return 'pending';
      case _AdminQueueSubTab.active:
        return 'in_production';
      case _AdminQueueSubTab.ready:
        return 'ready';
      case _AdminQueueSubTab.cancelled:
        return 'cancelled';
      case _AdminQueueSubTab.history:
        return 'pending'; // unused when history is active
    }
  }

  @override
  void initState() {
    super.initState();
    _subscribeCount(_AdminQueueSubTab.pending, 'pending');
    _subscribeCount(_AdminQueueSubTab.active, 'in_production');
    _subscribeCount(_AdminQueueSubTab.ready, 'ready');
    _subscribeCount(_AdminQueueSubTab.cancelled, 'cancelled');
  }

  void _subscribeCount(_AdminQueueSubTab tab, String status) {
    final sub = FirebaseFirestore.instance
        .collection('Orders')
        .where('status', isEqualTo: status)
        .snapshots()
        .listen((snap) {
          if (mounted) setState(() => _counts[tab] = snap.size);
        });
    _countSubs.add(sub);
  }

  @override
  void dispose() {
    for (final s in _countSubs) s.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isHistory = _sub == _AdminQueueSubTab.history;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Tab bar + search + history button ────────────────────────
          if (!isHistory)
            LayoutBuilder(
              builder: (ctx, constraints) {
                final w = constraints.maxWidth;
                const searchNatural = 200.0;
                const historyFullW = 94.0;
                const historyIconW = 32.0;
                const gap = 8.0;
                const minPillsGap = 12.0;
                // Full display threshold: search+gap+pills~340+minGap+history
                const compactBreak = 654.0;

                final compact = w < compactBreak;
                final historyW = compact ? historyIconW : historyFullW;
                final leftAvail = (w - gap - historyW - minPillsGap)
                    .clamp(140.0, double.infinity);
                final searchW = searchNatural.clamp(0.0, leftAvail * 0.40);
                final pillsMaxW = (leftAvail - searchW).clamp(60.0, double.infinity);

                final pills = _AdminPillSegmentControl<_AdminQueueSubTab>(
                  selected: _sub,
                  items: _statusTabs
                      .map(
                        (t) => _AdminPillSegmentItem(
                          value: t.$1,
                          label: t.$2,
                          icon: t.$3,
                          accent: t.$4,
                          count: _counts[t.$1],
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    _searchCtrl.clear();
                    setState(() {
                      _sub = v;
                      _searchQuery = '';
                    });
                  },
                );

                return Row(
                  children: [
                    // Search bar
                    SizedBox(
                      width: searchW,
                      height: 34,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _G.surfaceMid,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: _G.borderMid, width: 0.9),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 9),
                            const Icon(Icons.search_rounded, size: 14, color: _G.textMuted),
                            const SizedBox(width: 5),
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                onChanged: (v) => setState(
                                  () => _searchQuery = v.trim().toLowerCase(),
                                ),
                                style: const TextStyle(color: _G.textPrimary, fontSize: 11),
                                decoration: const InputDecoration(
                                  hintText: 'Order ID · Customer Name/ID',
                                  hintStyle: TextStyle(color: _G.textMuted, fontSize: 11),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                                child: const Padding(
                                  padding: EdgeInsets.only(right: 7),
                                  child: Icon(Icons.close_rounded, size: 13, color: _G.textMuted),
                                ),
                              )
                            else
                              const SizedBox(width: 7),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Pills — uncapped on wide, scrollable on narrow
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: pillsMaxW),
                      child: pills,
                    ),
                    SizedBox(width: minPillsGap),
                    const Spacer(),
                    // History button — label on wide, icon-only on narrow
                    GestureDetector(
                      onTap: () => setState(() => _sub = _AdminQueueSubTab.history),
                      child: compact
                          ? Container(
                              width: historyIconW,
                              height: historyIconW,
                              decoration: _G.solidPill(const Color(0xFF8B5CF6)),
                              child: const Icon(Icons.history_rounded, size: 16, color: Colors.white),
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              decoration: _G.solidPill(const Color(0xFF8B5CF6)),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.history_rounded, size: 13, color: Colors.white),
                                  SizedBox(width: 6),
                                  Text(
                                    'History',
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
                );
              },
            ),

          if (!isHistory) const SizedBox(height: 10),

          // ── Content: list or history ──────────────────────────────────
          Expanded(
            child: isHistory
                ? _AdminHistoryView(
                    onBack: () => setState(() => _sub = _AdminQueueSubTab.pending),
                  )
                : _AdminReadOnlyQueueList(
                    ordersStatus: _ordersStatus,
                    searchQuery: _searchQuery,
                  ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _AdminReadOnlyQueueList
// Reads from Orders collection (same as employee), renders read-only cards.
// =============================================================================
class _AdminReadOnlyQueueList extends StatefulWidget {
  final String ordersStatus;
  final String searchQuery;

  const _AdminReadOnlyQueueList({
    required this.ordersStatus,
    required this.searchQuery,
  });

  @override
  State<_AdminReadOnlyQueueList> createState() =>
      _AdminReadOnlyQueueListState();
}

class _AdminReadOnlyQueueListState extends State<_AdminReadOnlyQueueList> {
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Orders')
          .where('status', isEqualTo: widget.ordersStatus)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: _G.navyBlue.withValues(alpha: 0.4),
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

        // Sort oldest-first (same as employee pending/active views)
        final allDocs = [...(snap.data?.docs ?? [])]
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

        final q = widget.searchQuery;
        final docs = q.isEmpty
            ? allDocs
            : allDocs.where((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final id = (d['order_id']?.toString() ?? '').toLowerCase();
                final name = (d['customer_name']?.toString() ?? '').toLowerCase();
                final customerId = (d['customer_id']?.toString() ?? '').toLowerCase();
                return id.contains(q) || name.contains(q) || customerId.contains(q);
              }).toList();

        if (allDocs.isEmpty) {
          final label = widget.ordersStatus == 'in_production'
              ? 'active'
              : widget.ordersStatus;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                  'No $label jobs',
                  style: const TextStyle(
                    color: _G.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Jobs will appear here when assigned this status.',
                  style: TextStyle(color: _G.textMuted, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
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
                    Icons.search_off_rounded,
                    size: 28,
                    color: _G.textMuted,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'No orders match your search',
                  style: TextStyle(
                    color: _G.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        return Scrollbar(
          controller: _scrollCtrl,
          thumbVisibility: true,
          trackVisibility: false,
          child: ListView.separated(
            controller: _scrollCtrl,
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              return _AdminReadOnlyQueueCard(
                position: i + 1,
                orderId: doc.id,
                data: data,
              );
            },
          ),
        );
      },
    );
  }
}

// =============================================================================
// _AdminReadOnlyQueueCard
// Visual clone of employee _QueueCard — no action buttons whatsoever.
// =============================================================================
class _AdminReadOnlyQueueCard extends StatelessWidget {
  final int position;
  final String orderId;
  final Map<String, dynamic> data;
  final bool showDueDate;

  const _AdminReadOnlyQueueCard({
    required this.position,
    required this.orderId,
    required this.data,
    this.showDueDate = true,
  });

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
      return '${m[d.month - 1]} ${d.day}, ${d.year} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '—';
    }
  }

  static Color _statusColor(String s) {
    switch (s) {
      case 'pending':
        return const Color(0xFFD97706);
      case 'in_production':
        return const Color(0xFF2563EB);
      case 'ready':
        return const Color(0xFF16A34A);
      case 'cancelled':
        return _G.accentRose;
      case 'completed':
        return _G.accentViolet;
      default:
        return _G.textMuted;
    }
  }

  static String _statusLabel(String s) {
    switch (s) {
      case 'in_production':
        return 'Active';
      case 'pending':
        return 'Pending';
      case 'ready':
        return 'Ready';
      case 'cancelled':
        return 'Cancelled';
      case 'completed':
        return 'Completed';
      default:
        return s[0].toUpperCase() + s.substring(1);
    }
  }

  // Resolve notes: order-level first, then per-product notes
  static String _resolveNotes(Map<String, dynamic> data) {
    final orderNote = data['notes']?.toString() ?? '';
    if (orderNote.isNotEmpty) return orderNote;
    final prods = (data['products'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    return prods
        .map((p) => p['notes']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .join(' | ');
  }

  @override
  Widget build(BuildContext context) {
    final orderLabel = data['order_id']?.toString() ?? '—';
    final customerName = data['customer_name']?.toString() ?? 'Customer';
    final customerId = data['customer_id']?.toString() ?? '';
    final rawStatus = data['status']?.toString() ?? 'pending';
    final turnaround = data['turnaround_days'] as int?;
    final total = (data['total_price'] as num?)?.toDouble() ?? 0;
    final amountPaid = (data['amount_paid'] as num?)?.toDouble() ?? 0;
    final remaining =
        (data['remaining_balance'] as num?)?.toDouble() ?? (total - amountPaid);
    final fullyPaid = remaining < 0.01;
    final pct = total > 0 ? (amountPaid / total).clamp(0.0, 1.0) : 1.0;
    final refundPickedUp = data['refund_picked_up'] == true;
    final products =
        (data['products'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final dateStr = _fmtDate(data['created_at']);
    final statusColor = _statusColor(rawStatus);
    final statusLbl = _statusLabel(rawStatus);
    final notes = _resolveNotes(data);
    final cancelReason = data['cancel_reason']?.toString() ?? '';

    final DateTime? estimatedCompletion = (() {
      final ts = data['estimated_completion'] as Timestamp?;
      if (ts != null) return ts.toDate().toLocal();
      final created = (data['created_at'] as Timestamp?)?.toDate().toLocal();
      final ta = data['turnaround_days'] as int?;
      if (created == null || ta == null) return null;
      return created.add(Duration(days: ta));
    })();

    final productSummary = products.isEmpty
        ? null
        : products
              .map((p) => '${p['name'] ?? '?'} ×${p['qty'] ?? 1}')
              .join(', ');

    // Shared date+turnaround row widget
    Widget dateRow() => Row(
      children: [
        const Icon(Icons.calendar_today_outlined, size: 11, color: _G.textMuted),
        const SizedBox(width: 4),
        Text(dateStr, style: const TextStyle(color: _G.textMuted, fontSize: 12)),
        if (turnaround != null) ...[
          const SizedBox(width: 6),
          const Icon(Icons.schedule, size: 11, color: _G.textMuted),
          const SizedBox(width: 3),
          Text(
            '~$turnaround day${turnaround == 1 ? '' : 's'}',
            style: const TextStyle(color: _G.textMuted, fontSize: 12),
          ),
        ],
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Position bubble ───────────────────────────────────────────
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _G.accentAmber.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: _G.accentAmber.withValues(alpha: 0.35)),
          ),
          child: Center(
            child: Text(
              '$position',
              style: const TextStyle(
                color: _G.accentAmber,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // ── Card ──────────────────────────────────────────────────────
        Expanded(
          child: _BlurCard(
            radius: 14,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                orderLabel,
                                style: const TextStyle(
                                  color: _G.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              if (data['walk_in'] == true) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _G.accentAmber.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _G.accentAmber.withValues(alpha: 0.40),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: const Text(
                                    'Walk-in',
                                    style: TextStyle(
                                      color: _G.accentAmber,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            customerName,
                            style: const TextStyle(
                              color: _G.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          if (customerId.isNotEmpty) ...[
                            const SizedBox(height: 1),
                            Text(
                              'Customer ID: $customerId',
                              style: const TextStyle(
                                color: _G.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
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
                        statusLbl,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),

                // ── Products ────────────────────────────────────────────
                if (productSummary != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    productSummary,
                    style: const TextStyle(
                      color: _G.textSecondary,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  DesignFilesSection(products: products),
                ],

                // ── Special instructions ─────────────────────────────────
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.notes_outlined,
                      size: 12,
                      color: _G.textMuted,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Special Instructions: ${notes.isNotEmpty ? notes : 'None'}',
                        style: const TextStyle(
                          color: _G.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),

                // ── Estimated completion (queue only, non-cancelled) ──────
                if (showDueDate &&
                    estimatedCompletion != null &&
                    rawStatus != 'cancelled') ...[
                  const SizedBox(height: 6),
                  _AdminDueDateRow(dueDate: estimatedCompletion),
                ],

                // ── Ready: info chips + payment progress bar ─────────────
                if (rawStatus == 'ready') ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _AdminInfoChip(
                        'Total',
                        '₱${total.toStringAsFixed(2)}',
                        _G.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      _AdminInfoChip(
                        'Paid',
                        '₱${amountPaid.toStringAsFixed(2)}',
                        _G.accentEmerald,
                      ),
                      const SizedBox(width: 10),
                      _AdminInfoChip(
                        fullyPaid ? 'Fully Paid' : 'Balance Due',
                        fullyPaid ? '—' : '₱${remaining.toStringAsFixed(2)}',
                        fullyPaid ? _G.accentEmerald : _G.accentAmber,
                        bold: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: _G.borderDim,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        fullyPaid ? _G.accentEmerald : _G.accentAmber,
                      ),
                      minHeight: 5,
                    ),
                  ),
                ],

                // ── Divider ──────────────────────────────────────────────
                const SizedBox(height: 6),
                Divider(height: 0.8, color: _G.borderDim),
                const SizedBox(height: 8),

                // ── HISTORY layout (showDueDate == false) ────────────────
                if (!showDueDate) ...[
                  // Fit-to-content cancel reason (same style as queue cancelled)
                  if (cancelReason.isNotEmpty && rawStatus == 'cancelled') ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: _G.accentRose.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _G.accentRose.withValues(alpha: 0.22),
                              width: 0.9,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 12,
                                color: _G.accentRose,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  'Reason: $cancelReason',
                                  style: const TextStyle(
                                    color: _G.accentRose,
                                    fontSize: 11,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Info chips + invoice
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            _AdminInfoChip(
                              'Total',
                              '₱${total.toStringAsFixed(2)}',
                              _G.textSecondary,
                            ),
                            const SizedBox(width: 10),
                            _AdminInfoChip(
                              'Paid',
                              '₱${amountPaid.toStringAsFixed(2)}',
                              _G.accentEmerald,
                            ),
                            const SizedBox(width: 10),
                            _AdminInfoChip(
                              fullyPaid ? 'Fully Paid' : 'Balance',
                              fullyPaid
                                  ? '—'
                                  : '₱${remaining.toStringAsFixed(2)}',
                              fullyPaid ? _G.accentEmerald : _G.accentAmber,
                              bold: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _InvoiceButton(orderId: orderId),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Date + turnaround at very bottom
                  dateRow(),
                ]

                // ── QUEUE layout (showDueDate == true) ───────────────────
                else if (rawStatus == 'cancelled') ...[
                  // Row 1: fit-to-content cancel reason (left) + amounts (right)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: cancelReason.isNotEmpty
                              ? ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 260),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _G.accentRose.withValues(
                                        alpha: 0.06,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _G.accentRose.withValues(
                                          alpha: 0.22,
                                        ),
                                        width: 0.9,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.info_outline,
                                          size: 12,
                                          color: _G.accentRose,
                                        ),
                                        const SizedBox(width: 5),
                                        Flexible(
                                          child: Text(
                                            'Reason: $cancelReason',
                                            style: const TextStyle(
                                              color: _G.accentRose,
                                              fontSize: 11,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '₱${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: _G.accentAmber,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (amountPaid > 0)
                            Text(
                              'Paid: ₱${amountPaid.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: _G.accentEmerald,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Row 2: date + turnaround + invoice
                  Row(
                    children: [
                      dateRow(),
                      const Spacer(),
                      _InvoiceButton(orderId: orderId),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Refund pickup status (view-only)
                  if (refundPickedUp)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _G.accentEmerald.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _G.accentEmerald.withValues(alpha: 0.30),
                          width: 0.9,
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: _G.accentEmerald,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Refund picked up by customer',
                              style: TextStyle(
                                color: _G.accentEmerald,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (amountPaid > 0.01)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _G.accentAmber.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _G.accentAmber.withValues(alpha: 0.30),
                          width: 0.9,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.monetization_on_outlined,
                            size: 14,
                            color: _G.accentAmber,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Refund to be picked up — ₱${amountPaid.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: _G.accentAmber,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ] else if (rawStatus == 'ready') ...[
                  // Ready footer: date+turnaround + invoice (amounts shown above in chips)
                  Row(
                    children: [
                      dateRow(),
                      const Spacer(),
                      _InvoiceButton(orderId: orderId),
                    ],
                  ),
                ] else ...[
                  // Pending / Active footer
                  // Row 1: total (top) stacked above paid (bottom), right-aligned
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '₱${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: _G.accentAmber,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (amountPaid > 0)
                            Text(
                              'Paid: ₱${amountPaid.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: _G.accentEmerald,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Row 2: date+turnaround bottom-left · invoice bottom-right
                  Row(
                    children: [
                      dateRow(),
                      const Spacer(),
                      _InvoiceButton(orderId: orderId),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// _AdminInfoChip — label + value stacked, mirrors employee _InfoChip
// =============================================================================
class _AdminInfoChip extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool bold;

  const _AdminInfoChip(this.label, this.value, this.color,
      {this.bold = false});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: _G.textMuted,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: bold ? 13 : 11,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    ],
  );
}

// =============================================================================
// _InvoiceButton — tappable invoice launcher used inside queue cards
// =============================================================================
class _InvoiceButton extends StatelessWidget {
  final String orderId;
  const _InvoiceButton({required this.orderId});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final snap = await FirebaseFirestore.instance
            .collection('Orders')
            .doc(orderId)
            .get();
        final invId = snap.data()?['invoice_id']?.toString();
        if (!context.mounted) return;
        if (invId != null && invId.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => InvoiceScreen(invoiceId: invId)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No invoice for this order')),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: _G.glass(radius: 99),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_rounded, size: 15, color: _G.textSecondary),
            SizedBox(width: 6),
            Text(
              'View Invoice',
              style: TextStyle(
                color: _G.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _AdminDueDateRow — same logic as employee _DueDateRow, no dependencies
// =============================================================================
class _AdminDueDateRow extends StatelessWidget {
  final DateTime dueDate;
  const _AdminDueDateRow({required this.dueDate});

  static String _fmt(DateTime d) {
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
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final diff = due.difference(today).inDays;

    final Color color;
    final String label;

    if (diff < 0) {
      color = _G.accentRose;
      label =
          'Overdue by ${-diff} day${diff == -1 ? '' : 's'} — ${_fmt(dueDate)}';
    } else if (diff == 0) {
      color = _G.accentRose;
      label = 'Target completion: TODAY';
    } else if (diff == 1) {
      color = _G.accentAmber;
      label = 'Target completion: Tomorrow (${_fmt(dueDate)})';
    } else {
      color = _G.accentEmerald;
      label = 'Target completion: ${_fmt(dueDate)}';
    }

    return Row(
      children: [
        Icon(
          Icons.flag_rounded,
          size: 14,
          color: color.withValues(alpha: 0.85),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: diff <= 0 ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// _AdminPillSegmentItem / _AdminPillSegmentControl
// Self-contained copies so no cross-file dependency on employee widgets.
// =============================================================================
class _AdminPillSegmentItem<T> {
  final T value;
  final String label;
  final IconData icon;
  final Color accent;
  final int? count;

  const _AdminPillSegmentItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.accent,
    this.count,
  });
}

class _AdminPillSegmentControl<T> extends StatelessWidget {
  final T selected;
  final List<_AdminPillSegmentItem<T>> items;
  final ValueChanged<T> onChanged;

  const _AdminPillSegmentControl({
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
                    if (item.count != null && item.count! > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.white.withValues(alpha: 0.28)
                              : item.accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          item.count! > 99 ? '99+' : '${item.count}',
                          style: TextStyle(
                            color: isActive ? Colors.white : item.accent,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
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
// _AdminHistoryView — read-only order history for admin job queue tab
// =============================================================================
class _AdminHistoryView extends StatefulWidget {
  final VoidCallback? onBack;
  const _AdminHistoryView({this.onBack});

  @override
  State<_AdminHistoryView> createState() => _AdminHistoryViewState();
}

class _AdminHistoryViewState extends State<_AdminHistoryView> {
  String _statusFilter = 'all';
  String _search = '';
  final _searchCtrl = TextEditingController();
  String? _resolvedCustomerName;
  bool _isResolvingId = false;

  static const _statusOpts = [
    ('all', 'All'),
    ('pending', 'Pending'),
    ('active', 'Active'),
    ('ready', 'Ready'),
    ('completed', 'Completed'),
    ('cancelled', 'Cancelled'),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _resolveCustomerId(String term) async {
    if (!mounted) return;
    setState(() { _isResolvingId = true; _resolvedCustomerName = null; });
    try {
      final db = FirebaseFirestore.instance;
      QuerySnapshot<Map<String, dynamic>>? snap = await db
          .collection('User')
          .where('customer_id', isEqualTo: term)
          .limit(1)
          .get()
          .catchError((_) => null);
      if (snap == null || snap.docs.isEmpty) {
        final all = await db.collection('User').limit(300).get().catchError((_) => null);
        if (all != null) {
          final lower = term.toLowerCase();
          for (final doc in all.docs) {
            final cid = (doc.data()['customer_id'] as String? ?? '').toLowerCase();
            if (cid == lower) {
              final name = doc.data()['full_name'] as String?;
              if (mounted) setState(() { _resolvedCustomerName = name?.toLowerCase(); _isResolvingId = false; });
              return;
            }
          }
        }
      }
      final name = snap?.docs.isNotEmpty == true ? snap!.docs.first.data()['full_name'] as String? : null;
      if (mounted) setState(() { _resolvedCustomerName = (name?.isNotEmpty == true) ? name!.toLowerCase() : null; _isResolvingId = false; });
    } catch (_) {
      if (mounted) setState(() => _isResolvingId = false);
    }
  }

  void _onSearchChanged(String raw) {
    final term = raw.trim().toLowerCase();
    setState(() { _search = term; _resolvedCustomerName = null; });
    if (term.isEmpty) return;
    _resolveCustomerId(term);
  }

  Stream<List<QueryDocumentSnapshot>> _stream() {
    Query q = FirebaseFirestore.instance.collection('Orders');
    if (_statusFilter == 'all') {
      q = q.where('status', whereIn: ['pending', 'in_production', 'ready', 'completed', 'cancelled']);
    } else if (_statusFilter == 'active') {
      q = q.where('status', isEqualTo: 'in_production');
    } else if (_statusFilter == 'ready') {
      q = q.where('status', isEqualTo: 'ready');
    } else {
      q = q.where('status', isEqualTo: _statusFilter);
    }
    return q.snapshots().map((snap) {
      final docs = [...snap.docs]..sort((a, b) {
        final ta = (a.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
        final tb = (b.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });
      return docs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back button
        if (widget.onBack != null) ...[
          GestureDetector(
            onTap: widget.onBack,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _G.surfaceThin,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: _G.borderMid, width: 0.9),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_ios_new_rounded, size: 12, color: _G.textSecondary),
                  SizedBox(width: 6),
                  Text('Order History', style: TextStyle(color: _G.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        // Status filter pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: _statusOpts.map((opt) {
              final active = _statusFilter == opt.$1;
              return GestureDetector(
                onTap: () => setState(() => _statusFilter = opt.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: active
                      ? _G.solidPill(_G.navyBlue, glow: true)
                      : BoxDecoration(
                          color: _G.surfaceThin,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: _G.borderMid, width: 0.9),
                        ),
                  child: Text(
                    opt.$2,
                    style: TextStyle(
                      color: active ? Colors.white : _G.textSecondary,
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        // Search field
        Container(
          decoration: BoxDecoration(
            color: _G.surfaceThin,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _G.borderMid, width: 0.8),
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            style: const TextStyle(color: _G.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search by order ID, customer name, or customer ID…',
              hintStyle: const TextStyle(color: _G.textMuted, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: _G.textMuted, size: 18),
              suffixIcon: _search.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        setState(() { _search = ''; _resolvedCustomerName = null; _isResolvingId = false; });
                      },
                      child: _isResolvingId
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _G.textSecondary)),
                            )
                          : const Icon(Icons.clear, color: _G.textMuted, size: 18),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<List<QueryDocumentSnapshot>>(
            stream: _stream(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                return Center(child: CircularProgressIndicator(color: _G.navyBlue.withValues(alpha: 0.4), strokeWidth: 2));
              }
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}', style: const TextStyle(color: _G.accentRose, fontSize: 12)));
              }
              var docs = snap.data ?? [];
              if (_search.isNotEmpty) {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final id = (data['order_id']?.toString() ?? d.id).toLowerCase();
                  final name = (data['customer_name']?.toString() ?? '').toLowerCase();
                  final cid = (data['customer_id']?.toString() ?? '').toLowerCase();
                  if (id.contains(_search) || name.contains(_search) || cid.contains(_search)) return true;
                  if (_resolvedCustomerName != null && name.contains(_resolvedCustomerName!)) return true;
                  return false;
                }).toList();
              }
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 64, height: 64, decoration: _G.glass(radius: 20, elevated: true),
                          child: const Icon(Icons.history, size: 28, color: _G.textMuted)),
                      const SizedBox(height: 14),
                      const Text('No orders found', style: TextStyle(color: _G.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final doc = docs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AdminReadOnlyQueueCard(
                      position: i + 1,
                      orderId: doc.id,
                      data: data,
                      showDueDate: false,
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

// =============================================================================
// Sales Record Sub-Tab (unchanged)
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
// Employee Activity — sub-tabs: Inventory | Job Queue | POS
// =============================================================================
enum _EmpActSubTab { inventory, jobQueue, pos }

class _InventoryLogsTab extends StatefulWidget {
  const _InventoryLogsTab();

  @override
  State<_InventoryLogsTab> createState() => _InventoryLogsTabState();
}

class _InventoryLogsTabState extends State<_InventoryLogsTab> {
  _EmpActSubTab _subTab = _EmpActSubTab.inventory;

  // Inventory filters
  String _employeeFilter = '';
  String _materialFilter = '';
  final _empCtrl = TextEditingController();
  final _matCtrl = TextEditingController();

  // Job Queue filter
  String _jqFilter = '';
  final _jqCtrl = TextEditingController();

  // POS filter
  String _posFilter = '';
  final _posCtrl = TextEditingController();

  static final _dateFmt = DateFormat('MMM dd, yyyy hh:mm a');

  @override
  void dispose() {
    _empCtrl.dispose();
    _matCtrl.dispose();
    _jqCtrl.dispose();
    _posCtrl.dispose();
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

  static const _hStyle = TextStyle(
    color: _G.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
  );

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (_subTab) {
      _EmpActSubTab.inventory => 'Inventory stock updates (manual & QR only)',
      _EmpActSubTab.jobQueue => 'Job queue status changes by employees',
      _EmpActSubTab.pos => 'POS payment transactions by employees',
    };

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Employee Activity',
                      style: TextStyle(
                        color: _G.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: _G.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (_subTab == _EmpActSubTab.inventory)
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
          const SizedBox(height: 12),

          // ── Sub-tab pills ───────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _EmpActTabPill(
                  label: 'Inventory',
                  icon: Icons.inventory_2_outlined,
                  isActive: _subTab == _EmpActSubTab.inventory,
                  onTap: () => setState(() => _subTab = _EmpActSubTab.inventory),
                ),
                const SizedBox(width: 8),
                _EmpActTabPill(
                  label: 'Job Queue',
                  icon: Icons.queue_outlined,
                  isActive: _subTab == _EmpActSubTab.jobQueue,
                  onTap: () => setState(() => _subTab = _EmpActSubTab.jobQueue),
                ),
                const SizedBox(width: 8),
                _EmpActTabPill(
                  label: 'POS',
                  icon: Icons.point_of_sale_outlined,
                  isActive: _subTab == _EmpActSubTab.pos,
                  onTap: () => setState(() => _subTab = _EmpActSubTab.pos),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Content ─────────────────────────────────────────────────────
          Expanded(
            child: switch (_subTab) {
              _EmpActSubTab.inventory => _buildInventoryContent(),
              _EmpActSubTab.jobQueue => _buildJobQueueContent(),
              _EmpActSubTab.pos => _buildPosContent(),
            },
          ),
        ],
      ),
    );
  }

  // ── Inventory sub-tab ─────────────────────────────────────────────────────
  Widget _buildInventoryContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                    child: const Icon(Icons.clear, color: _G.textMuted, size: 16),
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
                child: Text('Added', style: _hStyle, textAlign: TextAlign.right),
              ),
              SizedBox(
                width: 70,
                child: Text('New Stock', style: _hStyle, textAlign: TextAlign.right),
              ),
              SizedBox(
                width: 56,
                child: Text('Method', style: _hStyle, textAlign: TextAlign.center),
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
              final filtered = docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final method = data['update_method']?.toString() ?? 'manual';
                // Only manual and qr_scan — exclude order_deduction and admin_edit
                if (method != 'manual' && method != 'qr_scan') return false;
                final emp =
                    data['updated_by_name']?.toString().toLowerCase() ?? '';
                final empId =
                    data['updated_by_display_id']?.toString().toLowerCase() ?? '';
                final mat =
                    data['material_name']?.toString().toLowerCase() ?? '';
                return (_employeeFilter.isEmpty ||
                        emp.contains(_employeeFilter) ||
                        empId.contains(_employeeFilter)) &&
                    (_materialFilter.isEmpty || mat.contains(_materialFilter));
              }).toList();

              if (filtered.isEmpty) {
                return _emptyState(
                  icon: Icons.history_toggle_off,
                  title: docs.isEmpty
                      ? 'No activity logs yet'
                      : 'No logs matching your filter',
                  subtitle: docs.isEmpty
                      ? 'Logs appear when employees replenish stock'
                      : null,
                );
              }
              return Scrollbar(
                thumbVisibility: true,
                trackVisibility: false,
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final data = filtered[i].data() as Map<String, dynamic>;
                    return _LogRow(data: data, dateFmt: _dateFmt);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Job Queue sub-tab ─────────────────────────────────────────────────────
  Widget _buildJobQueueContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _jqCtrl,
                style: const TextStyle(color: _G.textPrimary, fontSize: 13),
                onChanged: (v) => setState(() => _jqFilter = v.toLowerCase()),
                decoration: _G.field(
                  'Filter by employee',
                  icon: Icons.person_search_outlined,
                ),
              ),
            ),
            if (_jqFilter.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: GestureDetector(
                  onTap: () {
                    _jqCtrl.clear();
                    setState(() => _jqFilter = '');
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: _G.glass(radius: 12),
                    child: const Icon(Icons.clear, color: _G.textMuted, size: 16),
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
              Expanded(flex: 3, child: Text('Order / Customer', style: _hStyle)),
              Expanded(flex: 3, child: Text('Action', style: _hStyle)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('JobQueueActivityLogs')
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
              if (snapshot.hasError) {
                return _emptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load logs',
                  subtitle: snapshot.error.toString(),
                );
              }
              final docs = snapshot.data?.docs ?? [];
              final filtered = docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final emp =
                    data['employee_name']?.toString().toLowerCase() ?? '';
                final empId =
                    data['employee_display_id']?.toString().toLowerCase() ?? '';
                return _jqFilter.isEmpty ||
                    emp.contains(_jqFilter) ||
                    empId.contains(_jqFilter);
              }).toList();

              if (filtered.isEmpty) {
                return _emptyState(
                  icon: Icons.queue_outlined,
                  title: docs.isEmpty
                      ? 'No job queue activity yet'
                      : 'No logs matching your filter',
                  subtitle: docs.isEmpty
                      ? 'Logs appear when employees update job statuses'
                      : null,
                );
              }
              return Scrollbar(
                thumbVisibility: true,
                trackVisibility: false,
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final data = filtered[i].data() as Map<String, dynamic>;
                    return _JobQueueActivityRow(data: data, dateFmt: _dateFmt);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── POS sub-tab ───────────────────────────────────────────────────────────
  Widget _buildPosContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _posCtrl,
                style: const TextStyle(color: _G.textPrimary, fontSize: 13),
                onChanged: (v) => setState(() => _posFilter = v.toLowerCase()),
                decoration: _G.field(
                  'Filter by employee',
                  icon: Icons.person_search_outlined,
                ),
              ),
            ),
            if (_posFilter.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: GestureDetector(
                  onTap: () {
                    _posCtrl.clear();
                    setState(() => _posFilter = '');
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: _G.glass(radius: 12),
                    child: const Icon(Icons.clear, color: _G.textMuted, size: 16),
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
              Expanded(flex: 3, child: Text('Order / Customer', style: _hStyle)),
              SizedBox(
                width: 100,
                child: Text('Amount', style: _hStyle, textAlign: TextAlign.right),
              ),
              SizedBox(
                width: 90,
                child: Text('Type', style: _hStyle, textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('PosActivityLogs')
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
              if (snapshot.hasError) {
                return _emptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load logs',
                  subtitle: snapshot.error.toString(),
                );
              }
              final docs = snapshot.data?.docs ?? [];
              final filtered = docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final emp =
                    data['employee_name']?.toString().toLowerCase() ?? '';
                final empId =
                    data['employee_display_id']?.toString().toLowerCase() ?? '';
                return _posFilter.isEmpty ||
                    emp.contains(_posFilter) ||
                    empId.contains(_posFilter);
              }).toList();

              if (filtered.isEmpty) {
                return _emptyState(
                  icon: Icons.point_of_sale_outlined,
                  title: docs.isEmpty
                      ? 'No POS activity yet'
                      : 'No logs matching your filter',
                  subtitle: docs.isEmpty
                      ? 'Logs appear when employees process payments'
                      : null,
                );
              }
              return Scrollbar(
                thumbVisibility: true,
                trackVisibility: false,
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final data = filtered[i].data() as Map<String, dynamic>;
                    return _PosActivityRow(data: data, dateFmt: _dateFmt);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: _G.glass(radius: 22),
            child: Icon(icon, size: 32, color: _G.textMuted),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              color: _G.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: _G.textSecondary, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// _EmpActTabPill — pill button for Employee Activity sub-tabs
// =============================================================================
class _EmpActTabPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _EmpActTabPill({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accent = _G.navyBlue;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: isActive
            ? BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(99),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.30),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              )
            : BoxDecoration(
                color: _G.surfaceThin,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: _G.borderMid, width: 0.9),
              ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: isActive ? Colors.white : _G.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : _G.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _JobQueueActivityRow — one row in the Job Queue activity log
// =============================================================================
class _JobQueueActivityRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final DateFormat dateFmt;

  const _JobQueueActivityRow({required this.data, required this.dateFmt});

  static String _actionLabel(String action) {
    switch (action) {
      case 'started':
        return 'Started Production';
      case 'marked_ready':
        return 'Marked Ready';
      case 'cancelled':
        return 'Cancelled';
      case 'completed':
        return 'Completed';
      case 'refund_confirmed':
        return 'Refund Confirmed';
      default:
        return action;
    }
  }

  static Color _actionColor(String action) {
    switch (action) {
      case 'started':
        return const Color(0xFF2563EB);
      case 'marked_ready':
        return const Color(0xFF16A34A);
      case 'cancelled':
        return _G.accentRose;
      case 'completed':
        return _G.accentViolet;
      case 'refund_confirmed':
        return _G.accentEmerald;
      default:
        return _G.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = data['timestamp'] as Timestamp?;
    final timeStr = ts != null ? dateFmt.format(ts.toDate()) : '—';
    final empName = data['employee_name']?.toString() ?? '—';
    final empId = data['employee_display_id']?.toString() ?? '';
    final orderId = data['order_id']?.toString() ?? '—';
    final custName = data['customer_name']?.toString() ?? '';
    final custId = data['customer_id']?.toString() ?? '';
    final action = data['action']?.toString() ?? '';
    final cancelReason = data['cancel_reason']?.toString() ?? '';
    final amountRefunded = (data['amount_refunded'] as num?)?.toDouble();
    final actionColor = _actionColor(action);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _G.surfaceThin,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _G.borderDim, width: 0.9),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                timeStr,
                style: const TextStyle(color: _G.textMuted, fontSize: 11),
              ),
            ),
          ),
          // Employee
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  empName,
                  style: const TextStyle(
                    color: _G.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (empId.isNotEmpty)
                  Text(
                    empId,
                    style: const TextStyle(
                      color: _G.textMuted,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
              ],
            ),
          ),
          // Order / Customer
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  orderId,
                  style: const TextStyle(
                    color: _G.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (custName.isNotEmpty)
                  Text(
                    custName,
                    style: const TextStyle(color: _G.textSecondary, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (custId.isNotEmpty)
                  Text(
                    custId,
                    style: const TextStyle(
                      color: _G.textMuted,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
              ],
            ),
          ),
          // Action
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: actionColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: actionColor.withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      _actionLabel(action),
                      style: TextStyle(
                        color: actionColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (cancelReason.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      'Reason: $cancelReason',
                      style: const TextStyle(color: _G.accentRose, fontSize: 10),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (amountRefunded != null && amountRefunded > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '₱${amountRefunded.toStringAsFixed(2)} refunded',
                      style: const TextStyle(color: _G.accentEmerald, fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _PosActivityRow — one row in the POS activity log
// =============================================================================
class _PosActivityRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final DateFormat dateFmt;

  const _PosActivityRow({required this.data, required this.dateFmt});

  static String _typeLabel(String t) {
    switch (t) {
      case 'full':
        return 'Full';
      case 'downpayment':
        return 'Downpayment';
      case 'balance':
        return 'Balance';
      default:
        return t;
    }
  }

  static Color _typeColor(String t) {
    switch (t) {
      case 'full':
        return _G.accentEmerald;
      case 'downpayment':
        return _G.accentAmber;
      case 'balance':
        return _G.accentViolet;
      default:
        return _G.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = data['timestamp'] as Timestamp?;
    final timeStr = ts != null ? dateFmt.format(ts.toDate()) : '—';
    final empName = data['employee_name']?.toString() ?? '—';
    final empId = data['employee_display_id']?.toString() ?? '';
    final orderId = data['order_id']?.toString() ?? '—';
    final custName = data['customer_name']?.toString() ?? '';
    final custId = data['customer_id']?.toString() ?? '';
    final amount = (data['amount_paid'] as num?)?.toDouble() ?? 0;
    final payType = data['payment_type']?.toString() ?? '';
    final typeColor = _typeColor(payType);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _G.surfaceThin,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _G.borderDim, width: 0.9),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                timeStr,
                style: const TextStyle(color: _G.textMuted, fontSize: 11),
              ),
            ),
          ),
          // Employee
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  empName,
                  style: const TextStyle(
                    color: _G.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (empId.isNotEmpty)
                  Text(
                    empId,
                    style: const TextStyle(
                      color: _G.textMuted,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
              ],
            ),
          ),
          // Order / Customer
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  orderId,
                  style: const TextStyle(
                    color: _G.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (custName.isNotEmpty)
                  Text(
                    custName,
                    style: const TextStyle(color: _G.textSecondary, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (custId.isNotEmpty)
                  Text(
                    custId,
                    style: const TextStyle(
                      color: _G.textMuted,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
              ],
            ),
          ),
          // Amount
          SizedBox(
            width: 100,
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                '₱${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: _G.accentAmber,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),
          // Type pill
          SizedBox(
            width: 90,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: typeColor.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  _typeLabel(payType),
                  style: TextStyle(
                    color: typeColor,
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
// Customer Feedback Tab (unchanged)
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
                child: Scrollbar(
                  thumbVisibility: true,
                  trackVisibility: true,
                  child: ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final data = docs[i].data() as Map<String, dynamic>;
                      final customer = data['customer_name']?.toString() ?? '—';
                      final message = data['message']?.toString() ?? '';
                      final rating = (data['rating'] as num?)?.toInt();
                      final orderId = data['order_id']?.toString() ?? '';
                      final productName =
                          data['product_name']?.toString() ?? '';
                      final ts = data['created_at'] as Timestamp?;
                      final timeStr = ts != null
                          ? DateFormat(
                              'MMM dd, yyyy hh:mm a',
                            ).format(ts.toDate())
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
                                      color: _G.navyBlue.withValues(
                                        alpha: 0.08,
                                      ),
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
                                          borderRadius: BorderRadius.circular(
                                            99,
                                          ),
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
              ),
            ],
          );
        },
      ),
    );
  }
}

// =============================================================================
// Log Row (unchanged)
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
    final employeeDisplayId = data['updated_by_display_id']?.toString() ?? '';
    final employeeUid = data['updated_by_uid']?.toString() ?? '';
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOrderDeduction
                      ? (orderId.isNotEmpty ? orderId : employee)
                      : employee,
                  style: TextStyle(
                    color: isOrderDeduction ? _G.accentViolet : _G.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isOrderDeduction)
                  Builder(builder: (_) {
                    final id = employeeDisplayId.isNotEmpty
                        ? employeeDisplayId
                        : (employeeUid.length > 10
                            ? '${employeeUid.substring(0, 10)}…'
                            : employeeUid);
                    return id.isEmpty
                        ? const SizedBox.shrink()
                        : Text(
                            id,
                            style: const TextStyle(
                              color: _G.textMuted,
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          );
                  }),
              ],
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
// Customer ID resolver widget (unchanged)
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

// =============================================================================
// _AdminOrderHistory — kept for reference but no longer used in the Job Queue
// tab (admin now uses the read-only widget instead). It's still reachable
// from other parts of the admin panel if needed.
// =============================================================================
class AdminOrderHistory extends StatefulWidget {
  final VoidCallback? onBack;
  const AdminOrderHistory({super.key, this.onBack});

  @override
  State<AdminOrderHistory> createState() => _AdminOrderHistoryState();
}

class _AdminOrderHistoryState extends State<AdminOrderHistory> {
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
        if (widget.onBack != null) ...[
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
          const SizedBox(height: 10),
        ],
        Row(
          children: [
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
                    child: Scrollbar(
                      thumbVisibility: true,
                      trackVisibility: false,
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
                          final customerId =
                              data['customer_id']?.toString() ?? '';
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
                            customerId: customerId,
                            dateStr: dateStr,
                            statusLabel: _statusLabel(status),
                            statusColor: _statusColor(status),
                            products: products,
                            paid: paid,
                            total: total,
                            remaining: remaining,
                            invoiceId: invoiceId,
                            cancelReason:
                                data['cancel_reason']?.toString() ?? '',
                            notes: data['notes']?.toString() ?? '',
                          );
                        },
                      ),
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
  final String customerId;
  final String dateStr;
  final String statusLabel;
  final Color statusColor;
  final List<Map<String, dynamic>> products;
  final double paid;
  final double total;
  final double remaining;
  final String? invoiceId;
  final String cancelReason;
  final String notes;

  const _OrderHistoryCard({
    required this.docId,
    required this.orderId,
    required this.customer,
    this.customerId = '',
    required this.dateStr,
    required this.statusLabel,
    required this.statusColor,
    required this.products,
    required this.paid,
    required this.total,
    required this.remaining,
    this.invoiceId,
    this.cancelReason = '',
    this.notes = '',
  });

  @override
  Widget build(BuildContext context) {
    final fullyPaid = remaining < 0.01;

    return _BlurCard(
      radius: 14,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
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
                    if (customerId.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        'ID: $customerId',
                        style: const TextStyle(
                          color: _G.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
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
            const SizedBox(height: 8),
            DesignFilesSection(products: products),
          ],

          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.notes_outlined, size: 12, color: _G.textMuted),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Special Instructions: ${notes.isNotEmpty ? notes : 'None'}',
                  style: const TextStyle(color: _G.textMuted, fontSize: 11),
                ),
              ),
            ],
          ),

          if (cancelReason.isNotEmpty && statusLabel == 'Cancelled') ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _G.accentRose.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _G.accentRose.withValues(alpha: 0.22),
                  width: 0.9,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.cancel_outlined,
                    size: 12,
                    color: _G.accentRose,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Cancelled: $cancelReason',
                      style: const TextStyle(
                        color: _G.accentRose,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Divider(height: 0.8, color: _G.borderDim),
          const SizedBox(height: 10),

          LayoutBuilder(
            builder: (_, constraints) {
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
      mainAxisSize: MainAxisSize.min,
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
