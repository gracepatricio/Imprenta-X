import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/file_utils.dart' as file_utils;
import 'app_theme.dart';
import 'sales_widgets.dart';
import 'invoice_screen.dart';
import 'design_file_viewer.dart';

// ── Print Document / PDF report constants (Job Queue) ───────────────────────
// Mirrors the business info block in invoice_screen.dart for visual
// consistency between the invoice PDF and the Job Queue report PDF.
const _jqBizName    = 'IMPRENTA INC.';
const _jqBizTagline = 'Professional Printing Services';
const _jqBizAddr1   = '5th Street Pacita Avenue, Office 1 Rongavilla Building';
const _jqBizAddr2   = 'San Pedro, Laguna, 4023, Philippines';
const _jqBizTin     = '010-253-357-000';

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
      // ValueKey ensures a fresh State (and correct initial tab) each time
      // the dashboard navigates here with a specific status.
        return AdminReadOnlyJobQueueTab(
          key: ValueKey(widget.initialJobStatus ?? 'pending'),
          initialStatus: widget.initialJobStatus,
        );
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
  const AdminReadOnlyJobQueueTab({super.key, this.initialStatus});
  /// Firestore status string from the dashboard ('pending', 'active', 'ready',
  /// 'cancelled', 'in_production'). Determines the pre-selected queue tab.
  final String? initialStatus;

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
    // Jump to the tab the admin clicked on the dashboard.
    _sub = _subFromStatus(widget.initialStatus);
    _subscribeCount(_AdminQueueSubTab.pending, 'pending');
    _subscribeCount(_AdminQueueSubTab.active, 'in_production');
    _subscribeCount(_AdminQueueSubTab.ready, 'ready');
    _subscribeCount(_AdminQueueSubTab.cancelled, 'cancelled');
  }

  static _AdminQueueSubTab _subFromStatus(String? s) {
    switch (s) {
      case 'active':
      case 'in_production':
        return _AdminQueueSubTab.active;
      case 'ready':
        return _AdminQueueSubTab.ready;
      case 'cancelled':
      case 'uncollected':
        return _AdminQueueSubTab.cancelled;
      case 'pending':
      default:
        return _AdminQueueSubTab.pending;
    }
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

  // ── Print Document (Job Queue Orders Report) ────────────────────────────
  Future<void> _openPrintDialog() async {
    final selection = await showDialog<_JobQueuePrintSelection>(
      context: context,
      builder: (_) => const _JobQueuePrintDialog(),
    );
    if (selection == null || selection.orders.isEmpty) return;
    if (!mounted) return;
    await _downloadJobQueuePdf(selection);
  }

  Future<void> _downloadJobQueuePdf(_JobQueuePrintSelection selection) async {
    try {
      final bytes = await _buildJobQueuePdf(selection);
      final now = DateTime.now();
      final stamp = '${now.year}${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}';
      final filename = 'job_queue_orders_report_$stamp.pdf';

      if (kIsWeb) {
        await file_utils.downloadBytes(bytes, 'application/pdf', filename);
      } else {
        await Printing.sharePdf(bytes: bytes, filename: filename);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate report: $e')),
      );
    }
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
                const printFullW = 128.0;
                const printIconW = 32.0;
                const gap = 8.0;
                const minPillsGap = 12.0;
                // Full display threshold: search+gap+pills~340+minGap+history+print
                const compactBreak = 780.0;

                final compact = w < compactBreak;
                final historyW = compact ? historyIconW : historyFullW;
                final printW = compact ? printIconW : printFullW;
                final leftAvail = (w - gap - historyW - gap - printW - minPillsGap)
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
                    // Print Document button — opens the order-selection dialog
                    GestureDetector(
                      onTap: _openPrintDialog,
                      child: compact
                          ? Container(
                        width: printIconW,
                        height: printIconW,
                        decoration: _G.solidPill(_G.navyBlue),
                        child: const Icon(Icons.print_rounded, size: 16, color: Colors.white),
                      )
                          : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: _G.solidPill(_G.navyBlue),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.print_rounded, size: 13, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'Export Document',
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
                    const SizedBox(width: gap),
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
// Job Queue "Print Document" — order selection dialog + PDF report builder
// =============================================================================

class _JobQueuePrintSelection {
  final List<Map<String, dynamic>> orders; // each includes a '_docId' key
  final String label;
  const _JobQueuePrintSelection({required this.orders, required this.label});
}

String _fmtPrintDate(DateTime d) {
  const mo = ['Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${mo[d.month - 1]} ${d.day}, ${d.year}';
}

String _fmtPrintDateRange(DateTimeRange r) {
  final startDay = DateTime(r.start.year, r.start.month, r.start.day);
  final endDay = DateTime(r.end.year, r.end.month, r.end.day);
  if (startDay == endDay) return _fmtPrintDate(startDay);
  return '${_fmtPrintDate(startDay)} – ${_fmtPrintDate(endDay)}';
}

// Job-queue statuses selectable for the "specific job queue" filter — mirrors
// the Firestore status values used by the on-screen queue tabs.
const _jobQueueStatusOptions = [
  ('pending', 'Pending'),
  ('in_production', 'Active'),
  ('ready', 'Ready'),
  ('cancelled', 'Cancelled'),
  ('completed', 'Completed'),
];

class _JobQueuePrintDialog extends StatefulWidget {
  const _JobQueuePrintDialog();

  @override
  State<_JobQueuePrintDialog> createState() => _JobQueuePrintDialogState();
}

class _JobQueuePrintDialogState extends State<_JobQueuePrintDialog> {
  DateTimeRange? _range;
  String? _statusFilter; // null = All Job Queues
  bool _generating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    _range = DateTimeRange(start: day, end: day); // defaults to today only
  }

  Future<_JobQueuePrintSelection?> _buildSelection() async {
    final range = _range;
    if (range == null) {
      setState(() => _error = 'Please select a date range.');
      return null;
    }
    setState(() { _generating = true; _error = null; });
    try {
      final dayStart = DateTime(range.start.year, range.start.month, range.start.day);
      final dayEnd = DateTime(range.end.year, range.end.month, range.end.day)
          .add(const Duration(days: 1));
      // Range filter on created_at only — status is filtered client-side so
      // this never needs a composite Firestore index.
      final snap = await FirebaseFirestore.instance
          .collection('Orders')
          .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
          .where('created_at', isLessThan: Timestamp.fromDate(dayEnd))
          .get();
      var docs = [...snap.docs];
      final statusFilter = _statusFilter;
      if (statusFilter != null) {
        docs = docs.where((d) =>
        (d.data() as Map<String, dynamic>)['status']?.toString() == statusFilter).toList();
      }
      docs.sort((a, b) {
        final ta = (a.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
        final tb = (b.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return ta.compareTo(tb);
      });
      final orders = docs
          .map((d) => {...d.data() as Map<String, dynamic>, '_docId': d.id})
          .toList();
      final scopeLabel = statusFilter == null
          ? 'All Job Queues'
          : _jobQueueStatusOptions
          .firstWhere((s) => s.$1 == statusFilter, orElse: () => ('', statusFilter))
          .$2;
      return _JobQueuePrintSelection(
        orders: orders,
        label: '$scopeLabel · ${_fmtPrintDateRange(range)}',
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _confirm() async {
    final selection = await _buildSelection();
    if (selection == null) return;
    if (selection.orders.isEmpty) {
      setState(() => _error = 'No orders match this selection.');
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(selection);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── Header ────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: const BoxDecoration(
              color: _G.navyBlue,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              const Icon(Icons.print_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Expanded(child: Text('Print Job Queue Orders Report',
                  style: TextStyle(color: Colors.white, fontSize: 14,
                      fontWeight: FontWeight.w700))),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
              ),
            ]),
          ),

          // ── Filters ──────────────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Date range',
                    style: TextStyle(color: _G.textSecondary, fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DateFilterButton(
                  selectedRange: _range,
                  onChanged: (r) => setState(() { _range = r; _error = null; }),
                ),
                const SizedBox(height: 18),

                const Text('Job queue',
                    style: TextStyle(color: _G.textSecondary, fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _JobQueueScopeChip(
                    label: 'All Job Queues',
                    active: _statusFilter == null,
                    onTap: () => setState(() { _statusFilter = null; _error = null; }),
                  ),
                  for (final opt in _jobQueueStatusOptions)
                    _JobQueueScopeChip(
                      label: opt.$2,
                      active: _statusFilter == opt.$1,
                      onTap: () => setState(() { _statusFilter = opt.$1; _error = null; }),
                    ),
                ]),

                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!, style: const TextStyle(color: _G.accentRose, fontSize: 12)),
                ],
              ]),
            ),
          ),

          // ── Actions ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _G.borderSolid)),
            ),
            child: Row(children: [
              const Spacer(),
              TextButton(
                onPressed: _generating ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                onPressed: _generating ? null : _confirm,
                icon: _generating
                    ? const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Icon(Icons.print_rounded, size: 16),
                label: Text(_generating ? 'Preparing…' : 'Generate Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _G.navyBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _JobQueueScopeChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _JobQueueScopeChip({
    required this.label, required this.active, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? _G.navyBlue.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
            color: active ? _G.navyBlue : _G.borderSolid,
            width: active ? 1.3 : 0.9),
      ),
      child: Text(label, style: TextStyle(
          color: active ? _G.navyBlue : _G.textSecondary,
          fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
    ),
  );
}

// Shared radio-style option tile — reused by the Employee Activity and
// Feedback print dialogs elsewhere in this file.
class _PrintModeOption extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool active;
  final VoidCallback onTap;
  const _PrintModeOption({
    required this.icon, required this.title, required this.subtitle,
    required this.active, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active ? _G.navyBlue.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: active ? _G.navyBlue : _G.borderSolid,
            width: active ? 1.3 : 0.9),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: active ? _G.navyBlue : _G.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(
                color: active ? _G.navyBlue : _G.textPrimary,
                fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: _G.textMuted, fontSize: 10.5)),
          ]),
        ),
        Icon(active ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 18, color: active ? _G.navyBlue : _G.textMuted),
      ]),
    ),
  );
}

// ── PDF builder — Job Queue Orders Report ────────────────────────────────────
// Structure, fonts, header styling, and table layout mirror invoice_screen.dart
// (and the forecast report in employee_inventory_forecast_screen.dart) for a
// consistent look across all generated PDFs.
Future<Uint8List> _buildJobQueuePdf(_JobQueuePrintSelection selection) async {
  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold    = await PdfGoogleFonts.notoSansBold();
  final italic  = await PdfGoogleFonts.notoSansItalic();

  final doc = pw.Document();
  final now = DateTime.now();

  // Sort oldest-first, consistent with the on-screen queue.
  final orders = [...selection.orders]..sort((a, b) {
    final ta = a['created_at'] as Timestamp?;
    final tb = b['created_at'] as Timestamp?;
    if (ta == null && tb == null) return 0;
    if (ta == null) return 1;
    if (tb == null) return -1;
    return ta.compareTo(tb);
  });

  // ── Colours (mirrors invoice_screen.dart palette) ─────────────────────────
  const navy      = PdfColor.fromInt(0xFF0F1A2E);
  const gold      = PdfColor.fromInt(0xFFE8B84B);
  const white     = PdfColors.white;
  const textDark  = PdfColor.fromInt(0xFF0F172A);
  const textMid   = PdfColor.fromInt(0xFF475569);
  const textLight = PdfColor.fromInt(0xFF94A3B8);
  const rowAlt    = PdfColor.fromInt(0xFFF8FAFC);
  const rowBorder = PdfColor.fromInt(0xFFE2E8F0);
  const accentBg  = PdfColor.fromInt(0xFFF0F9FF);

  pw.TextStyle s(pw.Font f, double sz, PdfColor c) =>
      pw.TextStyle(font: f, fontSize: sz, color: c);

  String fmtDate(dynamic ts) {
    if (ts == null) return '—';
    try {
      final d = (ts as Timestamp).toDate().toLocal();
      const mo = ['Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${mo[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) {
      return '—';
    }
  }

  String fmtDateGenerated(DateTime d) {
    const mo = ['Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '${mo[d.month - 1]} ${d.day}, ${d.year} · '
        '$h12:${d.minute.toString().padLeft(2, '0')} $ampm';
  }

  String php(double v) => '₱ ${AppTheme.fmtAmt(v)}';

  PdfColor statusPdfColor(String st) {
    switch (st) {
      case 'pending':       return const PdfColor.fromInt(0xFFD97706);
      case 'in_production': return const PdfColor.fromInt(0xFF2563EB);
      case 'ready':         return const PdfColor.fromInt(0xFF16A34A);
      case 'uncollected':   return const PdfColor.fromInt(0xFFB45309);
      case 'cancelled':     return const PdfColor.fromInt(0xFFDC2626);
      case 'completed':     return const PdfColor.fromInt(0xFF8B5CF6);
      default:              return textMid;
    }
  }

  String statusLabel(String st) {
    switch (st) {
      case 'in_production': return 'Active';
      case 'pending':        return 'Pending';
      case 'ready':          return 'Ready';
      case 'uncollected':    return 'Uncollected';
      case 'cancelled':      return 'Cancelled';
      case 'completed':      return 'Completed';
      default: return st.isEmpty ? '—' : st[0].toUpperCase() + st.substring(1);
    }
  }

  int countStatus(String st) =>
      orders.where((o) => (o['status']?.toString() ?? '') == st).length;
  final grandTotal = orders.fold<double>(
      0, (sum, o) => sum + ((o['total_price'] as num?)?.toDouble() ?? 0));
  final grandRemaining = orders.fold<double>(0, (sum, o) {
    final total = (o['total_price'] as num?)?.toDouble() ?? 0;
    final paid = (o['amount_paid'] as num?)?.toDouble() ?? 0;
    return sum + ((o['remaining_balance'] as num?)?.toDouble() ?? (total - paid));
  });

  pw.Widget summaryChip(String label, int count, PdfColor color) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        margin: const pw.EdgeInsets.only(right: 6, bottom: 4),
        decoration: pw.BoxDecoration(
          color: white,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(9)),
          border: pw.Border.all(color: color, width: 0.7),
        ),
        child: pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
          pw.Container(width: 9, height: 9, decoration: pw.BoxDecoration(
              color: color, shape: pw.BoxShape.circle)),
          pw.SizedBox(width: 4),
          pw.Text('$count', style: s(bold, 8, textDark)),
          pw.SizedBox(width: 2),
          pw.Text(label, style: s(regular, 7, textMid)),
        ]),
      );

  pw.Widget pdfMeta(String label, String value, PdfColor valueColor) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.end,
    children: [
      pw.Text('$label  ', style: pw.TextStyle(font: regular, fontSize: 8.5,
          color: const PdfColor.fromInt(0xFF64748B))),
      pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 8.5, color: valueColor)),
    ],
  );

  // ── Table rows ───────────────────────────────────────────────────────────
  final headers = ['#', 'ORDER ID', 'CUSTOMER', 'STATUS', 'DATE CREATED', 'ITEMS', 'TOTAL', 'REMAINING'];

  // Bounds the ITEMS cell so a single order can never produce a row taller
  // than a page. An unbounded join of every product name (orders with many
  // items, or long item names) was the real cause of TooManyPagesException —
  // the table engine loops trying to fit an oversized row on a fresh page
  // and never succeeds, eventually hitting the page cap.
  String _shorten(String text, [int maxLen = 28]) =>
      text.length > maxLen ? '${text.substring(0, maxLen)}…' : text;

  String _summarizeItems(List<Map<String, dynamic>> products) {
    if (products.isEmpty) return '—';
    const maxShown = 3;
    final shown = products.take(maxShown).map((p) {
      final name = _shorten((p['name'] ?? '?').toString());
      return '$name ×${p['qty'] ?? 1}';
    }).join(', ');
    final extra = products.length > maxShown ? '  +${products.length - maxShown} more' : '';
    return '$shown$extra';
  }

  final rows = orders.asMap().entries.map((e) {
    final i = e.key;
    final o = e.value;
    final products = (o['products'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final itemsSummary = _summarizeItems(products);
    final total = (o['total_price'] as num?)?.toDouble() ?? 0;
    final paid = (o['amount_paid'] as num?)?.toDouble() ?? 0;
    final remaining = (o['remaining_balance'] as num?)?.toDouble() ?? (total - paid);
    return [
      '${i + 1}',
      _shorten(o['order_id']?.toString() ?? o['_docId']?.toString() ?? '—', 16),
      _shorten(o['customer_name']?.toString() ?? 'Customer', 22),
      _shorten(statusLabel(o['status']?.toString() ?? 'pending'), 14),
      fmtDate(o['created_at']),
      itemsSummary,
      php(total),
      remaining > 0.004 ? php(remaining) : '—',
    ];
  }).toList();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      // Default cap is 20 pages — kept generous even though selections are now
      // bounded to 100 orders, in case a wide "specific date" range is large.
      maxPages: 3000,
      header: (ctx) => ctx.pageNumber == 1
          ? pw.SizedBox()
          : pw.Container(
        width: double.infinity,
        color: navy,
        padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 10),
        child: pw.Text('$_jqBizName  ·  Job Queue Orders Report',
            style: s(bold, 9, gold)),
      ),
      footer: (ctx) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 10),
        decoration: const pw.BoxDecoration(color: rowAlt),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('$_jqBizName  ·  TIN: $_jqBizTin', style: s(bold, 7.5, textMid)),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: s(regular, 7.5, textLight)),
          ],
        ),
      ),
      build: (ctx) => [
        // ── Header band (first page only, included once in flow) ────────────
        pw.Container(
          width: double.infinity,
          color: navy,
          padding: const pw.EdgeInsets.fromLTRB(36, 26, 36, 22),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(_jqBizName, style: pw.TextStyle(
                        font: bold, fontSize: 22, color: gold, letterSpacing: 1.5)),
                    pw.SizedBox(height: 3),
                    pw.Text(_jqBizTagline, style: s(regular, 9, textLight)),
                    pw.SizedBox(height: 9),
                    pw.Container(height: 1, width: 160,
                        color: const PdfColor.fromInt(0xFF334155)),
                    pw.SizedBox(height: 9),
                    pw.Text(_jqBizAddr1, style: s(regular, 8.5,
                        const PdfColor.fromInt(0xFFCBD5E1))),
                    pw.Text(_jqBizAddr2, style: s(regular, 8.5,
                        const PdfColor.fromInt(0xFFCBD5E1))),
                    pw.SizedBox(height: 5),
                    pw.Text('TIN: $_jqBizTin', style: s(regular, 8.5,
                        const PdfColor.fromInt(0xFFCBD5E1))),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('JOB QUEUE ORDERS REPORT', style: pw.TextStyle(
                      font: bold, fontSize: 17, color: gold, letterSpacing: 1.1)),
                  pw.SizedBox(height: 10),
                  pdfMeta('Date Generated', fmtDateGenerated(now), white),
                  pw.SizedBox(height: 4),
                  pdfMeta('Generated By', 'Admin', const PdfColor.fromInt(0xFFCBD5E1)),
                  pw.SizedBox(height: 4),
                  pdfMeta('Report Scope', selection.label, const PdfColor.fromInt(0xFFCBD5E1)),
                ],
              ),
            ],
          ),
        ),

        // ── Summary strip ────────────────────────────────────────────────
        pw.Container(
          width: double.infinity,
          color: accentBg,
          padding: const pw.EdgeInsets.fromLTRB(36, 10, 36, 10),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('SUMMARY OF INCLUDED ORDERS', style: s(bold, 7.5, textLight)),
              pw.SizedBox(height: 6),
              pw.Wrap(spacing: 0, runSpacing: 0, children: [
                summaryChip('Total Orders', orders.length, navy),
                summaryChip('Pending', countStatus('pending'), statusPdfColor('pending')),
                summaryChip('Active', countStatus('in_production'), statusPdfColor('in_production')),
                summaryChip('Ready', countStatus('ready'), statusPdfColor('ready')),
                summaryChip('Cancelled', countStatus('cancelled'), statusPdfColor('cancelled')),
                summaryChip('Completed', countStatus('completed'), statusPdfColor('completed')),
              ]),
              pw.SizedBox(height: 8),
              pw.Text('Combined Order Value: ${php(grandTotal)}', style: s(bold, 9, textDark)),
              if (grandRemaining > 0.004) ...[
                pw.SizedBox(height: 2),
                pw.Text('Combined Remaining Balance: ${php(grandRemaining)}',
                    style: s(bold, 9, const PdfColor.fromInt(0xFFDC2626))),
              ],
            ],
          ),
        ),

        pw.SizedBox(height: 18),

        // ── Orders table ──────────────────────────────────────────────────
        // Kept as a single, unwrapped top-level item (no preceding "ORDERS"
        // heading nested in a Column above it). Nesting the table inside a
        // Column with a sibling heading was causing the whole table to defer
        // to the next page even when plenty of room remained on this one —
        // MultiPage only treats direct build-list items as independently
        // splittable, so the Table needs to be one on its own.
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 36),
          child: orders.isEmpty
              ? pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 20),
            child: pw.Text('No orders match this selection.',
                style: s(italic, 9, textMid)),
          )
              : pw.Table(
            border: null,
            columnWidths: const {
              0: pw.FixedColumnWidth(28),
              1: pw.FlexColumnWidth(1.5),
              2: pw.FlexColumnWidth(1.7),
              3: pw.FlexColumnWidth(1.0),
              4: pw.FlexColumnWidth(1.3),
              5: pw.FlexColumnWidth(2.3),
              6: pw.FlexColumnWidth(1.1),
              7: pw.FlexColumnWidth(1.2),
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: navy),
                children: headers.asMap().entries.map((h) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                    child: pw.Align(
                      alignment: (h.key == 6 || h.key == 7) ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
                      child: pw.Text(h.value,
                          style: pw.TextStyle(font: bold, fontSize: 7.5, color: gold),
                          maxLines: 1,
                          overflow: pw.TextOverflow.clip),
                    ),
                  );
                }).toList(),
              ),
              // Data rows — every cell is capped to a fixed number of
              // lines, so no single row can ever exceed a bounded height
              // (this is what was still causing TooManyPagesException).
              ...rows.asMap().entries.map((r) {
                final isAlt = r.key.isOdd;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: isAlt ? rowAlt : null,
                    border: const pw.Border(
                        bottom: pw.BorderSide(color: rowBorder, width: 0.5)),
                  ),
                  children: r.value.asMap().entries.map((c) {
                    final isItemsCol = c.key == 5;
                    final isTotalCol = c.key == 6 || c.key == 7;
                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      child: pw.Align(
                        alignment: isTotalCol ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
                        child: pw.Text(c.value,
                            style: pw.TextStyle(font: regular, fontSize: 8, color: textDark),
                            maxLines: isItemsCol ? 2 : 1,
                            overflow: pw.TextOverflow.clip),
                      ),
                    );
                  }).toList(),
                );
              }),
            ],
          ),
        ),
      ],
    ),
  );

  return Uint8List.fromList(await doc.save());
}

// =============================================================================
// Generic bounded-height report table (Employee Activity / Customer Feedback)
// Every cell is capped to a fixed number of lines so no row can ever exceed a
// page — see the Job Queue report above for the original TooManyPagesException
// bug this pattern was built to prevent.
// =============================================================================
pw.Widget _reportTable({
  required List<String> headers,
  required List<List<String>> data,
  required Map<int, pw.TableColumnWidth> columnWidths,
  required pw.Font regular,
  required pw.Font bold,
  required PdfColor navy,
  required PdfColor gold,
  required PdfColor textDark,
  required PdfColor rowAlt,
  required PdfColor rowBorder,
  Set<int> rightAlign = const {},
  Set<int> wrapTwoLines = const {},
}) {
  return pw.Table(
    border: null,
    columnWidths: columnWidths,
    children: [
      pw.TableRow(
        decoration: pw.BoxDecoration(color: navy),
        children: headers.asMap().entries.map((h) {
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
            child: pw.Align(
              alignment: rightAlign.contains(h.key) ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
              child: pw.Text(h.value,
                  style: pw.TextStyle(font: bold, fontSize: 7.5, color: gold),
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip),
            ),
          );
        }).toList(),
      ),
      ...data.asMap().entries.map((r) {
        final isAlt = r.key.isOdd;
        return pw.TableRow(
          decoration: pw.BoxDecoration(
            color: isAlt ? rowAlt : null,
            border: pw.Border(bottom: pw.BorderSide(color: rowBorder, width: 0.5)),
          ),
          children: r.value.asMap().entries.map((c) {
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: pw.Align(
                alignment: rightAlign.contains(c.key) ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
                child: pw.Text(c.value,
                    style: pw.TextStyle(font: regular, fontSize: 7.5, color: textDark),
                    maxLines: wrapTwoLines.contains(c.key) ? 2 : 1,
                    overflow: pw.TextOverflow.clip),
              ),
            );
          }).toList(),
        );
      }),
    ],
  );
}

String _reportShorten(String text, [int maxLen = 24]) =>
    text.length > maxLen ? '${text.substring(0, maxLen)}…' : text;

String _reportFmtDate(Timestamp? ts) {
  if (ts == null) return '—';
  final d = ts.toDate().toLocal();
  const mo = ['Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${mo[d.month - 1]} ${d.day}, ${d.year}';
}

String _reportFmtTime(Timestamp? ts) {
  if (ts == null) return '—';
  final d = ts.toDate().toLocal();
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ampm = d.hour >= 12 ? 'PM' : 'AM';
  return '$h12:${d.minute.toString().padLeft(2, '0')} $ampm';
}

String _reportFmtDateGenerated(DateTime d) {
  const mo = ['Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'];
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ampm = d.hour >= 12 ? 'PM' : 'AM';
  return '${mo[d.month - 1]} ${d.day}, ${d.year} · '
      '$h12:${d.minute.toString().padLeft(2, '0')} $ampm';
}

// Small reusable choice-tile used by the Employee Activity print dialog's
// category picker.
class _CategoryChoiceChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _CategoryChoiceChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: active ? _G.navyBlue : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: active ? _G.navyBlue : _G.borderSolid),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: active ? Colors.white : _G.textMuted),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(
            color: active ? Colors.white : _G.textPrimary,
            fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}

// =============================================================================
// Employee Activity Report — "Print Document"
// This feature (and Customer Feedback Report below) is only reachable from
// admin_logs_screen.dart, which is admin-only, so no extra role check is
// needed — consistent with the Job Queue and Sales print features above.
// =============================================================================

enum _ActivityCategory { inventory, jobQueue, pos }

enum _ActPrintMode { allCategories, specificCategory, specificDate, specificEmployeeDate }

class _EmployeeActivityPrintRequest {
  final _ActPrintMode mode;
  final _ActivityCategory category;
  final DateTime? date;
  final String employeeQuery;
  const _EmployeeActivityPrintRequest({
    required this.mode,
    required this.category,
    required this.date,
    required this.employeeQuery,
  });
}

class _ActivityReportRow {
  final String employeeName;
  final String employeeId;
  final String category; // 'Inventory' | 'Job Queue' | 'POS'
  final String description;
  final String module;
  final Timestamp? ts;
  const _ActivityReportRow({
    required this.employeeName,
    required this.employeeId,
    required this.category,
    required this.description,
    required this.module,
    required this.ts,
  });
}

String _actReportJqActionLabel(String action) {
  switch (action) {
    case 'started': return 'Started Production';
    case 'marked_ready': return 'Marked Ready';
    case 'cancelled': return 'Cancelled';
    case 'completed': return 'Completed';
    case 'refund_confirmed': return 'Refund Confirmed';
    default: return action.isEmpty ? 'Updated' : action;
  }
}

String _actReportInvMethodLabel(String method) {
  switch (method) {
    case 'qr_scan': return 'QR Scan';
    case 'admin_edit': return 'Admin Edit';
    case 'order_deduction': return 'Order Deduction';
    default: return 'Manual';
  }
}

String _actReportPosTypeLabel(String t) {
  switch (t) {
    case 'full': return 'Full Payment';
    case 'downpayment': return 'Downpayment';
    case 'balance': return 'Balance Payment';
    default: return t.isEmpty ? 'Payment' : t;
  }
}

_ActivityReportRow _rowFromInventoryDoc(Map<String, dynamic> d) {
  final material = d['material_name']?.toString() ?? 'Material';
  final qty = (d['quantity_added'] as num?) ?? 0;
  final newStock = (d['new_stock'] as num?) ?? 0;
  final method = d['update_method']?.toString() ?? 'manual';
  final qtyNum = qty.toDouble();
  final qtyStr = qtyNum == qtyNum.truncateToDouble()
      ? qtyNum.toInt().toString()
      : qtyNum.toStringAsFixed(2);
  final sign = qtyNum > 0 ? '+' : '';
  return _ActivityReportRow(
    employeeName: d['updated_by_name']?.toString() ?? '—',
    employeeId: d['updated_by_display_id']?.toString() ?? '—',
    category: 'Inventory',
    description: '$material $sign$qtyStr (new stock: $newStock) — ${_actReportInvMethodLabel(method)}',
    module: 'Inventory',
    ts: d['timestamp'] as Timestamp?,
  );
}

_ActivityReportRow _rowFromJobQueueDoc(Map<String, dynamic> d) {
  final action = d['action']?.toString() ?? '';
  final orderId = d['order_id']?.toString() ?? '—';
  return _ActivityReportRow(
    employeeName: d['employee_name']?.toString() ?? '—',
    employeeId: d['employee_display_id']?.toString() ?? '—',
    category: 'Job Queue',
    description: '${_actReportJqActionLabel(action)} — Order $orderId',
    module: 'Job Queue',
    ts: d['timestamp'] as Timestamp?,
  );
}

_ActivityReportRow _rowFromPosDoc(Map<String, dynamic> d) {
  final type = d['payment_type']?.toString() ?? '';
  final orderId = d['order_id']?.toString() ?? '—';
  final amount = (d['amount_paid'] as num?)?.toDouble() ?? 0;
  return _ActivityReportRow(
    employeeName: d['employee_name']?.toString() ?? '—',
    employeeId: d['employee_display_id']?.toString() ?? '—',
    category: 'POS',
    description: '${_actReportPosTypeLabel(type)} of ₱${AppTheme.fmtAmt(amount)} — Order $orderId',
    module: 'POS',
    ts: d['timestamp'] as Timestamp?,
  );
}

class _EmployeeActivityPrintDialog extends StatefulWidget {
  const _EmployeeActivityPrintDialog();

  @override
  State<_EmployeeActivityPrintDialog> createState() => _EmployeeActivityPrintDialogState();
}

class _EmployeeActivityPrintDialogState extends State<_EmployeeActivityPrintDialog> {
  _ActPrintMode _mode = _ActPrintMode.allCategories;
  _ActivityCategory _category = _ActivityCategory.inventory;
  DateTime? _date;
  final _empCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _empCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() { _date = picked; _error = null; });
  }

  void _confirm() {
    final needsDate = _mode == _ActPrintMode.specificDate || _mode == _ActPrintMode.specificEmployeeDate;
    if (needsDate && _date == null) {
      setState(() => _error = 'Please select a date.');
      return;
    }
    if (_mode == _ActPrintMode.specificEmployeeDate && _empCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter an employee name or ID.');
      return;
    }
    Navigator.of(context).pop(_EmployeeActivityPrintRequest(
      mode: _mode,
      category: _category,
      date: _date,
      employeeQuery: _empCtrl.text.trim().toLowerCase(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: const BoxDecoration(
              color: _G.navyBlue,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              const Icon(Icons.print_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Expanded(child: Text('Print Employee Activity Report',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
              ),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Choose what to include in the report:',
                    style: TextStyle(color: _G.textSecondary, fontSize: 12)),
                const SizedBox(height: 10),

                _PrintModeOption(
                  icon: Icons.all_inclusive_rounded,
                  title: 'All activity categories',
                  subtitle: 'Includes Inventory, Job Queue, and POS activity together.',
                  active: _mode == _ActPrintMode.allCategories,
                  onTap: () => setState(() { _mode = _ActPrintMode.allCategories; _error = null; }),
                ),
                const SizedBox(height: 8),
                _PrintModeOption(
                  icon: Icons.category_outlined,
                  title: 'Specific activity category',
                  subtitle: 'Includes only Inventory, POS, or Job Queue activity.',
                  active: _mode == _ActPrintMode.specificCategory,
                  onTap: () => setState(() { _mode = _ActPrintMode.specificCategory; _error = null; }),
                ),
                const SizedBox(height: 8),
                _PrintModeOption(
                  icon: Icons.event_rounded,
                  title: 'Specific date',
                  subtitle: 'Includes all activity (any category) from the chosen date.',
                  active: _mode == _ActPrintMode.specificDate,
                  onTap: () => setState(() { _mode = _ActPrintMode.specificDate; _error = null; }),
                ),
                const SizedBox(height: 8),
                _PrintModeOption(
                  icon: Icons.person_search_rounded,
                  title: 'Specific employee on a date',
                  subtitle: "Includes one employee's activity (any category) on the chosen date.",
                  active: _mode == _ActPrintMode.specificEmployeeDate,
                  onTap: () => setState(() { _mode = _ActPrintMode.specificEmployeeDate; _error = null; }),
                ),

                if (_mode == _ActPrintMode.specificCategory) ...[
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: _CategoryChoiceChip(
                      label: 'Inventory', icon: Icons.inventory_2_outlined,
                      active: _category == _ActivityCategory.inventory,
                      onTap: () => setState(() => _category = _ActivityCategory.inventory),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _CategoryChoiceChip(
                      label: 'POS', icon: Icons.point_of_sale_outlined,
                      active: _category == _ActivityCategory.pos,
                      onTap: () => setState(() => _category = _ActivityCategory.pos),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _CategoryChoiceChip(
                      label: 'Job Queue', icon: Icons.queue_outlined,
                      active: _category == _ActivityCategory.jobQueue,
                      onTap: () => setState(() => _category = _ActivityCategory.jobQueue),
                    )),
                  ]),
                ],

                if (_mode == _ActPrintMode.specificDate || _mode == _ActPrintMode.specificEmployeeDate) ...[
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _G.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _G.borderSolid),
                      ),
                      child: Row(children: [
                        const Icon(Icons.calendar_today_outlined, size: 15, color: _G.navyBlue),
                        const SizedBox(width: 8),
                        Text(
                          _date == null ? 'Select a date' : _fmtPrintDate(_date!),
                          style: TextStyle(
                              color: _date == null ? _G.textMuted : _G.textPrimary,
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        const Icon(Icons.expand_more_rounded, size: 16, color: _G.textMuted),
                      ]),
                    ),
                  ),
                ],

                if (_mode == _ActPrintMode.specificEmployeeDate) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _empCtrl,
                    style: const TextStyle(color: _G.textPrimary, fontSize: 13),
                    decoration: _G.field('Employee name or ID', icon: Icons.person_outline_rounded),
                  ),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: _G.accentRose, fontSize: 12)),
                ],
              ]),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _G.borderSolid)),
            ),
            child: Row(children: [
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                onPressed: _confirm,
                icon: const Icon(Icons.print_rounded, size: 16),
                label: const Text('Generate Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _G.navyBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

Future<void> _generateEmployeeActivityReport(
    BuildContext context, _EmployeeActivityPrintRequest req) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(content: Text('Preparing activity report…'), duration: Duration(seconds: 2)),
  );

  try {
    final db = FirebaseFirestore.instance;
    final rows = <_ActivityReportRow>[];

    Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchRange(String collection) async {
      Query<Map<String, dynamic>> q = db.collection(collection);
      if (req.date != null) {
        final dayStart = DateTime(req.date!.year, req.date!.month, req.date!.day);
        final dayEnd = dayStart.add(const Duration(days: 1));
        q = q
            .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
            .where('timestamp', isLessThan: Timestamp.fromDate(dayEnd));
      }
      final snap = await q.get();
      return snap.docs;
    }

    bool matchesEmployee(Map<String, dynamic> d,
        {required String nameField, required String idField}) {
      if (req.employeeQuery.isEmpty) return true;
      final name = (d[nameField]?.toString() ?? '').toLowerCase();
      final id = (d[idField]?.toString() ?? '').toLowerCase();
      return name.contains(req.employeeQuery) || id.contains(req.employeeQuery);
    }

    String scopeLabel;

    Future<void> addInventoryRows({bool Function(Map<String, dynamic>)? filter}) async {
      for (final doc in await fetchRange('InventoryLogs')) {
        final d = doc.data();
        final method = d['update_method']?.toString() ?? 'manual';
        if (method != 'manual' && method != 'qr_scan') continue;
        if (filter != null && !filter(d)) continue;
        rows.add(_rowFromInventoryDoc(d));
      }
    }

    Future<void> addJobQueueRows({bool Function(Map<String, dynamic>)? filter}) async {
      for (final doc in await fetchRange('JobQueueActivityLogs')) {
        final d = doc.data();
        if (filter != null && !filter(d)) continue;
        rows.add(_rowFromJobQueueDoc(d));
      }
    }

    Future<void> addPosRows({bool Function(Map<String, dynamic>)? filter}) async {
      for (final doc in await fetchRange('PosActivityLogs')) {
        final d = doc.data();
        if (filter != null && !filter(d)) continue;
        rows.add(_rowFromPosDoc(d));
      }
    }

    switch (req.mode) {
      case _ActPrintMode.allCategories:
        await addInventoryRows();
        await addJobQueueRows();
        await addPosRows();
        scopeLabel = 'All Activity Categories';
        break;

      case _ActPrintMode.specificCategory:
        switch (req.category) {
          case _ActivityCategory.inventory:
            await addInventoryRows();
            break;
          case _ActivityCategory.jobQueue:
            await addJobQueueRows();
            break;
          case _ActivityCategory.pos:
            await addPosRows();
            break;
        }
        final catLabel = switch (req.category) {
          _ActivityCategory.inventory => 'Inventory',
          _ActivityCategory.jobQueue => 'Job Queue',
          _ActivityCategory.pos => 'POS',
        };
        scopeLabel = 'Category: $catLabel';
        break;

      case _ActPrintMode.specificDate:
        await addInventoryRows();
        await addJobQueueRows();
        await addPosRows();
        scopeLabel = 'Date: ${_fmtPrintDate(req.date!)}';
        break;

      case _ActPrintMode.specificEmployeeDate:
        await addInventoryRows(filter: (d) =>
            matchesEmployee(d, nameField: 'updated_by_name', idField: 'updated_by_display_id'));
        await addJobQueueRows(filter: (d) =>
            matchesEmployee(d, nameField: 'employee_name', idField: 'employee_display_id'));
        await addPosRows(filter: (d) =>
            matchesEmployee(d, nameField: 'employee_name', idField: 'employee_display_id'));
        scopeLabel = 'Employee "${req.employeeQuery}" on ${_fmtPrintDate(req.date!)}';
        break;
    }

    rows.sort((a, b) {
      if (a.ts == null && b.ts == null) return 0;
      if (a.ts == null) return 1;
      if (b.ts == null) return -1;
      return b.ts!.compareTo(a.ts!);
    });

    final bytes = await _buildEmployeeActivityPdf(rows: rows, scopeLabel: scopeLabel);

    final now = DateTime.now();
    final stamp = '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
    final filename = 'employee_activity_report_$stamp.pdf';

    if (kIsWeb) {
      await file_utils.downloadBytes(bytes, 'application/pdf', filename);
    } else {
      await Printing.sharePdf(bytes: bytes, filename: filename);
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to generate report: $e')),
    );
  }
}

Future<Uint8List> _buildEmployeeActivityPdf({
  required List<_ActivityReportRow> rows,
  required String scopeLabel,
}) async {
  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold    = await PdfGoogleFonts.notoSansBold();
  final italic  = await PdfGoogleFonts.notoSansItalic();

  final doc = pw.Document();
  final now = DateTime.now();

  const navy      = PdfColor.fromInt(0xFF0F1A2E);
  const gold      = PdfColor.fromInt(0xFFE8B84B);
  const white     = PdfColors.white;
  const textDark  = PdfColor.fromInt(0xFF0F172A);
  const textMid   = PdfColor.fromInt(0xFF475569);
  const textLight = PdfColor.fromInt(0xFF94A3B8);
  const rowAlt    = PdfColor.fromInt(0xFFF8FAFC);
  const rowBorder = PdfColor.fromInt(0xFFE2E8F0);
  const accentBg  = PdfColor.fromInt(0xFFF0F9FF);

  pw.TextStyle s(pw.Font f, double sz, PdfColor c) => pw.TextStyle(font: f, fontSize: sz, color: c);

  pw.Widget pdfMeta(String label, String value, PdfColor valueColor) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.end,
    children: [
      pw.Text('$label  ', style: pw.TextStyle(font: regular, fontSize: 8.5,
          color: const PdfColor.fromInt(0xFF64748B))),
      pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 8.5, color: valueColor)),
    ],
  );

  pw.Widget summaryChip(String label, int count, PdfColor color) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    margin: const pw.EdgeInsets.only(right: 6, bottom: 4),
    decoration: pw.BoxDecoration(
      color: white,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(9)),
      border: pw.Border.all(color: color, width: 0.7),
    ),
    child: pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
      pw.Container(width: 9, height: 9, decoration: pw.BoxDecoration(
          color: color, shape: pw.BoxShape.circle)),
      pw.SizedBox(width: 4),
      pw.Text('$count', style: s(bold, 8, textDark)),
      pw.SizedBox(width: 2),
      pw.Text(label, style: s(regular, 7, textMid)),
    ]),
  );

  final invCount = rows.where((r) => r.category == 'Inventory').length;
  final jqCount  = rows.where((r) => r.category == 'Job Queue').length;
  final posCount = rows.where((r) => r.category == 'POS').length;

  final headers = ['#', 'EMPLOYEE', 'EMPLOYEE ID', 'CATEGORY', 'DESCRIPTION', 'DATE', 'TIME', 'MODULE'];
  final tableRows = rows.asMap().entries.map((e) {
    final i = e.key;
    final r = e.value;
    return [
      '${i + 1}',
      _reportShorten(r.employeeName, 20),
      _reportShorten(r.employeeId, 14),
      r.category,
      _reportShorten(r.description, 60),
      _reportFmtDate(r.ts),
      _reportFmtTime(r.ts),
      r.module,
    ];
  }).toList();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: pw.EdgeInsets.zero,
      maxPages: 5000,
      header: (ctx) => ctx.pageNumber == 1
          ? pw.SizedBox()
          : pw.Container(
        width: double.infinity,
        color: navy,
        padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 10),
        child: pw.Text('$_jqBizName  ·  Employee Activity Report', style: s(bold, 9, gold)),
      ),
      footer: (ctx) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 10),
        decoration: const pw.BoxDecoration(color: rowAlt),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('$_jqBizName  ·  TIN: $_jqBizTin', style: s(bold, 7.5, textMid)),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: s(regular, 7.5, textLight)),
          ],
        ),
      ),
      build: (ctx) => [
        pw.Container(
          width: double.infinity,
          color: navy,
          padding: const pw.EdgeInsets.fromLTRB(36, 26, 36, 22),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(_jqBizName, style: pw.TextStyle(
                        font: bold, fontSize: 22, color: gold, letterSpacing: 1.5)),
                    pw.SizedBox(height: 3),
                    pw.Text('Professional Printing Services', style: s(regular, 9, textLight)),
                    pw.SizedBox(height: 9),
                    pw.Container(height: 1, width: 160, color: const PdfColor.fromInt(0xFF334155)),
                    pw.SizedBox(height: 9),
                    pw.Text(_jqBizAddr1, style: s(regular, 8.5, const PdfColor.fromInt(0xFFCBD5E1))),
                    pw.Text(_jqBizAddr2, style: s(regular, 8.5, const PdfColor.fromInt(0xFFCBD5E1))),
                    pw.SizedBox(height: 5),
                    pw.Text('TIN: $_jqBizTin', style: s(regular, 8.5, const PdfColor.fromInt(0xFFCBD5E1))),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('EMPLOYEE ACTIVITY REPORT', style: pw.TextStyle(
                      font: bold, fontSize: 16, color: gold, letterSpacing: 1.0)),
                  pw.SizedBox(height: 10),
                  pdfMeta('Date Generated', _reportFmtDateGenerated(now), white),
                  pw.SizedBox(height: 4),
                  pdfMeta('Generated By', 'Admin', const PdfColor.fromInt(0xFFCBD5E1)),
                  pw.SizedBox(height: 4),
                  pdfMeta('Report Scope', scopeLabel, const PdfColor.fromInt(0xFFCBD5E1)),
                ],
              ),
            ],
          ),
        ),
        pw.Container(
          width: double.infinity,
          color: accentBg,
          padding: const pw.EdgeInsets.fromLTRB(36, 10, 36, 10),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('SUMMARY', style: s(bold, 7.5, textLight)),
              pw.SizedBox(height: 6),
              pw.Wrap(spacing: 0, runSpacing: 0, children: [
                summaryChip('Total Entries', rows.length, navy),
                summaryChip('Inventory', invCount, const PdfColor.fromInt(0xFF2563EB)),
                summaryChip('Job Queue', jqCount, const PdfColor.fromInt(0xFF7C3AED)),
                summaryChip('POS', posCount, const PdfColor.fromInt(0xFF16A34A)),
              ]),
            ],
          ),
        ),
        pw.SizedBox(height: 18),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 36),
          child: rows.isEmpty
              ? pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 20),
            child: pw.Text('No activity logs match this selection.', style: s(italic, 9, textMid)),
          )
              : _reportTable(
            headers: headers,
            data: tableRows,
            regular: regular,
            bold: bold,
            navy: navy,
            gold: gold,
            textDark: textDark,
            rowAlt: rowAlt,
            rowBorder: rowBorder,
            wrapTwoLines: const {4},
            columnWidths: const {
              0: pw.FixedColumnWidth(24),
              1: pw.FlexColumnWidth(1.3),
              2: pw.FlexColumnWidth(1.0),
              3: pw.FlexColumnWidth(0.9),
              4: pw.FlexColumnWidth(3.2),
              5: pw.FlexColumnWidth(1.0),
              6: pw.FlexColumnWidth(0.8),
              7: pw.FlexColumnWidth(0.9),
            },
          ),
        ),
      ],
    ),
  );

  return Uint8List.fromList(await doc.save());
}

// =============================================================================
// Customer Feedback Report — "Print Document"
// =============================================================================

enum _FeedbackPrintMode { all, specificRating }

class _FeedbackPrintRequest {
  final _FeedbackPrintMode mode;
  final int? rating;
  const _FeedbackPrintRequest({required this.mode, required this.rating});
}

class _FeedbackPrintDialog extends StatefulWidget {
  const _FeedbackPrintDialog();

  @override
  State<_FeedbackPrintDialog> createState() => _FeedbackPrintDialogState();
}

class _FeedbackPrintDialogState extends State<_FeedbackPrintDialog> {
  _FeedbackPrintMode _mode = _FeedbackPrintMode.all;
  int _rating = 5;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: const BoxDecoration(
              color: _G.navyBlue,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              const Icon(Icons.print_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Expanded(child: Text('Print Customer Feedback Report',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Choose what to include in the report:',
                  style: TextStyle(color: _G.textSecondary, fontSize: 12)),
              const SizedBox(height: 10),
              _PrintModeOption(
                icon: Icons.all_inclusive_rounded,
                title: 'All feedbacks',
                subtitle: 'Includes every customer feedback submission.',
                active: _mode == _FeedbackPrintMode.all,
                onTap: () => setState(() => _mode = _FeedbackPrintMode.all),
              ),
              const SizedBox(height: 8),
              _PrintModeOption(
                icon: Icons.star_rate_rounded,
                title: 'Specific rating',
                subtitle: 'Includes only feedback with the selected star rating.',
                active: _mode == _FeedbackPrintMode.specificRating,
                onTap: () => setState(() => _mode = _FeedbackPrintMode.specificRating),
              ),
              if (_mode == _FeedbackPrintMode.specificRating) ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final star = i + 1;
                    final active = _rating == star;
                    return GestureDetector(
                      onTap: () => setState(() => _rating = star),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          active ? Icons.star_rounded : Icons.star_border_rounded,
                          size: 30,
                          color: active ? const Color(0xFFB45309) : _G.textMuted,
                        ),
                      ),
                    );
                  }),
                ),
              ],
              const SizedBox(height: 8),
            ]),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _G.borderSolid)),
            ),
            child: Row(children: [
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(
                  _FeedbackPrintRequest(
                    mode: _mode,
                    rating: _mode == _FeedbackPrintMode.specificRating ? _rating : null,
                  ),
                ),
                icon: const Icon(Icons.print_rounded, size: 16),
                label: const Text('Generate Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _G.navyBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

Future<void> _generateFeedbackReport(BuildContext context, _FeedbackPrintRequest req) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(content: Text('Preparing feedback report…'), duration: Duration(seconds: 2)),
  );

  try {
    final db = FirebaseFirestore.instance;
    Query<Map<String, dynamic>> q = db.collection('OrderReviews');
    if (req.rating != null) {
      q = q.where('rating', isEqualTo: req.rating);
    }
    final snap = await q.get();
    final docs = [...snap.docs]..sort((a, b) {
      final ta = a.data()['created_at'] as Timestamp?;
      final tb = b.data()['created_at'] as Timestamp?;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });

    final scopeLabel = req.rating != null ? 'Rating: ${req.rating} Star(s)' : 'All Feedbacks';
    final bytes = await _buildFeedbackPdf(docs: docs, scopeLabel: scopeLabel);

    final now = DateTime.now();
    final stamp = '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
    final filename = 'customer_feedback_report_$stamp.pdf';

    if (kIsWeb) {
      await file_utils.downloadBytes(bytes, 'application/pdf', filename);
    } else {
      await Printing.sharePdf(bytes: bytes, filename: filename);
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to generate report: $e')),
    );
  }
}

Future<Uint8List> _buildFeedbackPdf({
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  required String scopeLabel,
}) async {
  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold    = await PdfGoogleFonts.notoSansBold();
  final italic  = await PdfGoogleFonts.notoSansItalic();

  final doc = pw.Document();
  final now = DateTime.now();

  const navy      = PdfColor.fromInt(0xFF0F1A2E);
  const gold      = PdfColor.fromInt(0xFFE8B84B);
  const white     = PdfColors.white;
  const textDark  = PdfColor.fromInt(0xFF0F172A);
  const textMid   = PdfColor.fromInt(0xFF475569);
  const textLight = PdfColor.fromInt(0xFF94A3B8);
  const rowAlt    = PdfColor.fromInt(0xFFF8FAFC);
  const rowBorder = PdfColor.fromInt(0xFFE2E8F0);
  const accentBg  = PdfColor.fromInt(0xFFF0F9FF);
  const amber     = PdfColor.fromInt(0xFFB45309);

  pw.TextStyle s(pw.Font f, double sz, PdfColor c) => pw.TextStyle(font: f, fontSize: sz, color: c);

  pw.Widget pdfMeta(String label, String value, PdfColor valueColor) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.end,
    children: [
      pw.Text('$label  ', style: pw.TextStyle(font: regular, fontSize: 8.5,
          color: const PdfColor.fromInt(0xFF64748B))),
      pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 8.5, color: valueColor)),
    ],
  );

  pw.Widget summaryChip(String label, String value, PdfColor color) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    margin: const pw.EdgeInsets.only(right: 6, bottom: 4),
    decoration: pw.BoxDecoration(
      color: white,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(9)),
      border: pw.Border.all(color: color, width: 0.7),
    ),
    child: pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
      pw.Container(width: 9, height: 9, decoration: pw.BoxDecoration(
          color: color, shape: pw.BoxShape.circle)),
      pw.SizedBox(width: 4),
      pw.Text(value, style: s(bold, 8, textDark)),
      pw.SizedBox(width: 2),
      pw.Text(label, style: s(regular, 7, textMid)),
    ]),
  );

  final ratingCounts = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
  double ratingSum = 0;
  int ratedCount = 0;
  for (final d in docs) {
    final r = (d.data()['rating'] as num?)?.toInt();
    if (r != null && r >= 1 && r <= 5) {
      ratingCounts[r] = (ratingCounts[r] ?? 0) + 1;
      ratingSum += r;
      ratedCount++;
    }
  }
  final avgRating = ratedCount > 0 ? ratingSum / ratedCount : 0.0;

  final headers = ['#', 'CUSTOMER', 'RATING', 'FEEDBACK', 'RELATED ORDER', 'DATE', 'TIME'];
  final tableRows = docs.asMap().entries.map((e) {
    final i = e.key;
    final data = e.value.data();
    final custName = data['customer_name']?.toString() ?? '';
    final custId = data['customer_id']?.toString() ?? '';
    final custDisplay = custName.isNotEmpty ? custName : (custId.isNotEmpty ? custId : '—');
    final rating = (data['rating'] as num?)?.toInt() ?? 0;
    final message = data['message']?.toString() ?? '';
    final orderId = data['order_id']?.toString() ?? '—';
    final ts = data['created_at'] as Timestamp?;
    return [
      '${i + 1}',
      _reportShorten(custDisplay, 22),
      rating > 0 ? '$rating ★' : '—',
      _reportShorten(message.isEmpty ? '—' : message, 70),
      _reportShorten(orderId, 16),
      _reportFmtDate(ts),
      _reportFmtTime(ts),
    ];
  }).toList();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: pw.EdgeInsets.zero,
      maxPages: 5000,
      header: (ctx) => ctx.pageNumber == 1
          ? pw.SizedBox()
          : pw.Container(
        width: double.infinity,
        color: navy,
        padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 10),
        child: pw.Text('$_jqBizName  ·  Customer Feedback Report', style: s(bold, 9, gold)),
      ),
      footer: (ctx) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 10),
        decoration: const pw.BoxDecoration(color: rowAlt),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('$_jqBizName  ·  TIN: $_jqBizTin', style: s(bold, 7.5, textMid)),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: s(regular, 7.5, textLight)),
          ],
        ),
      ),
      build: (ctx) => [
        pw.Container(
          width: double.infinity,
          color: navy,
          padding: const pw.EdgeInsets.fromLTRB(36, 26, 36, 22),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(_jqBizName, style: pw.TextStyle(
                        font: bold, fontSize: 22, color: gold, letterSpacing: 1.5)),
                    pw.SizedBox(height: 3),
                    pw.Text('Professional Printing Services', style: s(regular, 9, textLight)),
                    pw.SizedBox(height: 9),
                    pw.Container(height: 1, width: 160, color: const PdfColor.fromInt(0xFF334155)),
                    pw.SizedBox(height: 9),
                    pw.Text(_jqBizAddr1, style: s(regular, 8.5, const PdfColor.fromInt(0xFFCBD5E1))),
                    pw.Text(_jqBizAddr2, style: s(regular, 8.5, const PdfColor.fromInt(0xFFCBD5E1))),
                    pw.SizedBox(height: 5),
                    pw.Text('TIN: $_jqBizTin', style: s(regular, 8.5, const PdfColor.fromInt(0xFFCBD5E1))),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('CUSTOMER FEEDBACK REPORT', style: pw.TextStyle(
                      font: bold, fontSize: 16, color: gold, letterSpacing: 1.0)),
                  pw.SizedBox(height: 10),
                  pdfMeta('Date Generated', _reportFmtDateGenerated(now), white),
                  pw.SizedBox(height: 4),
                  pdfMeta('Generated By', 'Admin', const PdfColor.fromInt(0xFFCBD5E1)),
                  pw.SizedBox(height: 4),
                  pdfMeta('Report Scope', scopeLabel, const PdfColor.fromInt(0xFFCBD5E1)),
                ],
              ),
            ],
          ),
        ),
        pw.Container(
          width: double.infinity,
          color: accentBg,
          padding: const pw.EdgeInsets.fromLTRB(36, 10, 36, 10),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('SUMMARY', style: s(bold, 7.5, textLight)),
              pw.SizedBox(height: 6),
              pw.Wrap(spacing: 0, runSpacing: 0, children: [
                summaryChip('Total Feedback', '${docs.length}', navy),
                summaryChip('Average Rating', avgRating.toStringAsFixed(1), amber),
                summaryChip('5★', '${ratingCounts[5]}', const PdfColor.fromInt(0xFF16A34A)),
                summaryChip('4★', '${ratingCounts[4]}', const PdfColor.fromInt(0xFF65A30D)),
                summaryChip('3★', '${ratingCounts[3]}', const PdfColor.fromInt(0xFFD97706)),
                summaryChip('2★', '${ratingCounts[2]}', const PdfColor.fromInt(0xFFEA580C)),
                summaryChip('1★', '${ratingCounts[1]}', const PdfColor.fromInt(0xFFDC2626)),
              ]),
            ],
          ),
        ),
        pw.SizedBox(height: 18),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 36),
          child: docs.isEmpty
              ? pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 20),
            child: pw.Text('No feedback matches this selection.', style: s(italic, 9, textMid)),
          )
              : _reportTable(
            headers: headers,
            data: tableRows,
            regular: regular,
            bold: bold,
            navy: navy,
            gold: gold,
            textDark: textDark,
            rowAlt: rowAlt,
            rowBorder: rowBorder,
            wrapTwoLines: const {3},
            columnWidths: const {
              0: pw.FixedColumnWidth(24),
              1: pw.FlexColumnWidth(1.3),
              2: pw.FixedColumnWidth(50),
              3: pw.FlexColumnWidth(3.4),
              4: pw.FlexColumnWidth(1.1),
              5: pw.FlexColumnWidth(1.0),
              6: pw.FlexColumnWidth(0.8),
            },
          ),
        ),
      ],
    ),
  );

  return Uint8List.fromList(await doc.save());
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
      case 'uncollected':
        return const Color(0xFFB45309);
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
      case 'uncollected':
        return 'Uncollected';
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

    // 30-day pickup window, set when the order is marked ready. Falls back
    // to ready_at/created_at + 30 days for orders written before this field
    // existed.
    final DateTime? pickupExpiresAt = (() {
      final ts = data['pickup_expires_at'] as Timestamp?;
      if (ts != null) return ts.toDate().toLocal();
      final readyAt = (data['ready_at'] as Timestamp?)?.toDate().toLocal();
      if (readyAt != null) return readyAt.add(const Duration(days: 30));
      final createdAt = (data['created_at'] as Timestamp?)?.toDate().toLocal();
      if (createdAt != null) return createdAt.add(const Duration(days: 30));
      return null;
    })();

    final DateTime? uncollectedAt =
    (data['uncollected_at'] as Timestamp?)?.toDate().toLocal();

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
                            crossAxisAlignment: CrossAxisAlignment.center,
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

                // ── Ready/Uncollected: expiry + info chips + payment bar (queue) ──
                if ((rawStatus == 'ready' || rawStatus == 'uncollected') &&
                    showDueDate) ...[
                  if (rawStatus == 'ready' && pickupExpiresAt != null) ...[
                    const SizedBox(height: 8),
                    _AdminExpiryRow(expiresAt: pickupExpiresAt),
                  ],
                  if (rawStatus == 'uncollected' && uncollectedAt != null) ...[
                    const SizedBox(height: 8),
                    _AdminUncollectedRow(uncollectedAt: uncollectedAt),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _AdminInfoChip(
                        'Total',
                        '₱${AppTheme.fmtAmt(total)}',
                        _G.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      _AdminInfoChip(
                        'Paid',
                        '₱${AppTheme.fmtAmt(amountPaid)}',
                        _G.accentEmerald,
                      ),
                      const SizedBox(width: 10),
                      _AdminInfoChip(
                        fullyPaid ? 'Fully Paid' : 'Balance Due',
                        fullyPaid ? '—' : '₱${AppTheme.fmtAmt(remaining)}',
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
                  // Info chips
                  Row(
                    children: [
                      _AdminInfoChip(
                        'Total',
                        '₱${AppTheme.fmtAmt(total)}',
                        _G.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      _AdminInfoChip(
                        'Paid',
                        '₱${AppTheme.fmtAmt(amountPaid)}',
                        _G.accentEmerald,
                      ),
                      const SizedBox(width: 10),
                      _AdminInfoChip(
                        fullyPaid ? 'Fully Paid' : 'Balance',
                        fullyPaid
                            ? '—'
                            : '₱${AppTheme.fmtAmt(remaining)}',
                        fullyPaid ? _G.accentEmerald : _G.accentAmber,
                        bold: true,
                      ),
                    ],
                  ),
                  if (rawStatus == 'ready' || rawStatus == 'uncollected') ...[
                    const SizedBox(height: 8),
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
                    if (rawStatus == 'ready' && pickupExpiresAt != null) ...[
                      const SizedBox(height: 8),
                      _AdminExpiryRow(expiresAt: pickupExpiresAt),
                    ],
                    if (rawStatus == 'uncollected' && uncollectedAt != null) ...[
                      const SizedBox(height: 8),
                      _AdminUncollectedRow(uncollectedAt: uncollectedAt),
                    ],
                  ],
                  const SizedBox(height: 8),
                  // Date + turnaround (left) · invoice (right)
                  Row(
                    children: [
                      dateRow(),
                      const Spacer(),
                      _InvoiceButton(orderId: orderId),
                    ],
                  ),
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
                            '₱${AppTheme.fmtAmt(total)}',
                            style: const TextStyle(
                              color: _G.accentAmber,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (amountPaid > 0)
                            Text(
                              'Paid: ₱${AppTheme.fmtAmt(amountPaid)}',
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
                              'Refund to be picked up — ₱${AppTheme.fmtAmt(amountPaid)}',
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
                ] else if (rawStatus == 'ready' || rawStatus == 'uncollected') ...[
                  // Ready/Uncollected footer: date+turnaround + invoice (amounts shown above in chips)
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
                            '₱${AppTheme.fmtAmt(total)}',
                            style: const TextStyle(
                              color: _G.accentAmber,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (amountPaid > 0)
                            Text(
                              'Paid: ₱${AppTheme.fmtAmt(amountPaid)}',
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
// _AdminUncollectedRow — shows how long an order has sat uncollected
// =============================================================================
class _AdminUncollectedRow extends StatelessWidget {
  final DateTime uncollectedAt;
  const _AdminUncollectedRow({required this.uncollectedAt});

  static String _fmt(DateTime d) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final marked = DateTime(uncollectedAt.year, uncollectedAt.month, uncollectedAt.day);
    final daysSince = today.difference(marked).inDays;

    const color = Color(0xFFB45309);
    final label = daysSince <= 0
        ? 'Marked uncollected today (${_fmt(uncollectedAt)})'
        : 'Uncollected for $daysSince day${daysSince == 1 ? '' : 's'} '
        '(since ${_fmt(uncollectedAt)})';

    return Row(
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 14,
          color: Color(0xE6B45309),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
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
      label = 'Overdue by ${-diff} day${-diff == 1 ? '' : 's'} (${_fmt(dueDate)})';
    } else if (diff == 0) {
      color = _G.accentRose;
      label = 'Target completion: TODAY';
    } else if (diff == 1) {
      color = _G.accentAmber;
      label = 'Target completion: Tomorrow, ${_fmt(dueDate)}';
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
// _AdminExpiryRow — 30-day "ready for pickup" deadline, mirrors _AdminDueDateRow
// =============================================================================
class _AdminExpiryRow extends StatelessWidget {
  final DateTime expiresAt;
  const _AdminExpiryRow({required this.expiresAt});

  static String _fmt(DateTime d) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(expiresAt.year, expiresAt.month, expiresAt.day);
    final diff = exp.difference(today).inDays;

    final Color color;
    final String label;

    if (diff < 0) {
      color = _G.accentRose;
      label = 'Pickup window expired ${-diff} day${-diff == 1 ? '' : 's'} ago '
          '(${_fmt(expiresAt)})';
    } else if (diff == 0) {
      color = _G.accentRose;
      label = 'Pickup window expires TODAY';
    } else if (diff <= 5) {
      color = _G.accentAmber;
      label = 'Pickup by ${_fmt(expiresAt)} ($diff day${diff == 1 ? '' : 's'} left)';
    } else {
      color = _G.accentEmerald;
      label = 'Pickup by ${_fmt(expiresAt)} (30-day window)';
    }

    return Row(
      children: [
        Icon(
          diff < 0 ? Icons.error_outline_rounded : Icons.event_available_rounded,
          size: 14,
          color: color.withValues(alpha: 0.85),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: diff <= 5 ? FontWeight.w700 : FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
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
      q = q.where('status', whereIn: ['pending', 'in_production', 'ready', 'uncollected', 'completed', 'cancelled']); // 'uncollected' kept for legacy orders predating auto-cancel
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
  bool _printing = false;

  Future<void> _onPrintDocument() async {
    if (_printing) return;
    setState(() => _printing = true);
    try {
      // Sales Record tab → lean records-only PDF (just the table, no
      // analysis). Sales Report tab → full analytical report (summary,
      // records, price change analysis, revenue impact, best sellers,
      // payment/order-status breakdowns, remarks).
      if (_sub == _SalesSubTab.record) {
        // Matches whatever date range is currently selected on the Sales
        // Record view, kept in sync via adminSalesRecordsRange.
        await generateAdminSalesRecordsPdf(context, range: adminSalesRecordsRange.value);
      } else {
        // Matches whatever date range is currently selected on the Sales
        // Report view, kept in sync via adminSalesReportRange.
        await generateAdminSalesReportPdf(context, range: adminSalesReportRange.value);
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

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
              // Print Document — Admin-only. Which PDF gets generated
              // depends on the active sub-tab: "Sales Record" prints a lean
              // records-only listing, while "Sales Report" prints the full
              // analytical report (summary, price change analysis, revenue
              // impact, best sellers, payment/order-status breakdowns, and
              // remarks). See _onPrintDocument.
              GestureDetector(
                onTap: _onPrintDocument,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: _G.solidPill(_G.navyBlue),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _printing
                          ? const SizedBox(
                        width: 13, height: 13,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : const Icon(Icons.print_rounded, size: 13, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        _printing
                            ? 'Preparing…'
                            : (_sub == _SalesSubTab.record
                            ? 'Print Records'
                            : 'Print Report'),
                        style: const TextStyle(
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
  bool _printing = false;

  Future<void> _onPrintActivity() async {
    if (_printing) return;
    final req = await showDialog<_EmployeeActivityPrintRequest>(
      context: context,
      builder: (_) => const _EmployeeActivityPrintDialog(),
    );
    if (req == null) return;
    if (!mounted) return;
    setState(() => _printing = true);
    try {
      await _generateEmployeeActivityReport(context, req);
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  // Inventory filters
  String _employeeFilter = '';
  String _materialFilter = '';
  final _empCtrl = TextEditingController();
  final _matCtrl = TextEditingController();

  // Job Queue filter
  String _jqFilter = '';
  String _jqOrderFilter = '';
  final _jqCtrl = TextEditingController();
  final _jqOrderCtrl = TextEditingController();

  // POS filter
  String _posFilter = '';
  String _posOrderFilter = '';
  final _posCtrl = TextEditingController();
  final _posOrderCtrl = TextEditingController();

  static final _dateFmt = DateFormat('MMM dd, yyyy hh:mm a');

  @override
  void dispose() {
    _empCtrl.dispose();
    _matCtrl.dispose();
    _jqCtrl.dispose();
    _jqOrderCtrl.dispose();
    _posCtrl.dispose();
    _posOrderCtrl.dispose();
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
              // Print Document — opens a filter dialog (all categories,
              // one category, a specific date, or one employee on a date).
              GestureDetector(
                onTap: _onPrintActivity,
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: _G.solidPill(_G.navyBlue),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _printing
                          ? const SizedBox(
                        width: 13, height: 13,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : const Icon(Icons.print_rounded, size: 13, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        _printing ? 'Preparing…' : 'Print Document',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
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
              SizedBox(width: 8),
              Expanded(flex: 2, child: Text('Employee', style: _hStyle)),
              SizedBox(width: 8),
              Expanded(flex: 2, child: Text('Material', style: _hStyle)),
              SizedBox(width: 8),
              Expanded(flex: 1, child: Text('Added', style: _hStyle, textAlign: TextAlign.right)),
              SizedBox(width: 8),
              Expanded(flex: 1, child: Text('New Stock', style: _hStyle, textAlign: TextAlign.right)),
              SizedBox(width: 8),
              Expanded(flex: 1, child: Text('Method', style: _hStyle, textAlign: TextAlign.center)),
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
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _jqOrderCtrl,
                style: const TextStyle(color: _G.textPrimary, fontSize: 13),
                onChanged: (v) => setState(() => _jqOrderFilter = v.toLowerCase()),
                decoration: _G.field(
                  'Filter by order ID',
                  icon: Icons.receipt_outlined,
                ),
              ),
            ),
            if (_jqFilter.isNotEmpty || _jqOrderFilter.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: GestureDetector(
                  onTap: () {
                    _jqCtrl.clear();
                    _jqOrderCtrl.clear();
                    setState(() { _jqFilter = ''; _jqOrderFilter = ''; });
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
              Expanded(flex: 2, child: Text('Order / Customer', style: _hStyle)),
              Expanded(flex: 2, child: Text('Action', style: _hStyle)),
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
                final orderId =
                    data['order_id']?.toString().toLowerCase() ?? '';
                return (_jqFilter.isEmpty ||
                    emp.contains(_jqFilter) ||
                    empId.contains(_jqFilter)) &&
                    (_jqOrderFilter.isEmpty || orderId.contains(_jqOrderFilter));
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
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _posOrderCtrl,
                style: const TextStyle(color: _G.textPrimary, fontSize: 13),
                onChanged: (v) => setState(() => _posOrderFilter = v.toLowerCase()),
                decoration: _G.field(
                  'Filter by order ID',
                  icon: Icons.receipt_outlined,
                ),
              ),
            ),
            if (_posFilter.isNotEmpty || _posOrderFilter.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: GestureDetector(
                  onTap: () {
                    _posCtrl.clear();
                    _posOrderCtrl.clear();
                    setState(() { _posFilter = ''; _posOrderFilter = ''; });
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
              Expanded(child: Text('Timestamp', style: _hStyle)),
              SizedBox(width: 8),
              Expanded(child: Text('Employee', style: _hStyle)),
              SizedBox(width: 8),
              Expanded(child: Text('Order / Customer', style: _hStyle)),
              SizedBox(width: 8),
              Expanded(child: Text('Amount', style: _hStyle)),
              SizedBox(width: 8),
              Expanded(child: Text('Type', style: _hStyle)),
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
                final orderId =
                    data['order_id']?.toString().toLowerCase() ?? '';
                return (_posFilter.isEmpty ||
                    emp.contains(_posFilter) ||
                    empId.contains(_posFilter)) &&
                    (_posOrderFilter.isEmpty || orderId.contains(_posOrderFilter));
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
            flex: 2,
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
                    style: const TextStyle(
                      color: _G.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (data['walk_in'] == true || custName.isEmpty)
                  const Text(
                    'Walk-in',
                    style: TextStyle(
                      color: _G.textMuted,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
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
            flex: 2,
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
                      '₱${AppTheme.fmtAmt(amountRefunded)} refunded',
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
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                timeStr,
                style: const TextStyle(color: _G.textMuted, fontSize: 11),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Employee
          Expanded(
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
          const SizedBox(width: 8),
          // Order / Customer
          Expanded(
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
                    style: const TextStyle(
                      color: _G.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (data['walk_in'] == true || custName.isEmpty)
                  const Text(
                    'Walk-in',
                    style: TextStyle(
                      color: _G.textMuted,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
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
          const SizedBox(width: 8),
          // Amount
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                '₱${AppTheme.fmtAmt(amount)}',
                style: const TextStyle(
                  color: _G.accentAmber,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Type pill
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
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
// Customer Feedback Tab
// =============================================================================
class _CustomerFeedbackTab extends StatefulWidget {
  const _CustomerFeedbackTab();

  @override
  State<_CustomerFeedbackTab> createState() => _CustomerFeedbackTabState();
}

class _CustomerFeedbackTabState extends State<_CustomerFeedbackTab> {
  static const Color _feedbackAmber = Color(0xFFB45309);

  // Stream stored once in initState — prevents reconnection on every rebuild,
  // which was causing the TextField to stutter/refocus on each keystroke.
  StreamSubscription<QuerySnapshot>? _sub;
  List<QueryDocumentSnapshot> _allDocs = [];
  bool _loading = true;

  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int? _ratingFilter; // null = all
  bool _printing = false;

  Future<void> _onPrintFeedback() async {
    if (_printing) return;
    final req = await showDialog<_FeedbackPrintRequest>(
      context: context,
      builder: (_) => const _FeedbackPrintDialog(),
    );
    if (req == null) return;
    if (!mounted) return;
    setState(() => _printing = true);
    try {
      await _generateFeedbackReport(context, req);
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _sub = FirebaseFirestore.instance
        .collection('OrderReviews')
        .orderBy('created_at', descending: true)
        .limit(200)
        .snapshots()
        .listen((snap) {
      setState(() {
        _allDocs = snap.docs;
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot> _applyFilters(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;

      if (_ratingFilter != null) {
        if ((data['rating'] as num?)?.toInt() != _ratingFilter) return false;
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final customer =
        (data['customer_name']?.toString() ?? '').toLowerCase();
        final orderId = (data['order_id']?.toString() ?? '').toLowerCase();
        final customerId =
        (data['customer_id']?.toString() ?? '').toLowerCase();
        final rawNames = data['product_names'];
        final productNames = rawNames is List
            ? rawNames.map((e) => e.toString().toLowerCase()).toList()
            : (data['product_name']?.toString() ?? '').isNotEmpty
            ? [data['product_name'].toString().toLowerCase()]
            : <String>[];
        final matchesProduct = productNames.any((n) => n.contains(q));
        if (!customer.contains(q) &&
            !orderId.contains(q) &&
            !customerId.contains(q) &&
            !matchesProduct) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Widget _searchField() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: _G.surfaceThin,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _G.borderDim, width: 0.8),
      ),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(color: _G.textPrimary, fontSize: 13),
        onChanged: (v) => setState(() => _searchQuery = v.trim()),
        decoration: InputDecoration(
          hintText: 'Search by customer, ID, order, or product…',
          hintStyle: const TextStyle(color: _G.textMuted, fontSize: 12),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: _G.textMuted,
            size: 18,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
            onTap: () {
              _searchCtrl.clear();
              setState(() => _searchQuery = '');
            },
            child: const Icon(
              Icons.close_rounded,
              color: _G.textMuted,
              size: 16,
            ),
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _ratingDropdown() {
    final value = _ratingFilter != null ? '$_ratingFilter' : null;
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _G.surfaceThin,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value != null
              ? _feedbackAmber.withValues(alpha: 0.55)
              : _G.borderDim,
          width: 0.9,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: const Text(
            'Rating',
            style: TextStyle(color: _G.textMuted, fontSize: 12),
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: _G.textMuted,
            size: 18,
          ),
          dropdownColor: Colors.white,
          style: const TextStyle(color: Colors.black, fontSize: 12),
          onChanged: (v) =>
              setState(() => _ratingFilter = v != null ? int.parse(v) : null),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(
                'All',
                style: TextStyle(
                  color: value == null ? Colors.black : Colors.black54,
                  fontSize: 12,
                  fontWeight: value == null ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            ...List.generate(5, (i) {
              final star = '${i + 1}';
              final stars = '★' * (i + 1);
              final isSelected = value == star;
              return DropdownMenuItem<String>(
                value: star,
                child: Text(
                  stars,
                  style: TextStyle(
                    color: isSelected
                        ? _feedbackAmber
                        : _feedbackAmber.withValues(alpha: 0.65),
                    fontSize: 14,
                    letterSpacing: 2,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(
          color: _G.navyBlue.withValues(alpha: 0.5),
          strokeWidth: 2,
        ),
      );
    }

    if (_allDocs.isEmpty) {
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

    final docs = _applyFilters(_allDocs)
      ..sort((a, b) {
        final aRead = (a.data() as Map)['read'] == true;
        final bRead = (b.data() as Map)['read'] == true;
        if (aRead == bRead) return 0;
        return aRead ? 1 : -1; // unread first
      });

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
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
                  decoration: _G.pill(tint: _G.navyBlue),
                  child: Text(
                    '${docs.length}',
                    style: const TextStyle(
                      color: _G.navyBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                // Print Document — opens a filter dialog (all feedback or a
                // specific star rating).
                GestureDetector(
                  onTap: _onPrintFeedback,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: _G.solidPill(_G.navyBlue),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _printing
                            ? const SizedBox(
                          width: 13, height: 13,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                            : const Icon(Icons.print_rounded, size: 13, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          _printing ? 'Preparing…' : 'Print Document',
                          style: const TextStyle(
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
          ),
          // ── Search + Rating row ─────────────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 360;
              return isNarrow
                  ? Column(
                children: [
                  _searchField(),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _ratingDropdown(),
                  ),
                ],
              )
                  : Row(
                children: [
                  Expanded(child: _searchField()),
                  const SizedBox(width: 8),
                  _ratingDropdown(),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          // ── List ────────────────────────────────────────────────────────
          Expanded(
            child: docs.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.search_off_rounded,
                    color: _G.textMuted,
                    size: 32,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No results found',
                    style: TextStyle(
                      color: _G.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
                : Scrollbar(
              thumbVisibility: true,
              trackVisibility: true,
              child: ListView.builder(
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final data =
                  docs[i].data() as Map<String, dynamic>;
                  final customer =
                      data['customer_name']?.toString() ?? '—';
                  final message =
                      data['message']?.toString() ?? '';
                  final rating =
                  (data['rating'] as num?)?.toInt();
                  final orderId =
                      data['order_id']?.toString() ?? '';
                  final rawNames = data['product_names'];
                  final docProductNames = rawNames is List
                      ? rawNames
                      .map((e) => e.toString())
                      .where((n) => n.isNotEmpty)
                      .toList()
                      : (data['product_name']?.toString() ?? '')
                      .isNotEmpty
                      ? [data['product_name'].toString()]
                      : <String>[];
                  final productNamesStr =
                  docProductNames.join(', ');
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
                                        productNamesStr.isNotEmpty)
                                      Text(
                                        [
                                          if (orderId.isNotEmpty)
                                            orderId,
                                          if (productNamesStr.isNotEmpty)
                                            productNamesStr,
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
                              if (rating != null)
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
                            ],
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
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                timeStr,
                                style: const TextStyle(
                                  color: _G.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                              if (!isRead)
                                GestureDetector(
                                  onTap: () =>
                                      FirebaseFirestore.instance
                                          .collection('OrderReviews')
                                          .doc(docs[i].id)
                                          .update({'read': true}),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 13,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _G.accentEmerald,
                                      borderRadius:
                                      BorderRadius.circular(99),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 13,
                                        ),
                                        SizedBox(width: 5),
                                        Text(
                                          'Mark read',
                                          style: TextStyle(
                                            color: Colors.white,
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
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                if (!isOrderDeduction && employeeDisplayId.isNotEmpty)
                  Text(
                    'ID: $employeeDisplayId',
                    style: const TextStyle(
                      color: _G.textMuted,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
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
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
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
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
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
                            walkIn: data['walk_in'] == true,
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
  final bool walkIn;

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
    this.walkIn = false,
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
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
                        if (walkIn) ...[
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
                value: '₱${AppTheme.fmtAmt(total)}',
                color: _G.textPrimary,
                bgColor: _G.surfaceThin,
                borderColor: _G.borderMid,
              );
              final paidChip = _PayChip(
                label: 'Paid',
                value: '₱${AppTheme.fmtAmt(paid)}',
                color: _G.accentEmerald,
                bgColor: const Color(0xFFF0FDF4),
                borderColor: const Color(0xFFBBF7D0),
              );
              final balanceChip = _PayChip(
                label: fullyPaid ? 'Fully Paid' : 'Balance',
                value: fullyPaid
                    ? '✓ Paid'
                    : '₱${AppTheme.fmtAmt(remaining)}',
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
          Divider(height: 0.8, color: _G.borderDim),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
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