import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'app_theme.dart';
import 'sales_widgets.dart';
import 'employee_pos_screen.dart';
import 'invoice_screen.dart';
import 'design_file_viewer.dart';
import 'chat_screen.dart';
import '../services/inventory_service.dart';
import '../services/turnaround_service.dart';

// =============================================================================
// Design Tokens — Liquid Glass (aligned with EmployeeInventoryScreen)
// =============================================================================
const Color _navyBlue = Color(0xFF0F1A2E);
const Color _amber = Color(0xFFB45309);

class _Glass {
  static const Color surface = Color(0xF8FFFFFF);
  static const Color surfaceMid = Color(0xF0FFFFFF);
  static const Color surfaceThin = Color(0xA0FFFFFF);

  static const Color borderMid = Color(0x70FFFFFF);
  static const Color borderDim = Color(0x30FFFFFF);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xCC0F172A);
  static const Color textMuted = Color(0x880F172A);

  static const Color accentEmerald = Color(0xFF10B981);
  static const Color accentRose = Color(0xFFEF4444);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentAmber = Color(0xFFF59E0B);

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

final _blurFilter = ImageFilter.blur(sigmaX: 14, sigmaY: 14);

// =============================================================================
// Reusable frosted-glass card
// =============================================================================
class _BlurCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final bool elevated;

  const _BlurCard({
    required this.child,
    this.padding,
    this.radius = 20,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: _blurFilter,
      child: Container(
        decoration: _Glass.glass(radius: radius, elevated: elevated),
        padding: padding,
        child: child,
      ),
    ),
  );
}

// =============================================================================
// EmployeeLogsScreen
// =============================================================================
class EmployeeLogsScreen extends StatefulWidget {
  const EmployeeLogsScreen({super.key});

  @override
  State<EmployeeLogsScreen> createState() => _EmployeeLogsScreenState();
}

class _EmployeeLogsScreenState extends State<EmployeeLogsScreen> {
  int _topTab = 0; // 0 = Sales, 1 = POS

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: _blurFilter,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: _Glass.glass(radius: 20, elevated: true),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _navyBlue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.receipt_long_outlined,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Employee Logs',
                                style: TextStyle(
                                  color: _Glass.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              SizedBox(height: 1),
                              Text(
                                'Sales records, reports, and POS transactions',
                                style: TextStyle(
                                  color: _Glass.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(height: 1, color: _Glass.borderDim),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _TabPill(
                          label: 'Sales',
                          icon: Icons.bar_chart_rounded,
                          isActive: _topTab == 0,
                          onTap: () => setState(() => _topTab = 0),
                        ),
                        const SizedBox(width: 8),
                        _TabPill(
                          label: 'POS',
                          icon: Icons.point_of_sale_outlined,
                          isActive: _topTab == 1,
                          onTap: () => setState(() => _topTab = 1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: switch (_topTab) {
              0 => const _SalesSection(),
              1 => const EmployeePosScreen(),
              _ => const SizedBox.shrink(),
            },
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _TabPill
// =============================================================================
class _TabPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _TabPill({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: isActive
          ? _Glass.solidPill(_navyBlue, glow: true)
          : BoxDecoration(
              color: _Glass.surfaceThin,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: _Glass.borderMid, width: 0.9),
            ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: isActive ? Colors.white : _Glass.textSecondary,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : _Glass.textSecondary,
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

// =============================================================================
// _SalesSection
// =============================================================================
enum _SalesSubTab { record, report }

class _SalesSection extends StatefulWidget {
  const _SalesSection();

  @override
  State<_SalesSection> createState() => _SalesSectionState();
}

class _SalesSectionState extends State<_SalesSection> {
  _SalesSubTab _sub = _SalesSubTab.record;

  @override
  Widget build(BuildContext context) {
    return _BlurCard(
      radius: 20,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _Glass.surfaceThin,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: _Glass.borderMid, width: 0.9),
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
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _sub == _SalesSubTab.record
                ? const SalesRecordTable()
                : const SalesReportView(),
          ),
        ],
      ),
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
            ? _Glass.solidPill(_navyBlue)
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
              color: isActive ? Colors.white : _Glass.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : _Glass.textSecondary,
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
// _PillSegmentControl
// =============================================================================
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
        color: _Glass.surfaceThin,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _Glass.borderMid, width: 0.9),
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
                      color: isActive ? Colors.white : _Glass.textMuted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      item.label,
                      style: TextStyle(
                        color: isActive ? Colors.white : _Glass.textSecondary,
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

// =============================================================================
// EmployeeJobQueueScreen
// =============================================================================
class EmployeeJobQueueScreen extends StatelessWidget {
  final int initialTab;
  const EmployeeJobQueueScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: _blurFilter,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: _Glass.glass(radius: 20, elevated: true),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _navyBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.precision_manufacturing_outlined,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Job Queue',
                            style: TextStyle(
                              color: _Glass.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            'Track and manage production orders',
                            style: TextStyle(
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
            ),
          ),
          const SizedBox(height: 10),
          Expanded(child: _JobQueueSection(initialTab: initialTab)),
        ],
      ),
    );
  }
}

// =============================================================================
// _JobQueueSection
// =============================================================================
enum _QueueSubTab { pending, active, ready, cancelled, history }

class _JobQueueSection extends StatefulWidget {
  final int initialTab;
  const _JobQueueSection({this.initialTab = 0});

  @override
  State<_JobQueueSection> createState() => _JobQueueSectionState();
}

class _JobQueueSectionState extends State<_JobQueueSection> {
  late _QueueSubTab _sub;

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
  void initState() {
    super.initState();
    final idx = widget.initialTab.clamp(0, 4);
    _sub = _QueueSubTab.values[idx];
  }

  @override
  Widget build(BuildContext context) {
    final isHistory = _sub == _QueueSubTab.history;

    return _BlurCard(
      radius: 20,
      elevated: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _sub = _QueueSubTab.history),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: _Glass.solidPill(const Color(0xFF8B5CF6)),
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
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const _AddWalkInJobDialog(),
                    ),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: _Glass.solidPill(_navyBlue, glow: true),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            if (!isHistory) const SizedBox(height: 10),
            if (!isHistory) const _DeadlineAlertBanner(),
            if (!isHistory) const SizedBox(height: 6),
            Expanded(
              child: isHistory
                  ? _EmployeeOrderHistory(
                      onBack: () => setState(() => _sub = _QueueSubTab.pending),
                    )
                  : _buildQueueContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueContent() {
    switch (_sub) {
      case _QueueSubTab.pending:
        return const _QueueList(jobStatus: 'pending');
      case _QueueSubTab.active:
        return const _QueueList(jobStatus: 'active');
      case _QueueSubTab.ready:
        return const _ReadyForPickupList();
      case _QueueSubTab.cancelled:
        return const _QueueList(jobStatus: 'cancelled');
      case _QueueSubTab.history:
        return _EmployeeOrderHistory(
          onBack: () => setState(() => _sub = _QueueSubTab.pending),
        );
    }
  }
}

// =============================================================================
// _EmployeeOrderHistory
// =============================================================================
class _EmployeeOrderHistory extends StatefulWidget {
  final VoidCallback? onBack;
  const _EmployeeOrderHistory({this.onBack});

  @override
  State<_EmployeeOrderHistory> createState() => _EmployeeOrderHistoryState();
}

class _EmployeeOrderHistoryState extends State<_EmployeeOrderHistory> {
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
    setState(() {
      _isResolvingId = true;
      _resolvedCustomerName = null;
    });
    try {
      final db = FirebaseFirestore.instance;
      QuerySnapshot<Map<String, dynamic>>? snap = await db
          .collection('User')
          .where('customer_id', isEqualTo: term)
          .limit(1)
          .get()
          .catchError((_) => null);
      if (snap == null || snap.docs.isEmpty) {
        final all = await db
            .collection('User')
            .limit(300)
            .get()
            .catchError((_) => null);
        if (all != null) {
          final lower = term.toLowerCase();
          for (final doc in all.docs) {
            final cid = (doc.data()['customer_id'] as String? ?? '')
                .toLowerCase();
            if (cid == lower) {
              final name = doc.data()['full_name'] as String?;
              if (name != null && name.isNotEmpty && mounted) {
                setState(() {
                  _resolvedCustomerName = name.toLowerCase();
                  _isResolvingId = false;
                });
              } else if (mounted) {
                setState(() => _isResolvingId = false);
              }
              return;
            }
          }
        }
      }
      final name = snap?.docs.isNotEmpty == true
          ? snap!.docs.first.data()['full_name'] as String?
          : null;
      if (mounted) {
        setState(() {
          _resolvedCustomerName = (name != null && name.isNotEmpty)
              ? name.toLowerCase()
              : null;
          _isResolvingId = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isResolvingId = false);
    }
  }

  void _onSearchChanged(String raw) {
    final term = raw.trim().toLowerCase();
    setState(() {
      _search = term;
      _resolvedCustomerName = null;
    });
    if (term.isEmpty) return;
    _resolveCustomerId(term);
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

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':
        return _Glass.accentAmber;
      case 'in_production':
        return _Glass.accentBlue;
      case 'ready':
        return _Glass.accentEmerald;
      case 'completed':
        return _Glass.accentEmerald;
      case 'cancelled':
        return _Glass.accentRose;
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.onBack != null) ...[
          GestureDetector(
            onTap: widget.onBack,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _Glass.surfaceThin,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: _Glass.borderMid, width: 0.9),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 12,
                    color: _Glass.textSecondary,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Order History',
                    style: TextStyle(
                      color: _Glass.textSecondary,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: active
                      ? _Glass.solidPill(_navyBlue, glow: true)
                      : BoxDecoration(
                          color: _Glass.surfaceThin,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: _Glass.borderMid,
                            width: 0.9,
                          ),
                        ),
                  child: Text(
                    opt.$2,
                    style: TextStyle(
                      color: active ? Colors.white : _Glass.textSecondary,
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
        Container(
          decoration: BoxDecoration(
            color: _Glass.surfaceThin,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _Glass.borderMid, width: 0.8),
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            style: const TextStyle(color: _Glass.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search by order ID, customer name, or customer ID…',
              hintStyle: const TextStyle(color: _Glass.textMuted, fontSize: 13),
              prefixIcon: const Icon(
                Icons.search,
                color: _Glass.textMuted,
                size: 18,
              ),
              suffixIcon: _search.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        setState(() {
                          _search = '';
                          _resolvedCustomerName = null;
                          _isResolvingId = false;
                        });
                      },
                      child: _isResolvingId
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _Glass.textSecondary,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.clear,
                              color: _Glass.textMuted,
                              size: 18,
                            ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<List<QueryDocumentSnapshot>>(
            stream: _stream(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return Center(
                  child: CircularProgressIndicator(
                    color: _navyBlue.withValues(alpha: 0.4),
                    strokeWidth: 2,
                  ),
                );
              }
              if (snap.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snap.error}',
                    style: const TextStyle(
                      color: _Glass.accentRose,
                      fontSize: 12,
                    ),
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
                  if (id.contains(_search) || name.contains(_search)) {
                    return true;
                  }
                  if (_resolvedCustomerName != null &&
                      name.contains(_resolvedCustomerName!)) {
                    return true;
                  }
                  return false;
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
                        decoration: _Glass.glass(radius: 20, elevated: true),
                        child: const Icon(
                          Icons.history,
                          size: 28,
                          color: _Glass.textMuted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'No orders found',
                        style: TextStyle(
                          color: _Glass.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
                  final orderId = data['order_id']?.toString() ?? doc.id;
                  final customer = data['customer_name']?.toString() ?? '—';
                  final customerId = data['customer_id']?.toString() ?? '';
                  final status = data['status']?.toString() ?? '';
                  final total = (data['total_price'] as num?)?.toDouble() ?? 0;
                  final paid = (data['amount_paid'] as num?)?.toDouble() ?? 0;
                  final remaining =
                      (data['remaining_balance'] as num?)?.toDouble() ??
                      (total - paid);
                  final products =
                      (data['products'] as List?)
                          ?.cast<Map<String, dynamic>>() ??
                      [];
                  final dateStr = _fmtDate(data['created_at']);
                  final invoiceId = data['invoice_id']?.toString();
                  final statusColor = _statusColor(status);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _Glass.accentAmber.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _Glass.accentAmber.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                color: _Glass.accentAmber,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _OrderHistoryCard(
                            doc: doc,
                            orderId: orderId,
                            customer: customer,
                            customerId: customerId,
                            status: status,
                            statusLabel: _statusLabel(status),
                            statusColor: statusColor,
                            total: total,
                            paid: paid,
                            remaining: remaining,
                            products: products,
                            dateStr: dateStr,
                            invoiceId: invoiceId,
                            cancelReason:
                                data['cancel_reason']?.toString() ?? '',
                            notes: data['notes']?.toString() ?? '',
                          ),
                        ),
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

// =============================================================================
// _OrderHistoryCard
// =============================================================================
class _OrderHistoryCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final String orderId, customer, customerId, status, statusLabel, dateStr;
  final Color statusColor;
  final double total, paid, remaining;
  final List<Map<String, dynamic>> products;
  final String? invoiceId;
  final String cancelReason;
  final String notes;

  const _OrderHistoryCard({
    required this.doc,
    required this.orderId,
    required this.customer,
    required this.customerId,
    required this.status,
    required this.statusLabel,
    required this.statusColor,
    required this.total,
    required this.paid,
    required this.remaining,
    required this.products,
    required this.dateStr,
    this.invoiceId,
    this.cancelReason = '',
    this.notes = '',
  });

  @override
  Widget build(BuildContext context) {
    final fullyPaid = remaining < 0.01;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _Glass.glass(radius: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                          color: _Glass.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '$customer · $dateStr',
                              style: const TextStyle(
                                color: _Glass.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if ((doc.data() as Map<String, dynamic>)['walk_in'] ==
                              true) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _Glass.accentAmber.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _Glass.accentAmber.withValues(
                                    alpha: 0.40,
                                  ),
                                  width: 0.8,
                                ),
                              ),
                              child: const Text(
                                'Walk-in',
                                style: TextStyle(
                                  color: _Glass.accentAmber,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (customerId.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Customer ID: $customerId',
                          style: const TextStyle(
                            color: _Glass.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.10),
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
                      fontSize: 12,
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
                style: const TextStyle(
                  color: _Glass.textSecondary,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Builder(
                builder: (context) {
                  final isWalkIn =
                      (doc.data() as Map<String, dynamic>)['walk_in'] == true;
                  if (isWalkIn) {
                    final fileNames = products
                        .map((p) => p['design_file_name']?.toString() ?? '')
                        .where((n) => n.isNotEmpty)
                        .toList();
                    if (fileNames.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: fileNames
                            .expand((n) => n.split(', '))
                            .map(
                              (name) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _Glass.accentBlue.withValues(
                                    alpha: 0.10,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _Glass.accentBlue.withValues(
                                      alpha: 0.28,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.attach_file_rounded,
                                      size: 11,
                                      color: _Glass.accentBlue,
                                    ),
                                    const SizedBox(width: 4),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 140,
                                      ),
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          color: _Glass.accentBlue,
                                          fontSize: 11,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    );
                  }
                  return DesignFilesSection(products: products);
                },
              ),
            ],
            if (cancelReason.isNotEmpty && status == 'cancelled') ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _Glass.accentRose.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _Glass.accentRose.withValues(alpha: 0.22),
                    width: 0.9,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.cancel_outlined,
                      size: 13,
                      color: _Glass.accentRose,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Cancelled: $cancelReason',
                        style: const TextStyle(
                          color: _Glass.accentRose,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _InfoChip(
                        'Total',
                        '₱${total.toStringAsFixed(2)}',
                        _Glass.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      _InfoChip(
                        'Paid',
                        '₱${paid.toStringAsFixed(2)}',
                        _Glass.accentEmerald,
                      ),
                      const SizedBox(width: 10),
                      _InfoChip(
                        fullyPaid ? 'Fully Paid' : 'Balance',
                        fullyPaid ? '—' : '₱${remaining.toStringAsFixed(2)}',
                        fullyPaid ? _Glass.accentEmerald : _amber,
                        bold: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Builder(
                  builder: (ctx) => GestureDetector(
                    onTap: () async {
                      String? invId = invoiceId;
                      if (invId == null) {
                        final orderSnap = await FirebaseFirestore.instance
                            .collection('Orders')
                            .doc(doc.id)
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
                          const SnackBar(
                            content: Text('No invoice for this order'),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: _Glass.glass(radius: 99),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 15,
                            color: _navyBlue.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'View Invoice',
                            style: TextStyle(
                              color: _Glass.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
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
      ),
    );
  }
}

// =============================================================================
// _InfoChip
// =============================================================================
class _InfoChip extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool bold;

  const _InfoChip(this.label, this.value, this.color, {this.bold = false});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: _Glass.textMuted,
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
// _WalkInDesignFile — model for files in the walk-in dialog
// =============================================================================
class _WalkInDesignFile {
  final String name;
  final Uint8List? bytes;
  _WalkInDesignFile({required this.name, this.bytes});
}

// =============================================================================
// _WalkInItem model — aligned with CustomerOrderScreen CartItem logic
// =============================================================================
class _WalkInItem {
  final String productDocId;
  final Map<String, dynamic> productData;
  int qty;
  String notes;
  double? widthFt;
  double? heightFt;
  String? material;
  String? designFileUrl;
  String? designFileName;
  List<Map<String, dynamic>> selectedServices;

  _WalkInItem({
    required this.productDocId,
    required this.productData,
    required this.qty,
    required this.notes,
    this.widthFt,
    this.heightFt,
    this.material,
    this.designFileUrl,
    this.designFileName,
    this.selectedServices = const [],
  });

  String get pricingUnit => productData['pricing_unit']?.toString() ?? '';

  bool get needsSize => pricingUnit == 'per_sqft' || pricingUnit == 'per_sqin';

  bool get isSqIn => pricingUnit == 'per_sqin';

  int get pricingQty => (productData['pricing_qty'] as num?)?.toInt() ?? 100;

  double get underMinSurcharge =>
      (productData['under_min_surcharge'] as num?)?.toDouble() ?? 0;

  int get minQty => (productData['min_quantity'] as num?)?.toInt() ?? 1;

  double get unitPrice {
    if (material != null) {
      final vp = productData['variant_prices'] as Map?;
      if (vp != null) {
        final override = vp[material];
        if (override != null) return (override as num).toDouble();
      }
    }
    return (productData['price'] as num?)?.toDouble() ?? 0;
  }

  double _calcUnit(double price) {
    if (pricingUnit == 'per_sqin') {
      return price * (widthFt ?? 1) * (heightFt ?? 1) * 144 * qty;
    }
    if (needsSize) return price * (widthFt ?? 1) * (heightFt ?? 1) * qty;
    return price * qty;
  }

  double get subtotal {
    double total = _calcUnit(unitPrice);
    for (final svc in selectedServices) {
      final sp = (svc['price'] as num?)?.toDouble() ?? 0;
      total += _calcUnit(sp);
    }
    if (underMinSurcharge > 0 && qty < minQty) total += underMinSurcharge;
    return total;
  }
}

// =============================================================================
// _AddWalkInJobDialog — the outer form (customer info, product list, payment)
// =============================================================================
class _AddWalkInJobDialog extends StatefulWidget {
  const _AddWalkInJobDialog();

  @override
  State<_AddWalkInJobDialog> createState() => _AddWalkInJobDialogState();
}

class _AddWalkInJobDialogState extends State<_AddWalkInJobDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _paidCtrl = TextEditingController(text: '0');

  String _paymentMethod = 'cash';
  bool _submitting = false;
  final List<_WalkInItem> _items = [];
  List<QueryDocumentSnapshot> _products = [];
  bool _loadingProducts = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final snap = await FirebaseFirestore.instance.collection('Products').get();
    if (mounted) {
      setState(() {
        _products = snap.docs;
        _loadingProducts = false;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    _paidCtrl.dispose();
    super.dispose();
  }

  double get _total => _items.fold(0, (s, i) => s + i.subtotal);

  int get _turnaround {
    if (_items.isEmpty) return 1;
    final products = _items
        .map(
          (item) => {
            'category': item.productData['category']?.toString() ?? '',
            'qty': item.qty,
            if (item.widthFt != null) 'width_ft': item.widthFt,
            if (item.heightFt != null) 'height_ft': item.heightFt,
          },
        )
        .toList();
    return TurnaroundService.computeOrderDays(products);
  }

  Future<String> _nextId(String counter, String prefix) async {
    final ref = FirebaseFirestore.instance.collection('Counters').doc(counter);
    return FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final next = ((snap.data()?['last_id'] as int?) ?? 0) + 1;
      tx.set(ref, {'last_id': next});
      return '$prefix${next.toString().padLeft(4, '0')}';
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one product.')),
      );
      return;
    }
    final paidAmount = double.tryParse(_paidCtrl.text.trim()) ?? 0.0;
    final total = _total;
    final remaining = (total - paidAmount).clamp(0.0, double.infinity);
    final fullyPaid = remaining < 0.01;
    final customerName = _nameCtrl.text.trim();
    final customerEmail = _emailCtrl.text.trim();
    final turnaroundDays = _turnaround;
    final estimatedCompletion = DateTime.now().add(
      Duration(days: turnaroundDays),
    );

    setState(() => _submitting = true);

    try {
      final orderId = await _nextId('order', 'ORD-');
      final invoiceId = await _nextId('invoice', 'INV-');
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      final now = FieldValue.serverTimestamp();

      final products = _items
          .map(
            (item) => {
              'product_id':
                  item.productData['product_id']?.toString() ??
                  item.productDocId,
              'name': item.productData['product_name']?.toString() ?? '—',
              'category': item.productData['category']?.toString() ?? '',
              'qty': item.qty,
              'unit_price': item.unitPrice,
              'pricing_unit': item.pricingUnit,
              'price': item.subtotal,
              'notes': item.notes,
              if (item.widthFt != null) 'width_ft': item.widthFt,
              if (item.heightFt != null) 'height_ft': item.heightFt,
              if (item.material != null) 'material': item.material,
              if (item.widthFt != null && item.heightFt != null)
                'size_label': item.isSqIn
                    ? '${(item.widthFt! * 12).toStringAsFixed(0)}in × ${(item.heightFt! * 12).toStringAsFixed(0)}in'
                    : '${item.widthFt}ft × ${item.heightFt}ft',
              if (item.selectedServices.isNotEmpty)
                'selected_services': item.selectedServices,
              'walk_in': true,
              if (item.designFileUrl != null)
                'design_file_url': item.designFileUrl,
              if (item.designFileName != null)
                'design_file_name': item.designFileName,
            },
          )
          .toList();

      final orderRef = db.collection('Orders').doc(orderId);
      batch.set(orderRef, {
        'order_id': orderId,
        'customer_uid': '',
        'customer_id': '',
        'customer_name': customerName,
        'customer_email': customerEmail,
        'status': 'pending',
        'products': products,
        'total_price': total,
        'amount_paid': paidAmount,
        'remaining_balance': remaining,
        'payment_status': fullyPaid
            ? 'paid'
            : (paidAmount > 0 ? 'partial' : 'unpaid'),
        'payment_method': _paymentMethod,
        'turnaround_days': turnaroundDays,
        'estimated_completion': Timestamp.fromDate(estimatedCompletion),
        'shipping': 'pickup',
        'invoice_id': invoiceId,
        'walk_in': true,
        'has_review': false,
        'notes': _notesCtrl.text.trim(),
        'created_at': now,
      });

      final queueRef = db.collection('Order_Queue').doc();
      batch.set(queueRef, {
        'order_id': orderId,
        'customer_uid': '',
        'customer_id': '',
        'customer_name': customerName,
        'job_status': 'pending',
        'turnaround_days': turnaroundDays,
        'estimated_completion': Timestamp.fromDate(estimatedCompletion),
        'products': products,
        'total_price': total,
        'walk_in': true,
        'notes': _notesCtrl.text.trim(),
        'created_at': now,
      });

      final invoiceRef = db.collection('Invoices').doc(invoiceId);
      batch.set(invoiceRef, {
        'invoice_id': invoiceId,
        'order_id': orderId,
        'customer_name': customerName,
        'customer_email': customerEmail,
        'customer_id': '',
        'issued_date': now,
        'items': products,
        'total_amount': total,
        'amount_paid': paidAmount,
        'remaining_balance': remaining,
        'payment_method': _paymentMethod,
        'transaction_ref': '',
        'walk_in': true,
      });

      await batch.commit();

      if (paidAmount > 0) {
        await db.collection('Sales_Records').add({
          'order_id': orderId,
          'customer_name': customerName,
          'customer_id': '',
          'payment_type': fullyPaid ? 'full' : 'downpayment',
          'payment_method': _paymentMethod,
          'sale_amount': paidAmount,
          'order_total': total,
          'walk_in': true,
          'sale_date': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => InvoiceScreen(invoiceId: invoiceId)),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: _Glass.accentRose,
          ),
        );
      }
    }
  }

  void _updateDefaultDownpayment() {
    final min = (_total * 0.5);
    final current = double.tryParse(_paidCtrl.text.trim()) ?? 0;
    if (current < min) _paidCtrl.text = min.toStringAsFixed(2);
  }

  void _showAddProductDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _WalkInCustomizeDialog(
        products: _products,
        onAdd: (item) {
          if (mounted) {
            setState(() {
              _items.add(item);
              _updateDefaultDownpayment();
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _Glass.surface,
      elevation: 32,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: _Glass.borderMid, width: 1),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Title bar ──────────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _navyBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.add_box_outlined,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'New Walk-In Job Order',
                              style: TextStyle(
                                color: _Glass.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Walk-in customer · cash or GCash',
                              style: TextStyle(
                                color: _Glass.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _submitting
                            ? null
                            : () => Navigator.pop(context),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _Glass.surfaceThin,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _Glass.borderMid,
                              width: 0.9,
                            ),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: _Glass.textMuted,
                            size: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(
                    color: _Glass.borderMid,
                    height: 24,
                    thickness: 0.8,
                  ),

                  // ── Scrollable body ────────────────────────────────────
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _GlassFormField(
                            controller: _nameCtrl,
                            hint: 'Customer Name *',
                            icon: Icons.person_outline,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                          const SizedBox(height: 10),
                          _GlassFormField(
                            controller: _emailCtrl,
                            hint: 'Customer Email (optional)',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 20),

                          // ── Products header ──────────────────────────
                          Row(
                            children: [
                              const Text(
                                'Products',
                                style: TextStyle(
                                  color: _Glass.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: _loadingProducts
                                    ? null
                                    : _showAddProductDialog,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 7,
                                  ),
                                  decoration: _Glass.solidPill(
                                    _navyBlue,
                                    glow: true,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.add_rounded,
                                        size: 13,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _loadingProducts
                                            ? 'Loading…'
                                            : 'Add Product',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          if (_items.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: _Glass.glass(radius: 10),
                              child: const Center(
                                child: Text(
                                  'No products added yet.',
                                  style: TextStyle(
                                    color: _Glass.textMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            )
                          else
                            ..._items.asMap().entries.map((e) {
                              final i = e.key;
                              final item = e.value;
                              final svcNames = item.selectedServices
                                  .map((s) => s['name']?.toString() ?? '')
                                  .where((n) => n.isNotEmpty)
                                  .join(', ');
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: _Glass.glass(radius: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.productData['product_name']
                                                    ?.toString() ??
                                                '—',
                                            style: const TextStyle(
                                              color: _Glass.textPrimary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Text(
                                            [
                                              if (item.needsSize &&
                                                  item.widthFt != null &&
                                                  item.heightFt != null)
                                                item.isSqIn
                                                    ? '${(item.widthFt! * 12).toStringAsFixed(0)}in × ${(item.heightFt! * 12).toStringAsFixed(0)}in'
                                                    : '${item.widthFt}ft × ${item.heightFt}ft',
                                              if (item.material != null)
                                                item.material!,
                                              '₱${item.unitPrice.toStringAsFixed(2)} × ${item.qty} = ₱${item.subtotal.toStringAsFixed(2)}',
                                            ].join(' · '),
                                            style: const TextStyle(
                                              color: _Glass.textMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (svcNames.isNotEmpty)
                                            Text(
                                              'Add-ons: $svcNames',
                                              style: const TextStyle(
                                                color: _Glass.accentBlue,
                                                fontSize: 11,
                                              ),
                                            ),
                                          if (item.notes.isNotEmpty)
                                            Text(
                                              item.notes,
                                              style: const TextStyle(
                                                color: _Glass.textMuted,
                                                fontSize: 11,
                                              ),
                                            ),
                                          if (item.designFileName != null)
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.attach_file_rounded,
                                                  size: 11,
                                                  color: _Glass.accentBlue,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    item.designFileName!,
                                                    style: const TextStyle(
                                                      color: _Glass.accentBlue,
                                                      fontSize: 11,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () =>
                                          setState(() => _items.removeAt(i)),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: _Glass.accentRose.withValues(
                                            alpha: 0.08,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.remove_circle_outline,
                                          color: _Glass.accentRose,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),

                          if (_items.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: _navyBlue.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _Glass.borderMid,
                                  width: 0.9,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'Est. ~$_turnaround day${_turnaround == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                      color: _Glass.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Total: ₱${_total.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: _Glass.textPrimary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),

                          // ── Payment ──────────────────────────────────
                          const Text(
                            'Payment',
                            style: TextStyle(
                              color: _Glass.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _payMethodChip(
                                'cash',
                                'Cash',
                                Icons.payments_outlined,
                              ),
                              const SizedBox(width: 8),
                              _payMethodChip(
                                'gcash',
                                'GCash',
                                Icons.phone_android_outlined,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _GlassFormField(
                            controller: _paidCtrl,
                            hint: 'Amount Paid (₱) * — min. 50% downpayment',
                            icon: Icons.monetization_on_outlined,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (v) {
                              final n = double.tryParse(v?.trim() ?? '');
                              if (n == null) return 'Enter a valid amount';
                              if (n < 0) return 'Cannot be negative';
                              if (_items.isNotEmpty) {
                                final minDown = _total * 0.5;
                                if (n < minDown - 0.01) {
                                  return 'Minimum 50% downpayment required: ₱${minDown.toStringAsFixed(2)}';
                                }
                                if (n > _total + 0.01) {
                                  return 'Cannot exceed total ₱${_total.toStringAsFixed(2)}';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          _GlassFormField(
                            controller: _notesCtrl,
                            hint: 'Order Notes (optional)',
                            icon: Icons.notes_outlined,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Action buttons ─────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _submitting
                              ? null
                              : () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: _Glass.glass(radius: 12),
                            child: const Center(
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: _Glass.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: _submitting ? null : _submit,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: _Glass.solidPill(_navyBlue, glow: true),
                            child: Center(
                              child: _submitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white70,
                                      ),
                                    )
                                  : const Text(
                                      'Create Job Order',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _payMethodChip(String value, String label, IconData icon) {
    final active = _paymentMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: active
            ? _Glass.solidPill(_navyBlue)
            : BoxDecoration(
                color: _Glass.surfaceThin,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _Glass.borderMid, width: 0.9),
              ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? Colors.white : _Glass.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : _Glass.textSecondary,
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _GlassFormField
// =============================================================================
class _GlassFormField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;

  const _GlassFormField({
    required this.controller,
    required this.hint,
    this.icon,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    validator: validator,
    maxLines: maxLines,
    style: const TextStyle(color: _Glass.textPrimary, fontSize: 13),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _Glass.textMuted, fontSize: 13),
      prefixIcon: icon != null
          ? Icon(icon, size: 16, color: _Glass.textMuted)
          : null,
      filled: true,
      fillColor: _Glass.surfaceThin,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _Glass.borderMid, width: 0.9),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: _navyBlue.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _Glass.accentRose),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _Glass.accentRose),
      ),
      errorStyle: const TextStyle(fontSize: 10, color: _Glass.accentRose),
    ),
  );
}

// =============================================================================
// _WalkInCustomizeDialog — large dialog, two-step: pick product → customize
// Fully mirrors CustomerOrderScreen logic:
//   • pricing_unit: per_sqft, per_sqin, per_qty, per_piece
//   • material_options from product data (no hardcoded map)
//   • variant_prices overrides
//   • additional_services
//   • stock availability via RawMaterials + bill_of_materials
//   • under_min_surcharge
//   • design file upload
// =============================================================================
class _WalkInCustomizeDialog extends StatefulWidget {
  final List<QueryDocumentSnapshot> products;
  final ValueChanged<_WalkInItem> onAdd;

  const _WalkInCustomizeDialog({required this.products, required this.onAdd});

  @override
  State<_WalkInCustomizeDialog> createState() => _WalkInCustomizeDialogState();
}

class _WalkInCustomizeDialogState extends State<_WalkInCustomizeDialog> {
  // Step 0 = product list, Step 1 = customize
  int _step = 0;
  QueryDocumentSnapshot? _selected;

  // ── Filters ─────────────────────────────────────────────────────────────
  String _search = '';
  String? _category;
  final _searchCtrl = TextEditingController();

  // ── Customize state (mirrors CustomerOrderScreen) ────────────────────────
  int _qty = 1;
  String _sizePreset = '2×3 ft';
  double _widthFt = 2;
  double _heightFt = 3;
  String? _material;
  final Set<String> _selectedServices = {};
  final _widthCtrl = TextEditingController(text: '2');
  final _heightCtrl = TextEditingController(text: '3');
  final _notesCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');

  // Stock availability
  Map<String, double> _stockMap = {};
  bool _availabilityLoaded = false;
  double? _maxOrderable;

  // Design files
  final List<_WalkInDesignFile> _files = [];
  static const int _maxFileMB = 25;

  // ── Size presets ─────────────────────────────────────────────────────────
  static const _sizePresets = [
    '2×3 ft',
    '3×4 ft',
    '4×6 ft',
    '4×8 ft',
    '5×10 ft',
    'Custom',
  ];
  static const _presetDims = {
    '2×3 ft': (2.0, 3.0),
    '3×4 ft': (3.0, 4.0),
    '4×6 ft': (4.0, 6.0),
    '4×8 ft': (4.0, 8.0),
    '5×10 ft': (5.0, 10.0),
  };
  static const _sizePresetsIn = [
    '4×4 in',
    '4×6 in',
    '6×8 in',
    '8×10 in',
    '10×12 in',
    'Custom',
  ];
  static final _presetDimsIn = <String, (double, double)>{
    '4×4 in': (4 / 12.0, 4 / 12.0),
    '4×6 in': (4 / 12.0, 6 / 12.0),
    '6×8 in': (6 / 12.0, 8 / 12.0),
    '8×10 in': (8 / 12.0, 10 / 12.0),
    '10×12 in': (10 / 12.0, 12 / 12.0),
  };

  static const _categories = [
    'Large Format & Signage',
    'Stickers & Labels',
    'Photo & Card Prints',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    _notesCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  // ── Product data accessors (mirrors CustomerOrderScreen) ─────────────────

  Map<String, dynamic>? get _data => _selected?.data() as Map<String, dynamic>?;

  String get _pricingUnit => _data?['pricing_unit']?.toString() ?? '';

  bool get _needsSize =>
      _pricingUnit == 'per_sqft' || _pricingUnit == 'per_sqin';

  bool get _isSqIn => _pricingUnit == 'per_sqin';

  int get _minQty => (_data?['min_quantity'] as num?)?.toInt() ?? 1;

  int get _pricingQty => (_data?['pricing_qty'] as num?)?.toInt() ?? 100;

  double get _underMinSurcharge =>
      (_data?['under_min_surcharge'] as num?)?.toDouble() ?? 0;

  bool get _hasSurcharge => _underMinSurcharge > 0 && _qty < _minQty;

  List<String> get _materialList {
    final raw = _data?['material_options'] as List?;
    if (raw != null && raw.isNotEmpty) {
      return raw.map((e) => e.toString()).toList();
    }
    return [];
  }

  List<Map<String, dynamic>> get _additionalServicesList {
    final raw = _data?['additional_services'] as List?;
    if (raw == null) return [];
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  double get _effectiveBasePrice {
    if (_material != null) {
      final vp = _data?['variant_prices'] as Map?;
      if (vp != null) {
        final override = vp[_material];
        if (override != null) return (override as num).toDouble();
      }
    }
    return (_data?['price'] as num?)?.toDouble() ?? 0;
  }

  double _calcUnit(double price) {
    if (_pricingUnit == 'per_sqin') {
      return price * _widthFt * _heightFt * 144 * _qty;
    }
    if (_needsSize) return price * _widthFt * _heightFt * _qty;
    return price * _qty;
  }

  double get _lineSubtotal {
    double total = _calcUnit(_effectiveBasePrice);
    for (final svc in _additionalServicesList) {
      final name = svc['name']?.toString() ?? '';
      if (_selectedServices.contains(name)) {
        final sp = (svc['price'] as num?)?.toDouble() ?? 0;
        total += _calcUnit(sp);
      }
    }
    if (_hasSurcharge) total += _underMinSurcharge;
    return total;
  }

  bool get _sizeIsValid {
    if (!_needsSize) return true;
    final cat = (_data?['category']?.toString() ?? '').toLowerCase();
    if (!cat.contains('large format')) return true;
    return ((_widthFt >= 3 && _heightFt >= 2) ||
        (_widthFt >= 2 && _heightFt >= 3));
  }

  static String _fmtStock(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.abs() < 1 ? v.toStringAsFixed(3) : v.toStringAsFixed(2);
  }

  // ── Stock availability ───────────────────────────────────────────────────

  Future<void> _loadAvailability() async {
    if (_data == null) return;
    final bom = (_data!['bill_of_materials'] as List?) ?? [];
    if (bom.isEmpty) {
      if (mounted) setState(() => _availabilityLoaded = true);
      return;
    }
    setState(() {
      _availabilityLoaded = false;
      _maxOrderable = null;
    });
    final matIds = bom
        .map((e) => (e['material_id'] as String?) ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final stockMap = <String, double>{};
    try {
      for (final matId in matIds) {
        final doc = await FirebaseFirestore.instance
            .collection('RawMaterials')
            .doc(matId)
            .get();
        if (doc.exists) {
          stockMap[matId] =
              (doc.data()?['current_stock'] as num?)?.toDouble() ?? 0.0;
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _stockMap = stockMap;
      _availabilityLoaded = true;
      _maxOrderable = _computeMax();
    });
  }

  double? _computeMax() {
    if (_data == null) return null;
    final bom = (_data!['bill_of_materials'] as List?) ?? [];
    if (bom.isEmpty) return null;
    String resolved = _material?.trim() ?? '';
    if (resolved.isEmpty) {
      final opts = (_data!['material_options'] as List?) ?? [];
      if (opts.isNotEmpty) resolved = opts.first.toString().trim();
    }
    final applyFilter = resolved.isNotEmpty;
    double? max;
    for (final item in bom) {
      final opt = (item['for_material_option'] as String?)?.trim() ?? '';
      if (applyFilter && opt.isNotEmpty && opt != resolved) continue;
      final matId = (item['material_id'] as String?) ?? '';
      if (matId.isEmpty) continue;
      final qpu = (item['quantity_per_unit'] as num?)?.toDouble() ?? 1.0;
      if (qpu <= 0) continue;
      final fromThis = (_stockMap[matId] ?? 0.0) / qpu;
      if (max == null || fromThis < max) max = fromThis;
    }
    return max;
  }

  // ── File picking ─────────────────────────────────────────────────────────

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'psd', 'ai'],
        withData: true,
      );
      if (result == null || !mounted) return;
      final rejected = <String>[];
      setState(() {
        for (final pf in result.files) {
          if (pf.bytes == null) continue;
          final mb = pf.bytes!.lengthInBytes / (1024 * 1024);
          if (mb > _maxFileMB) {
            rejected.add('${pf.name} (${mb.toStringAsFixed(1)} MB)');
          } else {
            _files.add(_WalkInDesignFile(name: pf.name, bytes: pf.bytes));
          }
        }
      });
      if (rejected.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Skipped (>${_maxFileMB}MB): ${rejected.join(', ')}'),
            backgroundColor: Colors.orange.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File picker error: $e'),
            backgroundColor: _Glass.accentRose,
          ),
        );
      }
    }
  }

  // ── Product selection ────────────────────────────────────────────────────

  List<QueryDocumentSnapshot> get _filtered => widget.products.where((doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = (data['product_name']?.toString() ?? '').toLowerCase();
    final cat = data['category']?.toString() ?? '';
    return (_search.isEmpty || name.contains(_search.toLowerCase())) &&
        (_category == null || cat == _category);
  }).toList();

  void _selectProduct(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final mats =
        (data['material_options'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final pricingUnit = data['pricing_unit']?.toString() ?? '';
    final isSqIn = pricingUnit == 'per_sqin';
    final minQty = (data['min_quantity'] as num?)?.toInt() ?? 1;

    setState(() {
      _selected = doc;
      _step = 1;
      _qty = minQty;
      _qtyCtrl.text = '$_qty';
      _material = mats.isNotEmpty ? mats.first : null;
      _selectedServices.clear();
      _files.clear();
      _notesCtrl.clear();
      _availabilityLoaded = false;
      _maxOrderable = null;
      _stockMap = {};

      // Size defaults
      if (isSqIn) {
        _widthFt = 4 / 12.0;
        _heightFt = 4 / 12.0;
        _widthCtrl.text = '4';
        _heightCtrl.text = '4';
        _sizePreset = '4×4 in';
      } else {
        _widthFt = 2;
        _heightFt = 3;
        _widthCtrl.text = '2';
        _heightCtrl.text = '3';
        _sizePreset = '2×3 ft';
      }
    });

    _loadAvailability();
  }

  // ── Add to order ─────────────────────────────────────────────────────────

  void _addToOrder() {
    if (_needsSize && !_sizeIsValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimum tarpaulin size is 2×3 ft (or 3×2 ft).'),
          backgroundColor: _Glass.accentRose,
        ),
      );
      return;
    }
    if (_materialList.isNotEmpty && _material == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a variant.')));
      return;
    }
    if (_files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload at least one design file.'),
        ),
      );
      return;
    }
    if (_maxOrderable != null) {
      final effQty = _needsSize ? _widthFt * _heightFt * _qty : _qty.toDouble();
      if (effQty > _maxOrderable!) {
        final unit = _needsSize ? 'sq ft' : 'pcs';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Insufficient stock. Only ${_fmtStock(_maxOrderable!)} $unit available.',
            ),
            backgroundColor: _Glass.accentRose,
          ),
        );
        return;
      }
    }

    final selectedSvcList = _additionalServicesList
        .where((s) => _selectedServices.contains(s['name']?.toString()))
        .toList();

    widget.onAdd(
      _WalkInItem(
        productDocId: _selected!.id,
        productData: _selected!.data() as Map<String, dynamic>,
        qty: _qty,
        notes: _notesCtrl.text.trim(),
        widthFt: _needsSize ? _widthFt : null,
        heightFt: _needsSize ? _heightFt : null,
        material: _material,
        designFileUrl: null,
        designFileName: _files.isNotEmpty
            ? _files.map((f) => f.name).join(', ')
            : null,
        selectedServices: selectedSvcList,
      ),
    );
    Navigator.pop(context);
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: _Glass.surface,
      elevation: 40,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: _Glass.borderMid, width: 1),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: screenSize.height * 0.90,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Top bar ───────────────────────────────────────────────
              _buildDialogTopBar(),
              // ── Content ───────────────────────────────────────────────
              Flexible(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(0.04, 0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: anim,
                              curve: Curves.easeOut,
                            ),
                          ),
                      child: child,
                    ),
                  ),
                  child: _step == 0
                      ? _buildProductList()
                      : _buildCustomiseForm(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Dialog top bar ───────────────────────────────────────────────────────

  Widget _buildDialogTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      decoration: BoxDecoration(
        color: _Glass.surface,
        border: Border(bottom: BorderSide(color: _Glass.borderDim, width: 1)),
      ),
      child: Row(
        children: [
          // Back / close button
          GestureDetector(
            onTap: () {
              if (_step == 1) {
                setState(() => _step = 0);
              } else {
                Navigator.pop(context);
              }
            },
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _Glass.surfaceThin,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _Glass.borderMid, width: 0.9),
              ),
              child: Icon(
                _step == 1
                    ? Icons.arrow_back_ios_new_rounded
                    : Icons.close_rounded,
                size: 14,
                color: _Glass.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _step == 0
                      ? 'Select Product'
                      : (_data?['product_name']?.toString() ?? 'Customize'),
                  style: const TextStyle(
                    color: _Glass.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  _step == 0
                      ? 'Step 1 of 2 — choose a product'
                      : 'Step 2 of 2 — set options & upload files',
                  style: const TextStyle(color: _Glass.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          // Step dots
          Row(
            children: List.generate(2, (i) {
              final active = _step == i;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(left: 6),
                width: active ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: active ? _navyBlue : _Glass.borderMid,
                  borderRadius: BorderRadius.circular(99),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Step 0: Product list ─────────────────────────────────────────────────

  Widget _buildProductList() {
    final filtered = _filtered;
    return Column(
      key: const ValueKey('step0'),
      children: [
        // Search + filter
        Container(
          color: _Glass.surface,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: _Glass.surfaceThin,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _Glass.borderMid, width: 0.8),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v),
                  style: const TextStyle(
                    color: _Glass.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Search products…',
                    hintStyle: TextStyle(color: _Glass.textMuted, fontSize: 13),
                    prefixIcon: Icon(
                      Icons.search,
                      color: _Glass.textMuted,
                      size: 18,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _catChip(
                      'All',
                      _category == null,
                      () => setState(() => _category = null),
                    ),
                    ..._categories.map(
                      (c) => _catChip(
                        c,
                        _category == c,
                        () => setState(
                          () => _category = _category == c ? null : c,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: _Glass.borderDim),
        // Product list
        Flexible(
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                    'No products found.',
                    style: TextStyle(color: _Glass.textMuted, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final doc = filtered[i];
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['product_name']?.toString() ?? '—';
                    final price = (data['price'] as num?)?.toDouble() ?? 0;
                    final unit = data['pricing_unit']?.toString() ?? '';
                    final imageUrl = data['image_url']?.toString() ?? '';
                    final cat = data['category']?.toString() ?? '';
                    final desc = data['description']?.toString() ?? '';
                    final pricingQty =
                        (data['pricing_qty'] as num?)?.toInt() ?? 100;

                    String unitLabel;
                    switch (unit) {
                      case 'per_sqft':
                        unitLabel = '/ sq ft';
                        break;
                      case 'per_sqin':
                        unitLabel = '/ sq in';
                        break;
                      case 'per_qty':
                        unitLabel = '/ $pricingQty pcs';
                        break;
                      default:
                        unitLabel = '/ piece';
                    }

                    return GestureDetector(
                      onTap: () => _selectProduct(doc),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: _Glass.glass(radius: 14),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(14),
                              ),
                              child: SizedBox(
                                width: 76,
                                height: 76,
                                child: imageUrl.isNotEmpty
                                    ? Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _imgPlaceholder(),
                                      )
                                    : _imgPlaceholder(),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        color: _Glass.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (cat.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _navyBlue.withValues(
                                            alpha: 0.07,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          cat,
                                          style: const TextStyle(
                                            color: _navyBlue,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (desc.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        desc,
                                        style: const TextStyle(
                                          color: _Glass.textMuted,
                                          fontSize: 11,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(0, 0, 14, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₱${price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: _Glass.textPrimary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    unitLabel,
                                    style: const TextStyle(
                                      color: _Glass.textMuted,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: _navyBlue.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 14,
                                      color: _navyBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Step 1: Customize form ───────────────────────────────────────────────

  Widget _buildCustomiseForm() {
    final isArea = _needsSize;
    final effQty = isArea ? _widthFt * _heightFt * _qty : _qty.toDouble();
    final unitLabel = isArea ? 'sq ft' : 'pcs';
    final hasStock = _availabilityLoaded && _maxOrderable != null;
    final stockOk = !hasStock || effQty <= _maxOrderable!;

    return Column(
      key: const ValueKey('step1'),
      children: [
        // Scrollable content
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Product info header ────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((_data?['image_url']?.toString() ?? '').isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: Image.network(
                            _data!['image_url'],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _imgPlaceholder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _data?['product_name']?.toString() ?? '—',
                            style: const TextStyle(
                              color: _Glass.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if ((_data?['category']?.toString() ?? '').isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _navyBlue.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _data!['category'],
                                style: const TextStyle(
                                  color: _navyBlue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            _pricingUnit == 'per_qty'
                                ? '₱${_effectiveBasePrice.toStringAsFixed(2)} per $_pricingQty pcs'
                                : _pricingUnit == 'per_sqin'
                                ? '₱${_effectiveBasePrice.toStringAsFixed(2)} / sq in'
                                : _pricingUnit == 'per_sqft'
                                ? '₱${_effectiveBasePrice.toStringAsFixed(2)} / sq ft'
                                : '₱${_effectiveBasePrice.toStringAsFixed(2)} / piece',
                            style: const TextStyle(
                              color: _Glass.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: _Glass.borderDim),
                const SizedBox(height: 16),

                // ── Size inputs (per_sqft or per_sqin) ────────────────
                if (_needsSize) ...[
                  _sectionLabel(
                    _isSqIn ? 'Size (in inches)' : 'Size (in feet)',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (_isSqIn ? _sizePresetsIn : _sizePresets).map((
                      p,
                    ) {
                      final dims = _isSqIn ? _presetDimsIn[p] : _presetDims[p];
                      return _selChip(p, _sizePreset == p, () {
                        setState(() {
                          _sizePreset = p;
                          if (dims != null) {
                            _widthFt = dims.$1;
                            _heightFt = dims.$2;
                            _widthCtrl.text = _isSqIn
                                ? (dims.$1 * 12).toStringAsFixed(0)
                                : dims.$1.toString();
                            _heightCtrl.text = _isSqIn
                                ? (dims.$2 * 12).toStringAsFixed(0)
                                : dims.$2.toString();
                          }
                        });
                      });
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _dimField(
                          _isSqIn ? 'Width (in)' : 'Width (ft)',
                          _widthCtrl,
                          (v) {
                            final d = double.tryParse(v);
                            if (d != null && d > 0) {
                              setState(() {
                                _widthFt = _isSqIn ? d / 12.0 : d;
                                _sizePreset = 'Custom';
                              });
                            }
                          },
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '×',
                          style: TextStyle(
                            color: _Glass.textMuted,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _dimField(
                          _isSqIn ? 'Height (in)' : 'Height (ft)',
                          _heightCtrl,
                          (v) {
                            final d = double.tryParse(v);
                            if (d != null && d > 0) {
                              setState(() {
                                _heightFt = _isSqIn ? d / 12.0 : d;
                                _sizePreset = 'Custom';
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  if (!_isSqIn &&
                      (_data?['category']?.toString() ?? '')
                          .toLowerCase()
                          .contains('large format') &&
                      !_sizeIsValid) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: const [
                        Icon(
                          Icons.info_outline,
                          color: _Glass.accentAmber,
                          size: 13,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Minimum size is 2×3 ft',
                          style: TextStyle(
                            color: _Glass.accentAmber,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                ],

                // ── Variant (from material_options field) ────
                if (_materialList.isNotEmpty) ...[
                  _sectionLabel('Variant'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _materialList
                        .map(
                          (m) => _selChip(m, _material == m, () {
                            setState(() {
                              _material = m;
                              if (_availabilityLoaded) {
                                _maxOrderable = _computeMax();
                              }
                            });
                          }),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Stock availability ─────────────────────────────────
                if (_availabilityLoaded && _maxOrderable != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: stockOk
                          ? _Glass.accentEmerald.withValues(alpha: 0.08)
                          : _Glass.accentRose.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: stockOk
                            ? _Glass.accentEmerald.withValues(alpha: 0.30)
                            : _Glass.accentRose.withValues(alpha: 0.30),
                        width: 0.9,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          stockOk
                              ? Icons.inventory_2_outlined
                              : Icons.warning_amber_outlined,
                          color: stockOk
                              ? _Glass.accentEmerald
                              : _Glass.accentRose,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          stockOk
                              ? 'Available: ${_fmtStock(_maxOrderable!)} $unitLabel'
                              : 'Insufficient — only ${_fmtStock(_maxOrderable!)} $unitLabel available',
                          style: TextStyle(
                            color: stockOk
                                ? _Glass.accentEmerald
                                : _Glass.accentRose,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Quantity ───────────────────────────────────────────
                _sectionLabel(
                  _pricingUnit == 'per_qty'
                      ? 'Quantity (units of $_pricingQty pcs)'
                      : 'Quantity',
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: _Glass.glass(radius: 14),
                  child: Row(
                    children: [
                      _qtyBtn(Icons.remove_rounded, () {
                        final hardMin = _underMinSurcharge > 0 ? 1 : _minQty;
                        if (_qty > hardMin) {
                          setState(() {
                            _qty--;
                            _qtyCtrl.text = '$_qty';
                          });
                        }
                      }),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 60,
                        child: TextField(
                          controller: _qtyCtrl,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            color: _Glass.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          onChanged: (v) {
                            final n = int.tryParse(v);
                            if (n != null && n > 0) {
                              setState(() => _qty = n);
                            }
                          },
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _qtyBtn(Icons.add_rounded, () {
                        setState(() {
                          _qty++;
                          _qtyCtrl.text = '$_qty';
                        });
                      }),
                      const Spacer(),
                      if (_hasSurcharge) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _Glass.accentAmber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: _Glass.accentAmber.withValues(alpha: 0.40),
                            ),
                          ),
                          child: Text(
                            '+₱${_underMinSurcharge.toStringAsFixed(0)} surcharge',
                            style: const TextStyle(
                              color: _Glass.accentAmber,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        '₱${_lineSubtotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: _navyBlue,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _pricingUnit == 'per_qty'
                      ? 'min. $_minQty unit = ${_minQty * _pricingQty} pcs'
                      : 'min. $_minQty',
                  style: const TextStyle(color: _Glass.textMuted, fontSize: 11),
                ),
                const SizedBox(height: 20),

                // ── Add-on services ────────────────────────────────────
                if (_additionalServicesList.isNotEmpty) ...[
                  _sectionLabel('Add-on Services'),
                  const SizedBox(height: 4),
                  const Text(
                    'Optional — select any extras you\'d like included.',
                    style: TextStyle(color: _Glass.textMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  ..._additionalServicesList.map((svc) {
                    final name = svc['name']?.toString() ?? '';
                    final price = (svc['price'] as num?)?.toDouble() ?? 0;
                    final sel = _selectedServices.contains(name);
                    final priceLabel = _pricingUnit == 'per_qty'
                        ? '+₱${price.toStringAsFixed(0)} / $_pricingQty pcs'
                        : _pricingUnit == 'per_sqin'
                        ? '+₱${price.toStringAsFixed(2)} / sq in'
                        : _pricingUnit == 'per_sqft'
                        ? '+₱${price.toStringAsFixed(2)} / sq ft'
                        : '+₱${price.toStringAsFixed(2)} / piece';

                    return GestureDetector(
                      onTap: () => setState(() {
                        if (sel) {
                          _selectedServices.remove(name);
                        } else {
                          _selectedServices.add(name);
                        }
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: sel
                              ? _navyBlue.withValues(alpha: 0.06)
                              : _Glass.surfaceThin,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel
                                ? _navyBlue.withValues(alpha: 0.45)
                                : _Glass.borderMid,
                            width: sel ? 1.3 : 0.9,
                          ),
                        ),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: sel ? _navyBlue : Colors.transparent,
                                border: Border.all(
                                  color: sel ? _navyBlue : _Glass.textMuted,
                                  width: 1.5,
                                ),
                              ),
                              child: sel
                                  ? const Icon(
                                      Icons.check,
                                      size: 12,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                name,
                                style: TextStyle(
                                  color: sel
                                      ? _Glass.textPrimary
                                      : _Glass.textSecondary,
                                  fontSize: 13,
                                  fontWeight: sel
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              priceLabel,
                              style: TextStyle(
                                color: sel ? _navyBlue : _Glass.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                ],

                // ── Design files ───────────────────────────────────────
                _sectionLabel('Design Files *'),
                const SizedBox(height: 4),
                const Text(
                  'PDF, JPG, PNG, PSD, AI — max 25 MB per file',
                  style: TextStyle(color: _Glass.textMuted, fontSize: 11),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _pickFiles,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _files.isEmpty
                          ? _Glass.surfaceThin
                          : _Glass.accentBlue.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _files.isEmpty
                            ? _Glass.borderMid
                            : _Glass.accentBlue.withValues(alpha: 0.35),
                        width: _files.isEmpty ? 0.9 : 1.2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 32,
                          color: _files.isEmpty
                              ? _Glass.textMuted
                              : _Glass.accentBlue,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _files.isEmpty
                              ? 'Tap to upload design files'
                              : 'Tap to add more files',
                          style: TextStyle(
                            color: _files.isEmpty
                                ? _Glass.textMuted
                                : _Glass.accentBlue,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_files.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ..._files.asMap().entries.map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _Glass.accentBlue.withValues(
                                    alpha: 0.07,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _Glass.accentBlue.withValues(
                                      alpha: 0.20,
                                    ),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.insert_drive_file_outlined,
                                      size: 15,
                                      color: _Glass.accentBlue,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        e.value.name,
                                        style: const TextStyle(
                                          color: _Glass.textPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => setState(
                                        () => _files.removeAt(e.key),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: _Glass.accentRose.withValues(
                                            alpha: 0.08,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close_rounded,
                                          size: 13,
                                          color: _Glass.accentRose,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Notes ─────────────────────────────────────────────
                _sectionLabel('Product Notes (optional)'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: _Glass.surfaceThin,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _Glass.borderMid, width: 0.8),
                  ),
                  child: TextField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    style: const TextStyle(
                      color: _Glass.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Specifications, special instructions…',
                      hintStyle: TextStyle(
                        color: _Glass.textMuted,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(14),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // ── Bottom action bar ────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: BoxDecoration(
            color: _Glass.surface,
            border: Border(top: BorderSide(color: _Glass.borderDim, width: 1)),
            boxShadow: const [_Glass.elevatedShadow],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Subtotal',
                      style: TextStyle(color: _Glass.textMuted, fontSize: 11),
                    ),
                    Text(
                      '₱${_lineSubtotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: _navyBlue,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '50% min: ₱${(_lineSubtotal * 0.5).toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: _Glass.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _addToOrder,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 13,
                  ),
                  decoration: _Glass.solidPill(_navyBlue, glow: true),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_shopping_cart_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Add to Order',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Shared widget helpers ────────────────────────────────────────────────

  Widget _imgPlaceholder() => Container(
    color: _Glass.surfaceThin,
    child: const Center(
      child: Icon(Icons.image_outlined, color: _Glass.textMuted, size: 24),
    ),
  );

  Widget _catChip(String label, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: active
              ? _Glass.solidPill(_navyBlue)
              : BoxDecoration(
                  color: _Glass.surfaceThin,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: _Glass.borderMid, width: 0.9),
                ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : _Glass.textSecondary,
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      );

  Widget _selChip(String label, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: active
              ? _Glass.solidPill(_navyBlue)
              : BoxDecoration(
                  color: _Glass.surfaceThin,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _Glass.borderMid, width: 0.9),
                ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : _Glass.textSecondary,
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      );

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 34,
      height: 34,
      decoration: _Glass.glass(radius: 10),
      child: Icon(icon, color: _Glass.textSecondary, size: 18),
    ),
  );

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      color: _Glass.textPrimary,
      fontSize: 13,
      fontWeight: FontWeight.w700,
    ),
  );

  Widget _dimField(
    String label,
    TextEditingController ctrl,
    ValueChanged<String> onChanged,
  ) => Container(
    decoration: BoxDecoration(
      color: _Glass.surfaceThin,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _Glass.borderMid, width: 0.8),
    ),
    child: TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: _Glass.textPrimary, fontSize: 13),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: label,
        hintStyle: const TextStyle(color: _Glass.textMuted, fontSize: 13),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    ),
  );
}

// =============================================================================
// _QueueList
// =============================================================================
class _QueueList extends StatefulWidget {
  final String jobStatus;
  const _QueueList({required this.jobStatus});

  @override
  State<_QueueList> createState() => _QueueListState();
}

class _QueueListState extends State<_QueueList> {
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('Order_Queue')
        .where('job_status', isEqualTo: widget.jobStatus);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: _navyBlue.withValues(alpha: 0.4),
              strokeWidth: 2,
            ),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Queue error: ${snap.error}',
                style: const TextStyle(color: _Glass.accentRose, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final docs = [...(snap.data?.docs ?? [])]
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
          final icon = widget.jobStatus == 'pending'
              ? Icons.queue_outlined
              : widget.jobStatus == 'cancelled'
              ? Icons.cancel_outlined
              : Icons.precision_manufacturing_outlined;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: _Glass.glass(radius: 20, elevated: true),
                  child: Icon(icon, size: 28, color: _Glass.textMuted),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.jobStatus == 'pending'
                      ? 'No pending jobs'
                      : widget.jobStatus == 'cancelled'
                      ? 'No cancelled jobs'
                      : 'No active jobs',
                  style: const TextStyle(
                    color: _Glass.textSecondary,
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
          trackVisibility: true,
          child: ListView.separated(
            controller: _scrollCtrl,
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              return _QueueCard(
                queueDocId: doc.id,
                data: data,
                position: i + 1,
              );
            },
          ),
        );
      },
    );
  }
}

// =============================================================================
// _ReadyForPickupList
// =============================================================================
class _ReadyForPickupList extends StatefulWidget {
  const _ReadyForPickupList();

  @override
  State<_ReadyForPickupList> createState() => _ReadyForPickupListState();
}

class _ReadyForPickupListState extends State<_ReadyForPickupList> {
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('Orders')
        .where('status', isEqualTo: 'ready');

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: _navyBlue.withValues(alpha: 0.4),
              strokeWidth: 2,
            ),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'Error: ${snap.error}',
              style: const TextStyle(color: _Glass.accentRose, fontSize: 12),
            ),
          );
        }

        final docs = [...(snap.data?.docs ?? [])]
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: _Glass.glass(radius: 20, elevated: true),
                  child: const Icon(
                    Icons.check_circle_outline,
                    size: 28,
                    color: _Glass.textMuted,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'No orders ready for pickup',
                  style: TextStyle(
                    color: _Glass.textSecondary,
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
          trackVisibility: true,
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _Glass.accentAmber.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _Glass.accentAmber.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: _Glass.accentAmber,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ReadyOrderCard(orderId: doc.id, data: data),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// =============================================================================
// _ReadyOrderCard
// =============================================================================
class _ReadyOrderCard extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> data;
  const _ReadyOrderCard({required this.orderId, required this.data});

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
      return '${m[d.month - 1]} ${d.day}';
    } catch (_) {
      return '—';
    }
  }

  Future<void> _markCompleted(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _Glass.surface,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _Glass.borderMid, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mark as Completed?',
                style: TextStyle(
                  color: _Glass.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mark order $orderId as completed (picked up)?',
                style: const TextStyle(
                  color: _Glass.textSecondary,
                  fontSize: 13,
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
                        horizontal: 18,
                        vertical: 9,
                      ),
                      decoration: _Glass.glass(radius: 99),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: _Glass.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      decoration: _Glass.solidPill(
                        _Glass.accentEmerald,
                        glow: true,
                      ),
                      child: const Text(
                        'Mark Completed',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;

    final db = FirebaseFirestore.instance;
    await db.collection('Orders').doc(orderId).update({'status': 'completed'});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order $orderId marked as completed'),
          backgroundColor: _Glass.accentEmerald,
        ),
      );
    }
  }

  Future<void> _viewInvoice(BuildContext context) async {
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
        const SnackBar(content: Text('No invoice yet for this order')),
      );
    }
  }

  Future<void> _openChat(BuildContext context) async {
    final customerUid = data['customer_uid']?.toString() ?? '';
    final customerName = data['customer_name']?.toString() ?? 'Customer';
    if (customerUid.isEmpty) return;

    final orderLabel = data['order_id']?.toString() ?? orderId;
    final products =
        (data['products'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final productSummary = products.isNotEmpty
        ? products
              .map((p) => '${p['name'] ?? '?'} ×${p['qty'] ?? 1}')
              .join(', ')
        : '—';
    final total = (data['total_price'] as num?)?.toDouble() ?? 0;

    final user = FirebaseAuth.instance.currentUser;
    String employeeName = user?.displayName ?? 'Employee';
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('User')
            .doc(user.uid)
            .get();
        employeeName = doc.data()?['full_name'] ?? employeeName;
      } catch (_) {}
    }

    final threadRef = FirebaseFirestore.instance
        .collection('Messages')
        .doc('chat_$customerUid');

    final msgText =
        'Regarding Order: $orderLabel\n'
        'Items: $productSummary\n'
        'Status: Ready for Pickup\n'
        'Total: ₱${total.toStringAsFixed(2)}';

    await threadRef.collection('chat').add({
      'sender_uid': user?.uid ?? 'employee',
      'sender_name': employeeName,
      'sender_role': 'employee',
      'text': msgText,
      'timestamp': FieldValue.serverTimestamp(),
    });
    await threadRef.set({
      'customer_uid': customerUid,
      'customer_name': customerName,
      'last_message': 'Re: $orderLabel — Ready for Pickup',
      'last_updated': FieldValue.serverTimestamp(),
      'unread_customer': FieldValue.increment(1),
    }, SetOptions(merge: true));

    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => Scaffold(
            backgroundColor: const Color(0xFFF7F8FA),
            body: SafeArea(
              child: ChatScreen(
                customerUid: customerUid,
                customerName: customerName,
                isEmployee: true,
                embedded: true,
                onClose: () => Navigator.pop(ctx),
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderLabel = data['order_id']?.toString() ?? orderId;
    final customer = data['customer_name']?.toString() ?? '—';
    final customerId = data['customer_id']?.toString() ?? '';
    final total = (data['total_price'] as num?)?.toDouble() ?? 0;
    final paid = (data['amount_paid'] as num?)?.toDouble() ?? 0;
    final remaining =
        (data['remaining_balance'] as num?)?.toDouble() ?? (total - paid);
    final fullyPaid = remaining < 0.01;
    final pct = total > 0 ? (paid / total).clamp(0.0, 1.0) : 1.0;
    final products =
        (data['products'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final dateStr = _fmtDate(data['created_at']);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _Glass.glass(radius: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                        orderLabel,
                        style: const TextStyle(
                          color: _Glass.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '$customer · $dateStr',
                              style: const TextStyle(
                                color: _Glass.textMuted,
                                fontSize: 12,
                              ),
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
                                color: _Glass.accentAmber.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _Glass.accentAmber.withValues(
                                    alpha: 0.40,
                                  ),
                                  width: 0.8,
                                ),
                              ),
                              child: const Text(
                                'Walk-in',
                                style: TextStyle(
                                  color: _Glass.accentAmber,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (customerId.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Customer ID: $customerId',
                          style: const TextStyle(
                            color: _Glass.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _Glass.accentEmerald.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: _Glass.accentEmerald.withValues(alpha: 0.35),
                      width: 0.8,
                    ),
                  ),
                  child: const Text(
                    'Ready',
                    style: TextStyle(
                      color: _Glass.accentEmerald,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (products.isNotEmpty)
              Text(
                products
                    .map((p) => '${p['name'] ?? '?'} ×${p['qty'] ?? 1}')
                    .join(', '),
                style: const TextStyle(
                  color: _Glass.textSecondary,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            Builder(
              builder: (_) {
                if (data['walk_in'] == true) {
                  final fileNames = products
                      .map((p) => p['design_file_name']?.toString() ?? '')
                      .where((n) => n.isNotEmpty)
                      .toList();
                  if (fileNames.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: fileNames
                          .expand((n) => n.split(', '))
                          .map(
                            (name) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _Glass.accentBlue.withValues(
                                  alpha: 0.10,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _Glass.accentBlue.withValues(
                                    alpha: 0.28,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.attach_file_rounded,
                                    size: 11,
                                    color: _Glass.accentBlue,
                                  ),
                                  const SizedBox(width: 4),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 140,
                                    ),
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        color: _Glass.accentBlue,
                                        fontSize: 11,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  );
                }
                return DesignFilesSection(products: products);
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _InfoChip(
                  'Total',
                  '₱${total.toStringAsFixed(2)}',
                  _Glass.textSecondary,
                ),
                const SizedBox(width: 10),
                _InfoChip(
                  'Paid',
                  '₱${paid.toStringAsFixed(2)}',
                  _Glass.accentEmerald,
                ),
                const SizedBox(width: 10),
                _InfoChip(
                  fullyPaid ? 'Fully Paid' : 'Balance Due',
                  fullyPaid ? '—' : '₱${remaining.toStringAsFixed(2)}',
                  fullyPaid ? _Glass.accentEmerald : _amber,
                  bold: true,
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: _Glass.borderDim,
                valueColor: AlwaysStoppedAnimation<Color>(
                  fullyPaid ? _Glass.accentEmerald : _amber,
                ),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: !fullyPaid
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: _Glass.accentAmber.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _Glass.accentAmber.withValues(alpha: 0.25),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: _Glass.accentAmber,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '₱${remaining.toStringAsFixed(2)} balance due — via POS or app payment',
                                  style: const TextStyle(
                                    color: _Glass.accentAmber,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : GestureDetector(
                          onTap: () => _markCompleted(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: _Glass.solidPill(
                              _Glass.accentEmerald,
                              glow: true,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.task_alt_rounded,
                                  size: 15,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Mark as Completed',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _viewInvoice(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: _Glass.glass(radius: 99),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      size: 18,
                      color: _Glass.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _openChat(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: _Glass.glass(radius: 99),
                    child: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 18,
                      color: _Glass.textSecondary,
                    ),
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

// =============================================================================
// _RefundPickupSection
// =============================================================================
class _RefundPickupSection extends StatelessWidget {
  final String queueDocId;
  final String orderId;
  final Map<String, dynamic> data;

  const _RefundPickupSection({
    required this.queueDocId,
    required this.orderId,
    required this.data,
  });

  Future<void> _confirmRefundPickup(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _Glass.surface,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _Glass.borderMid, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Confirm Refund Pickup?',
                style: TextStyle(
                  color: _Glass.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mark order $orderId refund as picked up by the customer? '
                'This will deduct the paid amount from sales records.',
                style: const TextStyle(
                  color: _Glass.textSecondary,
                  fontSize: 13,
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
                        horizontal: 18,
                        vertical: 9,
                      ),
                      decoration: _Glass.glass(radius: 99),
                      child: const Text(
                        'No',
                        style: TextStyle(
                          color: _Glass.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      decoration: _Glass.solidPill(
                        _Glass.accentEmerald,
                        glow: true,
                      ),
                      child: const Text(
                        'Confirm Pickup',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    final db = FirebaseFirestore.instance;
    double actualPaid = 0;
    try {
      final orderSnap = await db.collection('Orders').doc(orderId).get();
      actualPaid = (orderSnap.data()?['amount_paid'] as num?)?.toDouble() ?? 0;
    } catch (_) {}

    final batch = db.batch();
    batch.update(db.collection('Order_Queue').doc(queueDocId), {
      'refund_picked_up': true,
      'refund_picked_up_at': FieldValue.serverTimestamp(),
    });
    batch.update(db.collection('Orders').doc(orderId), {
      'refund_picked_up': true,
      'refund_picked_up_at': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    if (actualPaid > 0.01) {
      await db.collection('Sales_Records').add({
        'order_id': orderId,
        'customer_name': data['customer_name']?.toString() ?? '—',
        'customer_id': data['customer_id']?.toString() ?? '',
        'payment_type': 'refund',
        'payment_method': 'refund',
        'sale_amount': -actualPaid,
        'order_total': (data['total_price'] as num?)?.toDouble() ?? 0,
        'walk_in': data['walk_in'] ?? false,
        'refund': true,
        'cancel_reason': data['cancel_reason']?.toString() ?? '',
        'sale_date': FieldValue.serverTimestamp(),
      });
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Refund pickup confirmed for $orderId'
            '${actualPaid > 0.01 ? ' — ₱${actualPaid.toStringAsFixed(2)} deducted from sales' : ''}',
          ),
          backgroundColor: _Glass.accentEmerald,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final refundPickedUp = data['refund_picked_up'] == true;
    final amountPaid =
        (data['amount_paid'] as num?)?.toDouble() ??
        (data['total_price'] as num?)?.toDouble() ??
        0;

    if (refundPickedUp) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _Glass.accentEmerald.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _Glass.accentEmerald.withValues(alpha: 0.30),
            width: 0.9,
          ),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: 14,
              color: _Glass.accentEmerald,
            ),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Refund picked up by customer',
                style: TextStyle(
                  color: _Glass.accentEmerald,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _Glass.accentAmber.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _Glass.accentAmber.withValues(alpha: 0.30),
              width: 0.9,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.monetization_on_outlined,
                size: 14,
                color: _Glass.accentAmber,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  amountPaid > 0.01
                      ? 'Refund to be picked up — ₱${amountPaid.toStringAsFixed(2)}'
                      : 'Refund to be picked up',
                  style: const TextStyle(
                    color: _Glass.accentAmber,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => _confirmRefundPickup(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 9),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: _Glass.solidPill(_Glass.accentEmerald, glow: true),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_turned_in_outlined,
                  size: 15,
                  color: Colors.white,
                ),
                SizedBox(width: 6),
                Text(
                  'Confirm Refund Pickup',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
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
// _QueueCard
// =============================================================================
class _QueueCard extends StatelessWidget {
  final String queueDocId;
  final Map<String, dynamic> data;
  final int position;

  const _QueueCard({
    required this.queueDocId,
    required this.data,
    required this.position,
  });

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
      return '${m[d.month - 1]} ${d.day}, ${d.year} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '—';
    }
  }

  Future<void> _cancelOrder(BuildContext context) async {
    final orderId = data['order_id']?.toString();
    final customerUid = data['customer_uid']?.toString();
    if (orderId == null) return;

    String selectedReason = '';
    String customReason = '';
    bool isOther = false;
    final customCtrl = TextEditingController();

    const reasons = [
      'Customer requested cancellation',
      'Payment not received',
      'Out of stock / materials unavailable',
      'Design file issue',
      'Duplicate order',
      'Customer unresponsive',
      'Others',
    ];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          backgroundColor: _Glass.surface,
          elevation: 24,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _Glass.borderMid, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cancel Order?',
                  style: TextStyle(
                    color: _Glass.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Order $orderId will be moved to Cancelled.',
                  style: const TextStyle(
                    color: _Glass.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Reason for Cancellation',
                  style: TextStyle(
                    color: _Glass.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: _Glass.surfaceThin,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _Glass.borderMid, width: 0.9),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedReason.isEmpty ? null : selectedReason,
                      hint: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Select a reason…',
                          style: TextStyle(
                            color: _Glass.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      isExpanded: true,
                      dropdownColor: _Glass.surface,
                      borderRadius: BorderRadius.circular(12),
                      icon: const Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: _Glass.textMuted,
                          size: 18,
                        ),
                      ),
                      items: reasons
                          .map(
                            (r) => DropdownMenuItem(
                              value: r,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text(
                                  r,
                                  style: const TextStyle(
                                    color: _Glass.textPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        setS(() {
                          selectedReason = val;
                          isOther = val == 'Others';
                          if (!isOther) {
                            customCtrl.clear();
                            customReason = '';
                          }
                        });
                      },
                    ),
                  ),
                ),
                if (isOther) ...[
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: _Glass.surfaceThin,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _Glass.borderMid, width: 0.9),
                    ),
                    child: TextField(
                      controller: customCtrl,
                      style: const TextStyle(
                        color: _Glass.textPrimary,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      onChanged: (v) => setS(() => customReason = v.trim()),
                      decoration: const InputDecoration(
                        hintText: 'Describe the reason…',
                        hintStyle: TextStyle(
                          color: _Glass.textMuted,
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 9,
                        ),
                        decoration: _Glass.glass(radius: 99),
                        child: const Text(
                          'Keep It',
                          style: TextStyle(
                            color: _Glass.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        final reason = isOther ? customReason : selectedReason;
                        if (reason.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please select a cancellation reason.',
                              ),
                            ),
                          );
                          return;
                        }
                        Navigator.pop(ctx, true);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 9,
                        ),
                        decoration: _Glass.solidPill(
                          _Glass.accentRose,
                          glow: true,
                        ),
                        child: const Text(
                          'Yes, Cancel',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final finalReason = isOther ? customReason : selectedReason;
    customCtrl.dispose();
    if (confirmed != true) return;

    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    batch.update(db.collection('Order_Queue').doc(queueDocId), {
      'job_status': 'cancelled',
      'cancel_reason': finalReason,
      'updated_at': FieldValue.serverTimestamp(),
    });
    batch.update(db.collection('Orders').doc(orderId), {
      'status': 'cancelled',
      'cancel_reason': finalReason,
    });

    final orderSnap = await db.collection('Orders').doc(orderId).get();
    final invoiceId = orderSnap.data()?['invoice_id']?.toString();
    if (invoiceId != null && invoiceId.isNotEmpty) {
      batch.update(db.collection('Invoices').doc(invoiceId), {
        'status': 'cancelled',
        'cancel_reason': finalReason,
        'cancelled_at': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    if (customerUid != null && customerUid.isNotEmpty) {
      final threadRef = FirebaseFirestore.instance
          .collection('Messages')
          .doc('chat_$customerUid');
      await threadRef.collection('chat').add({
        'sender_uid': 'system',
        'sender_role': 'system',
        'text':
            'Your order $orderId has been cancelled.\nReason: $finalReason\nPlease contact us for assistance.',
        'timestamp': FieldValue.serverTimestamp(),
      });
      await threadRef.set({
        'last_message': 'Your order $orderId has been cancelled.',
        'last_updated': FieldValue.serverTimestamp(),
        'unread_customer': FieldValue.increment(1),
      }, SetOptions(merge: true));
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order $orderId has been cancelled.'),
          backgroundColor: _Glass.accentRose,
        ),
      );
    }
  }

  Future<void> _startJob(BuildContext context) async {
    final orderId = data['order_id']?.toString();
    final customerUid = data['customer_uid']?.toString();
    if (orderId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _Glass.surface,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _Glass.borderMid, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Start Production?',
                style: TextStyle(
                  color: _Glass.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start production for order $orderId?',
                style: const TextStyle(
                  color: _Glass.textSecondary,
                  fontSize: 13,
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
                        horizontal: 18,
                        vertical: 9,
                      ),
                      decoration: _Glass.glass(radius: 99),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: _Glass.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      decoration: _Glass.solidPill(
                        _Glass.accentBlue,
                        glow: true,
                      ),
                      child: const Text(
                        'Start Job',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;

    final db = FirebaseFirestore.instance;
    final alreadyDeducted = data['bom_deducted'] == true;

    final batch = db.batch();
    batch.update(db.collection('Order_Queue').doc(queueDocId), {
      'job_status': 'active',
      'updated_at': FieldValue.serverTimestamp(),
    });
    batch.update(db.collection('Orders').doc(orderId), {
      'status': 'in_production',
    });
    await batch.commit();

    final allDeductionLines = <String>[];
    final deductionErrors = <String>[];

    if (!alreadyDeducted) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String employeeName = user.displayName ?? user.email ?? 'Employee';
        try {
          final userDoc = await db.collection('User').doc(user.uid).get();
          if (userDoc.exists) {
            employeeName = userDoc.data()?['full_name'] ?? employeeName;
          }
        } catch (_) {}

        final products = List<Map<String, dynamic>>.from(
          ((data['products'] as List?) ?? []).map(
            (e) => Map<String, dynamic>.from(e as Map),
          ),
        );

        for (final p in products) {
          final productId = p['product_id']?.toString() ?? '';
          if (productId.isEmpty) continue;
          final qty = (p['qty'] as num?)?.toDouble() ?? 1.0;
          final widthFt = (p['width_ft'] as num?)?.toDouble();
          final heightFt = (p['height_ft'] as num?)?.toDouble();
          final selectedMaterial = p['material']?.toString();
          final effectiveQty = (widthFt != null && heightFt != null)
              ? widthFt * heightFt * qty
              : qty;
          try {
            final lines = await InventoryService.deductForOrder(
              orderId: orderId,
              productId: productId,
              productName: p['name']?.toString() ?? '',
              orderQuantity: effectiveQty,
              processedByUid: user.uid,
              processedByName: employeeName,
              selectedMaterial: selectedMaterial,
            );
            allDeductionLines.addAll(lines);
          } catch (e) {
            final pName = p['name']?.toString() ?? productId;
            deductionErrors.add('$pName: $e');
            debugPrint('Inventory deduction failed for $productId: $e');
          }
        }

        if (deductionErrors.isEmpty && allDeductionLines.isNotEmpty) {
          await db.collection('Orders').doc(orderId).update({
            'bom_deducted': true,
          });
        }
      }
    }

    if (customerUid != null && customerUid.isNotEmpty) {
      final threadRef = FirebaseFirestore.instance
          .collection('Messages')
          .doc('chat_$customerUid');
      final turnaround = data['turnaround_days'] as int?;
      await threadRef.collection('chat').add({
        'sender_uid': 'system',
        'sender_role': 'system',
        'text':
            'Your order $orderId is now in production!'
            '${turnaround != null ? ' Estimated completion: ~$turnaround day${turnaround == 1 ? '' : 's'}.' : ''}',
        'timestamp': FieldValue.serverTimestamp(),
      });
      await threadRef.set({
        'last_message': 'Your order $orderId is now in production!',
        'last_updated': FieldValue.serverTimestamp(),
        'unread_customer': FieldValue.increment(1),
      }, SetOptions(merge: true));
    }

    if (context.mounted) {
      if (deductionErrors.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Production started for $orderId, but some inventory deductions failed:\n${deductionErrors.join('\n')}',
            ),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 8),
          ),
        );
      } else if (allDeductionLines.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Production started — inventory deducted:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                ...allDeductionLines.map(
                  (l) => Text(
                    '  • $l',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: _Glass.accentBlue,
            duration: const Duration(seconds: 6),
          ),
        );
      } else if (alreadyDeducted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Production started for $orderId (inventory already deducted earlier)',
            ),
            backgroundColor: _Glass.accentBlue,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Production started for $orderId (no BOM set for products)',
            ),
            backgroundColor: _Glass.accentBlue,
          ),
        );
      }
    }
  }

  Future<void> _markReady(BuildContext context) async {
    final orderId = data['order_id']?.toString();
    final customerUid = data['customer_uid']?.toString();
    if (orderId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _Glass.surface,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _Glass.borderMid, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mark Ready for Pickup?',
                style: TextStyle(
                  color: _Glass.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mark order $orderId as ready for pickup?',
                style: const TextStyle(
                  color: _Glass.textSecondary,
                  fontSize: 13,
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
                        horizontal: 18,
                        vertical: 9,
                      ),
                      decoration: _Glass.glass(radius: 99),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: _Glass.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      decoration: _Glass.solidPill(
                        _Glass.accentEmerald,
                        glow: true,
                      ),
                      child: const Text(
                        'Mark Ready',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;

    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    final orderSnap = await db.collection('Orders').doc(orderId).get();
    final remaining =
        (orderSnap.data()?['remaining_balance'] as num?)?.toDouble() ?? 0;

    batch.update(db.collection('Order_Queue').doc(queueDocId), {
      'job_status': 'completed',
      'updated_at': FieldValue.serverTimestamp(),
    });
    batch.update(db.collection('Orders').doc(orderId), {'status': 'ready'});
    await batch.commit();

    if (customerUid != null && customerUid.isNotEmpty) {
      final balanceNote = remaining > 0
          ? ' Remaining balance due on pickup: ₱${remaining.toStringAsFixed(2)}.'
          : ' Your order is fully paid — just come pick it up!';
      final threadRef = FirebaseFirestore.instance
          .collection('Messages')
          .doc('chat_$customerUid');
      await threadRef.collection('chat').add({
        'sender_uid': 'system',
        'sender_role': 'system',
        'text': 'Your order $orderId is ready for pickup!$balanceNote',
        'timestamp': FieldValue.serverTimestamp(),
      });
      await threadRef.set({
        'last_message': 'Your order $orderId is ready for pickup!',
        'last_updated': FieldValue.serverTimestamp(),
        'unread_customer': FieldValue.increment(1),
      }, SetOptions(merge: true));
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order $orderId marked ready for pickup'),
          backgroundColor: _Glass.accentEmerald,
        ),
      );
    }
  }

  Future<void> _openChat(BuildContext context) async {
    final customerUid = data['customer_uid']?.toString() ?? '';
    final customerName = data['customer_name']?.toString() ?? 'Customer';
    if (customerUid.isEmpty) return;

    final orderId = data['order_id']?.toString() ?? queueDocId;
    final products =
        (data['products'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final productSummary = products.isNotEmpty
        ? products
              .map((p) => '${p['name'] ?? '?'} ×${p['qty'] ?? 1}')
              .join(', ')
        : '—';
    final total = (data['total_price'] as num?)?.toDouble() ?? 0;
    final jobStatus = data['job_status']?.toString() ?? 'pending';
    final statusLabel = jobStatus == 'active' ? 'In Production' : 'Pending';

    final user = FirebaseAuth.instance.currentUser;
    String employeeName = user?.displayName ?? 'Employee';
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('User')
            .doc(user.uid)
            .get();
        employeeName = doc.data()?['full_name'] ?? employeeName;
      } catch (_) {}
    }

    final threadRef = FirebaseFirestore.instance
        .collection('Messages')
        .doc('chat_$customerUid');

    final msgText =
        'Regarding Order: $orderId\n'
        'Items: $productSummary\n'
        'Status: $statusLabel\n'
        'Total: ₱${total.toStringAsFixed(2)}';

    await threadRef.collection('chat').add({
      'sender_uid': user?.uid ?? 'employee',
      'sender_name': employeeName,
      'sender_role': 'employee',
      'text': msgText,
      'timestamp': FieldValue.serverTimestamp(),
    });
    await threadRef.set({
      'customer_uid': customerUid,
      'customer_name': customerName,
      'last_message': 'Re: $orderId — $statusLabel',
      'last_updated': FieldValue.serverTimestamp(),
      'unread_customer': FieldValue.increment(1),
    }, SetOptions(merge: true));

    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => Scaffold(
            backgroundColor: const Color(0xFFF7F8FA),
            body: SafeArea(
              child: ChatScreen(
                customerUid: customerUid,
                customerName: customerName,
                isEmployee: true,
                embedded: true,
                onClose: () => Navigator.pop(ctx),
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderId = data['order_id']?.toString() ?? '—';
    final customerName = data['customer_name']?.toString() ?? 'Customer';
    final customerId = data['customer_id']?.toString() ?? '';
    final turnaround = data['turnaround_days'] as int?;
    final total = (data['total_price'] as num?)?.toDouble() ?? 0;
    final jobStatus = data['job_status']?.toString() ?? 'pending';
    final products =
        (data['products'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final dateStr = _fmtDate(data['created_at']);

    final DateTime? estimatedCompletion = (() {
      final ts = data['estimated_completion'] as Timestamp?;
      if (ts != null) return ts.toDate().toLocal();
      final created = (data['created_at'] as Timestamp?)?.toDate().toLocal();
      final ta = data['turnaround_days'] as int?;
      if (created == null || ta == null) return null;
      return created.add(Duration(days: ta));
    })();

    final statusColor = jobStatus == 'active'
        ? _Glass.accentBlue
        : jobStatus == 'cancelled'
        ? _Glass.accentRose
        : _Glass.accentAmber;

    final statusLabel = jobStatus == 'active'
        ? 'Active'
        : jobStatus == 'cancelled'
        ? 'Cancelled'
        : 'Pending';

    final productSummary = products.isEmpty
        ? null
        : products
              .map((p) => '${p['name'] ?? '?'} ×${p['qty'] ?? 1}')
              .join(', ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _Glass.accentAmber.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: _Glass.accentAmber.withValues(alpha: 0.35),
            ),
          ),
          child: Center(
            child: Text(
              '$position',
              style: const TextStyle(
                color: _Glass.accentAmber,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            orderId,
                            style: const TextStyle(
                              color: _Glass.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                customerName,
                                style: const TextStyle(
                                  color: _Glass.textSecondary,
                                  fontSize: 12,
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
                                    color: _Glass.accentAmber.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _Glass.accentAmber.withValues(
                                        alpha: 0.40,
                                      ),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: const Text(
                                    'Walk-in',
                                    style: TextStyle(
                                      color: _Glass.accentAmber,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (customerId.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Customer ID: $customerId',
                              style: const TextStyle(
                                color: _Glass.textMuted,
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
                    productSummary,
                    style: const TextStyle(
                      color: _Glass.textSecondary,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Builder(
                    builder: (_) {
                      if (data['walk_in'] == true) {
                        final fileNames = products
                            .map((p) => p['design_file_name']?.toString() ?? '')
                            .where((n) => n.isNotEmpty)
                            .toList();
                        if (fileNames.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: fileNames
                                .expand((n) => n.split(', '))
                                .map(
                                  (name) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _Glass.accentBlue.withValues(
                                        alpha: 0.10,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _Glass.accentBlue.withValues(
                                          alpha: 0.28,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.attach_file_rounded,
                                          size: 11,
                                          color: _Glass.accentBlue,
                                        ),
                                        const SizedBox(width: 4),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 140,
                                          ),
                                          child: Text(
                                            name,
                                            style: const TextStyle(
                                              color: _Glass.accentBlue,
                                              fontSize: 11,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        );
                      }
                      return DesignFilesSection(products: products);
                    },
                  ),
                ],

                if (estimatedCompletion != null &&
                    jobStatus != 'cancelled') ...[
                  const SizedBox(height: 6),
                  _DueDateRow(dueDate: estimatedCompletion),
                ],

                const SizedBox(height: 10),
                Divider(height: 0.8, color: _Glass.borderDim),
                const SizedBox(height: 10),

                if (jobStatus == 'cancelled') ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((data['cancel_reason']?.toString() ?? '').isNotEmpty)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _Glass.accentRose.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _Glass.accentRose.withValues(alpha: 0.22),
                              width: 0.9,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 13,
                                color: _Glass.accentRose,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Reason: ${data['cancel_reason']}',
                                  style: const TextStyle(
                                    color: _Glass.accentRose,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 11,
                            color: _Glass.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              dateStr,
                              style: const TextStyle(
                                color: _Glass.textMuted,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (turnaround != null) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.schedule,
                              size: 11,
                              color: _Glass.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '~$turnaround day${turnaround == 1 ? '' : 's'}',
                              style: const TextStyle(
                                color: _Glass.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '₱${total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: _Glass.accentAmber,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Builder(
                                builder: (context) {
                                  final paid =
                                      (data['amount_paid'] as num?)
                                          ?.toDouble() ??
                                      0;
                                  if (paid <= 0) {
                                    return const SizedBox.shrink();
                                  }
                                  return Text(
                                    'Paid: ₱${paid.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: _Glass.accentEmerald,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const Spacer(),
                          Builder(
                            builder: (ctx) => GestureDetector(
                              onTap: () async {
                                final oid =
                                    data['order_id']?.toString() ?? queueDocId;
                                final orderSnap = await FirebaseFirestore
                                    .instance
                                    .collection('Orders')
                                    .doc(oid)
                                    .get();
                                final invId = orderSnap
                                    .data()?['invoice_id']
                                    ?.toString();
                                if (!ctx.mounted) return;
                                if (invId != null && invId.isNotEmpty) {
                                  Navigator.of(ctx).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          InvoiceScreen(invoiceId: invId),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'No invoice for this order',
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                decoration: _Glass.glass(radius: 99),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.receipt_long_rounded,
                                      size: 15,
                                      color: _Glass.textSecondary,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'View Invoice',
                                      style: TextStyle(
                                        color: _Glass.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _RefundPickupSection(
                        queueDocId: queueDocId,
                        data: data,
                        orderId: data['order_id']?.toString() ?? queueDocId,
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 11,
                        color: _Glass.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          color: _Glass.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      if (turnaround != null) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.schedule,
                          size: 11,
                          color: _Glass.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '~$turnaround day${turnaround == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: _Glass.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const Spacer(),
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('Orders')
                            .doc(orderId)
                            .get(),
                        builder: (context, snap) {
                          final docData =
                              snap.data?.data() as Map<String, dynamic>?;
                          final paid = docData?['amount_paid'] as num?;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₱${total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: _Glass.accentAmber,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (paid != null && paid > 0)
                                Text(
                                  'Paid: ₱${paid.toDouble().toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: _Glass.accentEmerald,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (jobStatus == 'pending')
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _startJob(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: _Glass.solidPill(
                                _Glass.accentBlue,
                                glow: true,
                              ),
                              child: const Center(
                                child: Text(
                                  'Start Job',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (jobStatus == 'active')
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _markReady(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: _Glass.solidPill(
                                _Glass.accentEmerald,
                                glow: true,
                              ),
                              child: const Center(
                                child: Text(
                                  'Mark Ready',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (jobStatus != 'active') ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _cancelOrder(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: _Glass.accentRose.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: _Glass.accentRose.withValues(
                                  alpha: 0.30,
                                ),
                                width: 0.8,
                              ),
                            ),
                            child: const Icon(
                              Icons.cancel_outlined,
                              size: 18,
                              color: _Glass.accentRose,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Builder(
                        builder: (ctx) => GestureDetector(
                          onTap: () async {
                            final orderSnap = await FirebaseFirestore.instance
                                .collection('Orders')
                                .doc(orderId)
                                .get();
                            final invId = orderSnap
                                .data()?['invoice_id']
                                ?.toString();
                            if (invId != null && ctx.mounted) {
                              Navigator.of(ctx).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      InvoiceScreen(invoiceId: invId),
                                ),
                              );
                            } else if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'No invoice yet for this order',
                                  ),
                                ),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: _Glass.glass(radius: 99),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              size: 18,
                              color: _Glass.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _openChat(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: _Glass.glass(radius: 99),
                          child: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 18,
                            color: _Glass.textSecondary,
                          ),
                        ),
                      ),
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
// _DueDateRow
// =============================================================================
class _DueDateRow extends StatelessWidget {
  final DateTime dueDate;
  const _DueDateRow({required this.dueDate});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final diff = due.difference(today).inDays;

    final Color color;
    final String label;

    if (diff < 0) {
      color = _Glass.accentRose;
      label =
          'Overdue by ${-diff} day${diff == -1 ? '' : 's'} — ${_fmt(dueDate)}';
    } else if (diff == 0) {
      color = _Glass.accentRose;
      label = 'Target completion: TODAY';
    } else if (diff == 1) {
      color = _Glass.accentAmber;
      label = 'Target completion: Tomorrow (${_fmt(dueDate)})';
    } else {
      color = _Glass.accentEmerald;
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
            fontSize: 13,
            fontWeight: diff <= 0 ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _fmt(DateTime d) {
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
}

// =============================================================================
// _DeadlineAlertBanner
// =============================================================================
class _DeadlineAlertBanner extends StatefulWidget {
  const _DeadlineAlertBanner();
  @override
  State<_DeadlineAlertBanner> createState() => _DeadlineAlertBannerState();
}

class _DeadlineAlertBannerState extends State<_DeadlineAlertBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final threshold = now.add(const Duration(days: 2));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Orders')
          .where('status', whereIn: ['pending', 'in_production'])
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const SizedBox.shrink();

        final due =
            snap.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final ts = data['estimated_completion'] as Timestamp?;
              if (ts == null) return false;
              return ts.toDate().isBefore(threshold);
            }).toList()..sort((a, b) {
              final ta =
                  ((a.data() as Map)['estimated_completion'] as Timestamp?)
                      ?.toDate();
              final tb =
                  ((b.data() as Map)['estimated_completion'] as Timestamp?)
                      ?.toDate();
              if (ta == null && tb == null) return 0;
              if (ta == null) return 1;
              if (tb == null) return -1;
              return ta.compareTo(tb);
            });

        if (due.isEmpty) return const SizedBox.shrink();

        final overdueCount = due.where((doc) {
          final ts = ((doc.data() as Map)['estimated_completion'] as Timestamp?)
              ?.toDate();
          return ts != null && ts.isBefore(now);
        }).length;

        final isUrgent = overdueCount > 0;
        final accent = isUrgent ? _Glass.accentRose : _Glass.accentAmber;

        return AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                    child: Row(
                      children: [
                        Icon(
                          isUrgent
                              ? Icons.warning_amber_rounded
                              : Icons.access_time_rounded,
                          size: 14,
                          color: accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isUrgent
                                ? '$overdueCount overdue${due.length - overdueCount > 0 ? ' · ${due.length - overdueCount} due soon' : ''} — action needed'
                                : '${due.length} order${due.length == 1 ? '' : 's'} due within 2 days',
                            style: TextStyle(
                              color: accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(
                          _expanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 16,
                          color: accent.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_expanded)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: due.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final orderId =
                              data['order_id']?.toString() ?? doc.id;
                          final customer =
                              data['customer_name']?.toString() ?? '—';
                          final status = data['status']?.toString() ?? '';
                          final ts = data['estimated_completion'] as Timestamp?;
                          final dueDate = ts?.toDate().toLocal();
                          final isOverdue =
                              dueDate != null && dueDate.isBefore(now);
                          final todayMid = DateTime(
                            now.year,
                            now.month,
                            now.day,
                          );
                          final dueMid = dueDate != null
                              ? DateTime(
                                  dueDate.year,
                                  dueDate.month,
                                  dueDate.day,
                                )
                              : null;
                          final diff = dueMid?.difference(todayMid).inDays;
                          final rowColor = isOverdue
                              ? _Glass.accentRose
                              : _Glass.accentAmber;
                          final dueLabel = dueDate == null
                              ? '—'
                              : diff! < 0
                              ? 'Overdue (${_fmtBanner(dueDate)})'
                              : diff == 0
                              ? 'Due TODAY'
                              : 'Due ${_fmtBanner(dueDate)}';
                          final statusLabel = status == 'in_production'
                              ? 'Active'
                              : 'Pending';

                          return Container(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                            child: Row(
                              children: [
                                const SizedBox(width: 22),
                                Expanded(
                                  child: Text(
                                    '$orderId · $customer',
                                    style: const TextStyle(
                                      color: _Glass.textSecondary,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _Glass.surfaceThin,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _Glass.borderMid,
                                      width: 0.7,
                                    ),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: const TextStyle(
                                      color: _Glass.textMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: rowColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    dueLabel,
                                    style: TextStyle(
                                      color: rowColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _fmtBanner(DateTime d) {
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
    return '${m[d.month - 1]} ${d.day}';
  }
}
