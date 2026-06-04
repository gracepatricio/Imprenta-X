import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
          // ── Unified header card (mirrors inventory header) ──────────────
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
                    // Row 1: icon + title
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

                    // Row 2: sub-tab pills (Sales | POS)
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

          // ── Body ──────────────────────────────────────────────────────────
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
// _TabPill — mirrors inventory _TabPill exactly
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
// _SalesSection — Sales Record / Sales Report sub-tabs
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
          // ── Inner sub-tab bar ─────────────────────────────────────────────
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

// ── Inner pill tab (Sales Record / Sales Report) ──────────────────────────────
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
// EmployeeJobQueueScreen — public entry-point (unchanged structure)
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
          // ── Header card ───────────────────────────────────────────────────
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
// _JobQueueSection — 5 sub-tabs (structure unchanged)
// =============================================================================
class _UnderlineTabBar extends StatelessWidget {
  final List<String> tabs;
  final int active;
  final ValueChanged<int> onTap;

  const _UnderlineTabBar({
    required this.tabs,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isActive = i == active;
          return GestureDetector(
            onTap: () => onTap(i),
            child: Container(
              margin: EdgeInsets.only(right: i < tabs.length - 1 ? 20 : 0),
              padding: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isActive ? _navyBlue : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
              child: Text(
                tabs[i],
                style: TextStyle(
                  color: isActive ? _Glass.textPrimary : _Glass.textMuted,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _JobQueueSection extends StatefulWidget {
  final int initialTab;
  const _JobQueueSection({this.initialTab = 0});

  @override
  State<_JobQueueSection> createState() => _JobQueueSectionState();
}

class _JobQueueSectionState extends State<_JobQueueSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  static const _tabLabels = [
    'Pending',
    'Active',
    'Ready for Pickup',
    'Cancelled',
    'Order History',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 4),
    );
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _BlurCard(
      radius: 20,
      elevated: true,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _UnderlineTabBar(
                    tabs: _tabLabels,
                    active: _tabs.index,
                    onTap: (i) => _tabs.animateTo(i),
                  ),
                ),
                if (_tabs.index != 4)
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
          ),
          Divider(
            height: 1,
            color: _Glass.borderDim,
            indent: 16,
            endIndent: 16,
          ),
          Expanded(
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: const _DeadlineAlertBanner(),
                  ),
                ),
              ],
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TabBarView(
                  controller: _tabs,
                  children: const [
                    _QueueList(jobStatus: 'pending'),
                    _QueueList(jobStatus: 'active'),
                    _ReadyForPickupList(),
                    _QueueList(jobStatus: 'cancelled'),
                    _EmployeeOrderHistory(),
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

// =============================================================================
// _EmployeeOrderHistory
// =============================================================================
class _EmployeeOrderHistory extends StatefulWidget {
  const _EmployeeOrderHistory();

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
        // Status filter chips
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

        // Search field
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

        // List
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

                  return _OrderHistoryCard(
                    doc: doc,
                    orderId: orderId,
                    customer: customer,
                    status: status,
                    statusLabel: _statusLabel(status),
                    statusColor: statusColor,
                    total: total,
                    paid: paid,
                    remaining: remaining,
                    products: products,
                    dateStr: dateStr,
                    invoiceId: invoiceId,
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

// ── Order history card ────────────────────────────────────────────────────────
class _OrderHistoryCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final String orderId, customer, status, statusLabel, dateStr;
  final Color statusColor;
  final double total, paid, remaining;
  final List<Map<String, dynamic>> products;
  final String? invoiceId;

  const _OrderHistoryCard({
    required this.doc,
    required this.orderId,
    required this.customer,
    required this.status,
    required this.statusLabel,
    required this.statusColor,
    required this.total,
    required this.paid,
    required this.remaining,
    required this.products,
    required this.dateStr,
    this.invoiceId,
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
                      Text(
                        '$customer · $dateStr',
                        style: const TextStyle(
                          color: _Glass.textMuted,
                          fontSize: 12,
                        ),
                      ),
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
              DesignFilesSection(products: products),
            ],
            const SizedBox(height: 10),

            // Chips row
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
                  fullyPaid ? 'Fully Paid' : 'Balance',
                  fullyPaid ? '—' : '₱${remaining.toStringAsFixed(2)}',
                  fullyPaid ? _Glass.accentEmerald : _amber,
                  bold: true,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Invoice button
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
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _Glass.surfaceThin,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _Glass.borderMid, width: 0.9),
                  ),
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
      ),
    );
  }
}

// ── Info chip ─────────────────────────────────────────────────────────────────
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
// _AddWalkInJobDialog (structure unchanged, colours aligned)
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
    final snap = await FirebaseFirestore.instance
        .collection('Products')
        .where('is_available', isEqualTo: true)
        .get();
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
    final products = _items.map((item) => {
      'category': item.productData['category']?.toString() ?? '',
      'qty':      item.qty,
      if (item.widthFt  != null) 'width_ft':  item.widthFt,
      if (item.heightFt != null) 'height_ft': item.heightFt,
    }).toList();
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
              'unit_price':
                  (item.productData['price'] as num?)?.toDouble() ?? 0,
              'pricing_unit':
                  item.productData['pricing_unit']?.toString() ?? '',
              'price': item.subtotal,
              'notes': item.notes,
              if (item.widthFt != null) 'width_ft': item.widthFt,
              if (item.heightFt != null) 'height_ft': item.heightFt,
              if (item.material != null) 'material': item.material,
              if (item.widthFt != null && item.heightFt != null)
                'size_label': '${item.widthFt}ft × ${item.heightFt}ft',
              'walk_in': true,
            },
          )
          .toList();

      final orderRef = db.collection('Orders').doc(orderId);
      batch.set(orderRef, {
        'order_id': orderId,
        'customer_uid': '',
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
        'order_id':             orderId,
        'customer_uid':         '',
        'customer_name':        customerName,
        'job_status':           'pending',
        'turnaround_days':      turnaroundDays,
        'estimated_completion': Timestamp.fromDate(estimatedCompletion),
        'products':             products,
        'total_price':          total,
        'walk_in':              true,
        'created_at':           now,
      });

      final invoiceRef = db.collection('Invoices').doc(invoiceId);
      batch.set(invoiceRef, {
        'invoice_id': invoiceId,
        'order_id': orderId,
        'customer_name': customerName,
        'customer_email': customerEmail,
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

  void _showAddProductSheet() {
    showDialog(
      context: context,
      builder: (_) => _ProductPickerDialog(
        products: _products,
        onAdd: (item) => setState(() => _items.add(item)),
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
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _Glass.borderMid, width: 1),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title bar
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _navyBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.add_box_outlined,
                        color: Colors.white,
                        size: 15,
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
                      onTap: _submitting ? null : () => Navigator.pop(context),
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

                        // Products header
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
                                  : _showAddProductSheet,
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
                                              '${item.widthFt}ft × ${item.heightFt}ft',
                                            if (item.material != null)
                                              item.material!,
                                            '₱${(item.productData['price'] as num?)?.toStringAsFixed(2) ?? '0'}'
                                                ' × ${item.qty} = ₱${item.subtotal.toStringAsFixed(2)}',
                                          ].join(' · '),
                                          style: const TextStyle(
                                            color: _Glass.textMuted,
                                            fontSize: 12,
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
                          hint: 'Amount Paid (₱) *',
                          icon: Icons.monetization_on_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) {
                            final n = double.tryParse(v?.trim() ?? '');
                            if (n == null) return 'Enter a valid amount';
                            if (n < 0) return 'Cannot be negative';
                            if (_items.isNotEmpty && n > _total + 0.01) {
                              return 'Cannot exceed total ₱${_total.toStringAsFixed(2)}';
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

                // Action bar
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
// _GlassFormField — text field matching inventory _GlassField style
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
// _WalkInItem model (unchanged)
// =============================================================================
class _WalkInItem {
  final String productDocId;
  final Map<String, dynamic> productData;
  int qty;
  String notes;
  double? widthFt;
  double? heightFt;
  String? material;

  _WalkInItem({
    required this.productDocId,
    required this.productData,
    required this.qty,
    required this.notes,
    this.widthFt,
    this.heightFt,
    this.material,
  });

  double get unitPrice => (productData['price'] as num?)?.toDouble() ?? 0;

  bool get needsSize {
    final u = (productData['pricing_unit']?.toString() ?? '').toLowerCase();
    return u.contains('sq') || u.contains('sqft') || u.contains('per ft');
  }

  double get subtotal {
    if (needsSize && widthFt != null && heightFt != null) {
      return unitPrice * widthFt! * heightFt! * qty;
    }
    return unitPrice * qty;
  }
}

// =============================================================================
// _ProductPickerDialog (structure unchanged, colours aligned)
// =============================================================================
class _ProductPickerDialog extends StatefulWidget {
  final List<QueryDocumentSnapshot> products;
  final ValueChanged<_WalkInItem> onAdd;
  const _ProductPickerDialog({required this.products, required this.onAdd});

  @override
  State<_ProductPickerDialog> createState() => _ProductPickerDialogState();
}

class _ProductPickerDialogState extends State<_ProductPickerDialog> {
  QueryDocumentSnapshot? _selected;
  int _qty = 1;
  String _notes = '';
  String _search = '';
  String? _category;

  String _sizePreset = '2×3 ft';
  double _widthFt = 2;
  double _heightFt = 3;
  final _widthCtrl = TextEditingController(text: '2');
  final _heightCtrl = TextEditingController(text: '3');
  String? _material;

  final _qtyCtrl = TextEditingController(text: '1');
  final _notesCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

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
  static const _materialMap = {
    'Large Format & Signage': ['Standard Tarp', 'Premium Tarp', 'Mesh Tarp', 'Standard', 'Premium Backlit'],
    'Stickers & Labels': ['Glossy Vinyl', 'Matte Vinyl', 'Clear Vinyl'],
    'Photo & Card Prints': ['Glossy', 'Matte', 'Satin', 'Kraft Paper', 'UV Coated'],
  };
  static const _categories = [
    'Large Format & Signage',
    'Stickers & Labels',
    'Photo & Card Prints',
  ];

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    _searchCtrl.dispose();
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot> get _filtered => widget.products.where((doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = (data['product_name']?.toString() ?? '').toLowerCase();
    final cat = data['category']?.toString() ?? '';
    return (_search.isEmpty || name.contains(_search.toLowerCase())) &&
        (_category == null || cat == _category);
  }).toList();

  bool get _needsSize {
    final data = _selected?.data() as Map<String, dynamic>?;
    final u = (data?['pricing_unit']?.toString() ?? '').toLowerCase();
    return u.contains('sq') || u.contains('sqft') || u.contains('per ft');
  }

  List<String> get _materialList {
    final data = _selected?.data() as Map<String, dynamic>?;
    final cat = data?['category']?.toString() ?? '';
    return _materialMap[cat] ?? [];
  }

  double get _unitPrice {
    final data = _selected?.data() as Map<String, dynamic>?;
    return (data?['price'] as num?)?.toDouble() ?? 0.0;
  }

  double get _lineSubtotal {
    if (_needsSize) return _unitPrice * _widthFt * _heightFt * _qty;
    return _unitPrice * _qty;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Dialog(
      backgroundColor: _Glass.surface,
      elevation: 32,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _Glass.borderMid, width: 1),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _navyBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.category_outlined,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Select Product',
                      style: TextStyle(
                        color: _Glass.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _Glass.surfaceThin,
                        shape: BoxShape.circle,
                        border: Border.all(color: _Glass.borderMid, width: 0.9),
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
                height: 20,
                thickness: 0.8,
              ),

              // Search
              Container(
                decoration: BoxDecoration(
                  color: _Glass.surfaceThin,
                  borderRadius: BorderRadius.circular(10),
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
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Category chips
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
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
              const SizedBox(height: 12),

              // Product list
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'No products found.',
                          style: TextStyle(
                            color: _Glass.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final doc = filtered[i];
                          final data = doc.data() as Map<String, dynamic>;
                          final name = data['product_name']?.toString() ?? '—';
                          final price =
                              (data['price'] as num?)?.toDouble() ?? 0;
                          final unit = data['pricing_unit']?.toString() ?? '';
                          final imageUrl = data['image_url']?.toString() ?? '';
                          final cat = data['category']?.toString() ?? '';
                          final desc = data['description']?.toString() ?? '';
                          final isSelected = _selected?.id == doc.id;

                          return GestureDetector(
                            onTap: () => setState(() {
                              _selected = doc;
                              final minQty =
                                  (data['min_quantity'] as num?)?.toInt() ?? 1;
                              _qty = minQty;
                              _qtyCtrl.text = '$_qty';
                              _sizePreset = '2×3 ft';
                              _widthFt = 2;
                              _heightFt = 3;
                              _widthCtrl.text = '2';
                              _heightCtrl.text = '3';
                              final mats =
                                  _materialMap[data['category']?.toString() ??
                                      ''] ??
                                  [];
                              _material = mats.isNotEmpty ? mats.first : null;
                            }),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: isSelected
                                  ? _Glass.glass(
                                      radius: 12,
                                      tintBorder: _navyBlue.withValues(
                                        alpha: 0.45,
                                      ),
                                    )
                                  : _Glass.glass(radius: 12),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.horizontal(
                                      left: Radius.circular(12),
                                    ),
                                    child: SizedBox(
                                      width: 64,
                                      height: 64,
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
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: TextStyle(
                                            color: _Glass.textPrimary,
                                            fontWeight: isSelected
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (cat.isNotEmpty)
                                          Text(
                                            cat,
                                            style: const TextStyle(
                                              color: _Glass.textMuted,
                                              fontSize: 10,
                                            ),
                                          ),
                                        if (desc.isNotEmpty)
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
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '₱${price.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: isSelected
                                                ? _navyBlue
                                                : _Glass.textPrimary,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (unit.isNotEmpty)
                                          Text(
                                            '/ $unit',
                                            style: const TextStyle(
                                              color: _Glass.textMuted,
                                              fontSize: 10,
                                            ),
                                          ),
                                        if (isSelected)
                                          Icon(
                                            Icons.check_circle_rounded,
                                            color: _navyBlue,
                                            size: 16,
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

              if (_selected != null) ...[
                const SizedBox(height: 12),
                Divider(color: _Glass.borderDim, height: 1),
                const SizedBox(height: 12),

                if (_needsSize) ...[
                  _label('Size (in feet)'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _sizePresets
                        .map(
                          (p) => _selChip(p, _sizePreset == p, () {
                            final dims = _presetDims[p];
                            setState(() {
                              _sizePreset = p;
                              if (dims != null) {
                                _widthFt = dims.$1;
                                _heightFt = dims.$2;
                                _widthCtrl.text = dims.$1.toString();
                                _heightCtrl.text = dims.$2.toString();
                              }
                            });
                          }),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _dimField('Width', _widthCtrl, (v) {
                          final d = double.tryParse(v);
                          if (d != null && d > 0)
                            setState(() {
                              _widthFt = d;
                              _sizePreset = 'Custom';
                            });
                        }),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '×',
                          style: TextStyle(
                            color: _Glass.textMuted,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _dimField('Height', _heightCtrl, (v) {
                          final d = double.tryParse(v);
                          if (d != null && d > 0)
                            setState(() {
                              _heightFt = d;
                              _sizePreset = 'Custom';
                            });
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],

                if (_materialList.isNotEmpty) ...[
                  _label('Material / Finish'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _materialList
                        .map(
                          (m) => _selChip(
                            m,
                            _material == m,
                            () => setState(() => _material = m),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                ],

                Row(
                  children: [
                    const Text(
                      'Quantity',
                      style: TextStyle(
                        color: _Glass.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    _qtyBtn(
                      Icons.remove_rounded,
                      () => setState(() {
                        final minQty =
                            ((_selected!.data() as Map)['min_quantity'] as num?)
                                ?.toInt() ??
                            1;
                        if (_qty > minQty) {
                          _qty--;
                          _qtyCtrl.text = '$_qty';
                        }
                      }),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 56,
                      child: TextField(
                        controller: _qtyCtrl,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: _Glass.textPrimary,
                          fontSize: 13,
                        ),
                        onChanged: (v) {
                          final n = int.tryParse(v);
                          if (n != null && n > 0) setState(() => _qty = n);
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: _Glass.surfaceThin,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: _Glass.borderMid,
                              width: 0.9,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: _Glass.borderMid,
                              width: 0.9,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: _navyBlue.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _qtyBtn(
                      Icons.add_rounded,
                      () => setState(() {
                        _qty++;
                        _qtyCtrl.text = '$_qty';
                      }),
                    ),
                    const Spacer(),
                    Text(
                      '₱${_lineSubtotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: _Glass.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _GlassFormField(
                  controller: _notesCtrl,
                  hint: 'Product notes / specifications (optional)',
                  maxLines: 2,
                ),
              ],

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: _selected == null
                      ? null
                      : () {
                          if (_materialList.isNotEmpty && _material == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please select a material / finish.',
                                ),
                              ),
                            );
                            return;
                          }
                          widget.onAdd(
                            _WalkInItem(
                              productDocId: _selected!.id,
                              productData:
                                  _selected!.data() as Map<String, dynamic>,
                              qty: _qty,
                              notes: _notes,
                              widthFt: _needsSize ? _widthFt : null,
                              heightFt: _needsSize ? _heightFt : null,
                              material: _material,
                            ),
                          );
                          Navigator.pop(context);
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: _selected == null
                        ? _Glass.glass(radius: 12)
                        : _Glass.solidPill(_navyBlue, glow: true),
                    child: Center(
                      child: Text(
                        _selected == null
                            ? 'Select a product first'
                            : 'Add to Order',
                        style: TextStyle(
                          color: _selected == null
                              ? _Glass.textMuted
                              : Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _catChip(String label, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
              fontSize: 11,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      );

  Widget _imgPlaceholder() => Container(
    color: _Glass.surfaceThin,
    child: const Center(
      child: Icon(Icons.image_outlined, color: _Glass.textMuted, size: 24),
    ),
  );

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 30,
      height: 30,
      decoration: _Glass.glass(radius: 8),
      child: Icon(icon, color: _Glass.textSecondary, size: 16),
    ),
  );

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      color: _Glass.textPrimary,
      fontSize: 13,
      fontWeight: FontWeight.w700,
    ),
  );

  Widget _selChip(String label, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
        hintText: '$label (ft)',
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
// _QueueList (structure unchanged)
// =============================================================================
class _QueueList extends StatelessWidget {
  final String jobStatus;
  const _QueueList({required this.jobStatus});

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('Order_Queue')
        .where('job_status', isEqualTo: jobStatus);

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
          final icon = jobStatus == 'pending'
              ? Icons.queue_outlined
              : jobStatus == 'cancelled'
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
                  jobStatus == 'pending'
                      ? 'No pending jobs'
                      : jobStatus == 'cancelled'
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

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            return _QueueCard(queueDocId: doc.id, data: data, position: i + 1);
          },
        );
      },
    );
  }
}

// =============================================================================
// _ReadyForPickupList (structure unchanged)
// =============================================================================
class _ReadyForPickupList extends StatelessWidget {
  const _ReadyForPickupList();

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

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            return _ReadyOrderCard(orderId: doc.id, data: data);
          },
        );
      },
    );
  }
}

// =============================================================================
// _ReadyOrderCard (structure unchanged, colours aligned)
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
    final customerUid  = data['customer_uid']?.toString() ?? '';
    final customerName = data['customer_name']?.toString() ?? 'Customer';
    if (customerUid.isEmpty) return;

    final orderLabel = data['order_id']?.toString() ?? orderId;
    final products   = (data['products'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final productSummary = products.isNotEmpty
        ? products.map((p) => '${p['name'] ?? '?'} ×${p['qty'] ?? 1}').join(', ')
        : '—';
    final total = (data['total_price'] as num?)?.toDouble() ?? 0;

    final user = FirebaseAuth.instance.currentUser;
    String employeeName = user?.displayName ?? 'Employee';
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('User').doc(user.uid).get();
        employeeName = doc.data()?['full_name'] ?? employeeName;
      } catch (_) {}
    }

    final threadRef = FirebaseFirestore.instance
        .collection('Messages').doc('chat_$customerUid');

    final msgText = 'Regarding Order: $orderLabel\n'
        'Items: $productSummary\n'
        'Status: Ready for Pickup\n'
        'Total: ₱${total.toStringAsFixed(2)}';

    await threadRef.collection('chat').add({
      'sender_uid':  user?.uid ?? 'employee',
      'sender_name': employeeName,
      'sender_role': 'employee',
      'text':        msgText,
      'timestamp':   FieldValue.serverTimestamp(),
    });
    await threadRef.set({
      'customer_uid':   customerUid,
      'customer_name':  customerName,
      'last_message':   'Re: $orderLabel — Ready for Pickup',
      'last_updated':   FieldValue.serverTimestamp(),
      'unread_customer': FieldValue.increment(1),
    }, SetOptions(merge: true));

    if (context.mounted) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: const Color(0xFFF7F8FA),
          body: SafeArea(
            child: ChatScreen(
              customerUid:  customerUid,
              customerName: customerName,
              isEmployee:   true,
              embedded:     true,
              onClose:      () => Navigator.pop(ctx),
            ),
          ),
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderLabel = data['order_id']?.toString() ?? orderId;
    final customer = data['customer_name']?.toString() ?? '—';
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
                      Text(
                        '$customer · $dateStr',
                        style: const TextStyle(
                          color: _Glass.textMuted,
                          fontSize: 12,
                        ),
                      ),
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
            DesignFilesSection(products: products),
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
                GestureDetector(
                  onTap: () => _viewInvoice(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: _Glass.glass(radius: 10),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      size: 18,
                      color: _Glass.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Message button
                GestureDetector(
                  onTap: () => _openChat(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: _Glass.glass(radius: 10),
                    child: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 18,
                      color: _Glass.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (!fullyPaid)
                  Expanded(
                    child: Container(
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
                    ),
                  ),
                if (fullyPaid)
                  Expanded(
                    child: GestureDetector(
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _QueueCard (structure unchanged, colours aligned)
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
                'Cancel Order?',
                style: TextStyle(
                  color: _Glass.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to cancel order $orderId? This cannot be undone.',
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
                    onTap: () => Navigator.pop(ctx, true),
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
    );
    if (confirmed != true) return;

    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    batch.update(db.collection('Order_Queue').doc(queueDocId), {
      'job_status': 'cancelled',
      'updated_at': FieldValue.serverTimestamp(),
    });
    batch.update(db.collection('Orders').doc(orderId), {'status': 'cancelled'});
    await batch.commit();

    if (customerUid != null && customerUid.isNotEmpty) {
      final threadRef = FirebaseFirestore.instance
          .collection('Messages')
          .doc('chat_$customerUid');
      await threadRef.collection('chat').add({
        'sender_uid': 'system',
        'sender_role': 'system',
        'text':
            'Your order $orderId has been cancelled. Please contact us for assistance.',
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

    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    batch.update(db.collection('Order_Queue').doc(queueDocId), {
      'job_status': 'active',
      'updated_at': FieldValue.serverTimestamp(),
    });
    batch.update(db.collection('Orders').doc(orderId), {
      'status': 'in_production',
    });
    await batch.commit();

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
          await InventoryService.deductForOrder(
            orderId: orderId,
            productId: productId,
            productName: p['name']?.toString() ?? '',
            orderQuantity: effectiveQty,
            processedByUid: user.uid,
            processedByName: employeeName,
            selectedMaterial: selectedMaterial,
          );
        } catch (e) {
          debugPrint('Inventory deduction failed for $productId: $e');
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Started production for $orderId'),
          backgroundColor: _Glass.accentBlue,
        ),
      );
    }
  }

  Future<void> _markReady(BuildContext context) async {
    final orderId = data['order_id']?.toString();
    final customerUid = data['customer_uid']?.toString();
    if (orderId == null) return;

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
    final customerUid  = data['customer_uid']?.toString() ?? '';
    final customerName = data['customer_name']?.toString() ?? 'Customer';
    if (customerUid.isEmpty) return;

    final orderId = data['order_id']?.toString() ?? queueDocId;
    final products = (data['products'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final productSummary = products.isNotEmpty
        ? products.map((p) => '${p['name'] ?? '?'} ×${p['qty'] ?? 1}').join(', ')
        : '—';
    final total    = (data['total_price'] as num?)?.toDouble() ?? 0;
    final jobStatus = data['job_status']?.toString() ?? 'pending';
    final statusLabel = jobStatus == 'active' ? 'In Production' : 'Pending';

    final user = FirebaseAuth.instance.currentUser;
    String employeeName = user?.displayName ?? 'Employee';
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('User').doc(user.uid).get();
        employeeName = doc.data()?['full_name'] ?? employeeName;
      } catch (_) {}
    }

    final threadRef = FirebaseFirestore.instance
        .collection('Messages').doc('chat_$customerUid');

    final msgText = 'Regarding Order: $orderId\n'
        'Items: $productSummary\n'
        'Status: $statusLabel\n'
        'Total: ₱${total.toStringAsFixed(2)}';

    await threadRef.collection('chat').add({
      'sender_uid':  user?.uid ?? 'employee',
      'sender_name': employeeName,
      'sender_role': 'employee',
      'text':        msgText,
      'timestamp':   FieldValue.serverTimestamp(),
    });
    await threadRef.set({
      'customer_uid':    customerUid,
      'customer_name':   customerName,
      'last_message':    'Re: $orderId — $statusLabel',
      'last_updated':    FieldValue.serverTimestamp(),
      'unread_customer': FieldValue.increment(1),
    }, SetOptions(merge: true));

    if (context.mounted) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: const Color(0xFFF7F8FA),
          body: SafeArea(
            child: ChatScreen(
              customerUid:  customerUid,
              customerName: customerName,
              isEmployee:   true,
              embedded:     true,
              onClose:      () => Navigator.pop(ctx),
            ),
          ),
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderId = data['order_id']?.toString() ?? '—';
    final customerName = data['customer_name']?.toString() ?? 'Customer';
    final turnaround = data['turnaround_days'] as int?;
    final total = (data['total_price'] as num?)?.toDouble() ?? 0;
    final jobStatus = data['job_status']?.toString() ?? 'pending';
    final products =
        (data['products'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final dateStr = _fmtDate(data['created_at']);

    // Estimated completion: stored directly (new orders) or computed as fallback
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
                // Position badge
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _navyBlue.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _navyBlue.withValues(alpha: 0.3),
                      width: 0.9,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '#$position',
                      style: TextStyle(
                        color: _navyBlue.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        orderId,
                        style: const TextStyle(
                          color: _Glass.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        customerName,
                        style: const TextStyle(
                          color: _Glass.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
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
                    jobStatus == 'active'
                        ? 'Active'
                        : jobStatus == 'cancelled'
                        ? 'Cancelled'
                        : 'Pending',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (products.isNotEmpty) ...[
              Text(
                products
                    .map((p) => '${p['name'] ?? '?'} ×${p['qty'] ?? 1}')
                    .join(', '),
                style: const TextStyle(
                  color: _Glass.textSecondary,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              DesignFilesSection(products: products),
              const SizedBox(height: 6),
            ],

            Row(
              children: [
                Icon(Icons.schedule, size: 15, color: _Glass.textMuted),
                const SizedBox(width: 4),
                Text(
                  turnaround != null
                      ? 'Est. $turnaround day${turnaround == 1 ? '' : 's'}'
                      : 'Turnaround TBD',
                  style: const TextStyle(color: _Glass.textMuted, fontSize: 13),
                ),
                const SizedBox(width: 12),
                Icon(Icons.calendar_today, size: 15, color: _Glass.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    dateStr,
                    style: const TextStyle(
                      color: _Glass.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  '₱${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: _Glass.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            if (estimatedCompletion != null && jobStatus != 'cancelled') ...[
              const SizedBox(height: 6),
              _DueDateRow(dueDate: estimatedCompletion),
            ],
            const SizedBox(height: 12),

            if (jobStatus != 'cancelled')
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
                  const SizedBox(width: 8),
                  // Cancel button
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
                          color: _Glass.accentRose.withValues(alpha: 0.30),
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
                  const SizedBox(width: 8),
                  // Invoice button
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
                              builder: (_) => InvoiceScreen(invoiceId: invId),
                            ),
                          );
                        } else if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('No invoice yet for this order'),
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
                  // Message button
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
        ),
      ),
    );
  }
}

// =============================================================================
// _DueDateRow — compact due-date chip shown on each queue card
// =============================================================================
class _DueDateRow extends StatelessWidget {
  final DateTime dueDate;
  const _DueDateRow({required this.dueDate});

  @override
  Widget build(BuildContext context) {
    final now  = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due   = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final diff  = due.difference(today).inDays;

    final Color color;
    final String label;

    if (diff < 0) {
      color = _Glass.accentRose;
      label = 'Overdue by ${-diff} day${diff == -1 ? '' : 's'} — ${_fmt(dueDate)}';
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
        Icon(Icons.flag_rounded, size: 14, color: color.withValues(alpha: 0.85)),
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
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }
}

// =============================================================================
// _DeadlineAlertBanner — sticky alert at top of Job Queue for urgent orders
// =============================================================================
class _DeadlineAlertBanner extends StatefulWidget {
  const _DeadlineAlertBanner();
  @override
  State<_DeadlineAlertBanner> createState() => _DeadlineAlertBannerState();
}

class _DeadlineAlertBannerState extends State<_DeadlineAlertBanner> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final now       = DateTime.now();
    final threshold = now.add(const Duration(days: 2));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Orders')
          .where('status', whereIn: ['pending', 'in_production'])
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const SizedBox.shrink();

        final due = snap.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final ts = data['estimated_completion'] as Timestamp?;
          if (ts == null) return false;
          return ts.toDate().isBefore(threshold);
        }).toList()
          ..sort((a, b) {
            final ta = ((a.data() as Map)['estimated_completion'] as Timestamp?)?.toDate();
            final tb = ((b.data() as Map)['estimated_completion'] as Timestamp?)?.toDate();
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return ta.compareTo(tb);
          });

        if (due.isEmpty) return const SizedBox.shrink();

        final overdueCount = due.where((doc) {
          final ts = ((doc.data() as Map)['estimated_completion'] as Timestamp?)?.toDate();
          return ts != null && ts.isBefore(now);
        }).length;

        final isUrgent = overdueCount > 0;
        final accent   = isUrgent ? _Glass.accentRose : _Glass.accentAmber;

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
                          isUrgent ? Icons.warning_amber_rounded : Icons.access_time_rounded,
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
                          _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
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
                          final data      = doc.data() as Map<String, dynamic>;
                          final orderId   = data['order_id']?.toString() ?? doc.id;
                          final customer  = data['customer_name']?.toString() ?? '—';
                          final status    = data['status']?.toString() ?? '';
                          final ts        = data['estimated_completion'] as Timestamp?;
                          final dueDate   = ts?.toDate().toLocal();
                          final isOverdue = dueDate != null && dueDate.isBefore(now);
                          final todayMid  = DateTime(now.year, now.month, now.day);
                          final dueMid    = dueDate != null
                              ? DateTime(dueDate.year, dueDate.month, dueDate.day)
                              : null;
                          final diff      = dueMid?.difference(todayMid).inDays;
                          final rowColor  = isOverdue ? _Glass.accentRose : _Glass.accentAmber;
                          final dueLabel  = dueDate == null
                              ? '—'
                              : diff! < 0
                                  ? 'Overdue (${_fmtBanner(dueDate)})'
                                  : diff == 0
                                      ? 'Due TODAY'
                                      : 'Due ${_fmtBanner(dueDate)}';
                          final statusLabel = status == 'in_production' ? 'Active' : 'Pending';

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
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _Glass.surfaceThin,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: _Glass.borderMid, width: 0.7),
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
                                      horizontal: 8, vertical: 3),
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
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${m[d.month - 1]} ${d.day}';
  }
}
