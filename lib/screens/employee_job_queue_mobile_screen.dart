// employee_mobile_job_queue_screen.dart
// ---------------------------------------------------------------------------
// READ-ONLY Job Queue for employees on Android / iOS.
//
// • Shows the same Firestore data as the full EmployeeJobQueueScreen.
// • All write actions (Start Job, Mark Ready, Cancel, Add Walk-in) are hidden.
// • A persistent banner reminds the user that they are in read-only mode.
// • Tab layout mirrors the web version so the experience is familiar:
//     Pending | Active | Ready for Pickup | Cancelled | Order History
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'design_file_viewer.dart';

// =============================================================================
// Design Tokens — Liquid Glass
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

class EmployeeMobileJobQueueScreen extends StatefulWidget {
  const EmployeeMobileJobQueueScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<EmployeeMobileJobQueueScreen> createState() =>
      _EmployeeMobileJobQueueScreenState();
}

class _EmployeeMobileJobQueueScreenState
    extends State<EmployeeMobileJobQueueScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // Live counts from Firestore — mirrors the web version's tab badges
  final Map<int, int> _counts = {};
  final List<StreamSubscription<QuerySnapshot>> _countSubs = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 4),
    );
    _tabs.addListener(() => setState(() {}));
    _subscribeCount(0, 'pending');
    _subscribeCount(1, 'in_production');
    _subscribeCount(2, 'ready');
    _subscribeCount(3, 'cancelled');
  }

  void _subscribeCount(int idx, String status) {
    final sub = FirebaseFirestore.instance
        .collection('Orders')
        .where('status', isEqualTo: status)
        .snapshots()
        .listen((snap) {
          if (mounted) setState(() => _counts[idx] = snap.size);
        });
    _countSubs.add(sub);
  }

  @override
  void dispose() {
    for (final s in _countSubs) s.cancel();
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Frosted-glass header ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: ClipRRect(
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
                            Icons.work_outline_rounded,
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
                                'View-only — manage orders on web',
                                style: TextStyle(
                                  color: _Glass.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Read-only lock badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _Glass.accentAmber.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _Glass.accentAmber.withValues(alpha: 0.30),
                              width: 0.8,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_outline_rounded,
                                  size: 11, color: _Glass.accentAmber),
                              SizedBox(width: 4),
                              Text(
                                'View only',
                                style: TextStyle(
                                  color: _Glass.accentAmber,
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
                    Divider(height: 1, color: _Glass.borderDim),
                    const SizedBox(height: 12),
                    // ── Pill segment tab bar ───────────────────────────────
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: _PillSegmentControl<int>(
                        selected: _tabs.index,
                        onChanged: (i) => setState(() => _tabs.animateTo(i)),
                        items: [
                          _PillSegmentItem(
                            value: 0,
                            label: 'Pending',
                            icon: Icons.hourglass_empty_rounded,
                            accent: _Glass.accentAmber,
                            count: _counts[0],
                          ),
                          _PillSegmentItem(
                            value: 1,
                            label: 'Active',
                            icon: Icons.play_circle_outline_rounded,
                            accent: _Glass.accentBlue,
                            count: _counts[1],
                          ),
                          _PillSegmentItem(
                            value: 2,
                            label: 'Ready',
                            icon: Icons.check_circle_outline_rounded,
                            accent: _Glass.accentEmerald,
                            count: _counts[2],
                          ),
                          _PillSegmentItem(
                            value: 3,
                            label: 'Cancelled',
                            icon: Icons.cancel_outlined,
                            accent: _Glass.accentRose,
                            count: _counts[3],
                          ),
                          const _PillSegmentItem(
                            value: 4,
                            label: 'History',
                            icon: Icons.history_rounded,
                            accent: _navyBlue,
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

        const SizedBox(height: 8),

        // ── Deadline alert banner ──────────────────────────────────────────
        const _MobileDeadlineBanner(),

        // ── Tab views ──────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _MobileQueueList(status: 'pending'),
              _MobileQueueList(status: 'in_production'),
              _MobileQueueList(status: 'ready'),
              _MobileQueueList(status: 'cancelled'),
              const _MobileOrderHistory(),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────

String _fmtDate(dynamic ts) {
  if (ts == null) return '—';
  try {
    final d = (ts as Timestamp).toDate().toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  } catch (_) {
    return '—';
  }
}

Color _statusColor(String s) {
  switch (s) {
    case 'pending':
      return Colors.amber;
    case 'in_production':
      return Colors.blueAccent;
    case 'ready':
      return Colors.green;
    case 'completed':
      return Colors.green;
    case 'cancelled':
      return Colors.redAccent;
    default:
      return Colors.white54;
  }
}

String _statusLabel(String s) {
  switch (s) {
    case 'in_production':
      return 'Active';
    case 'ready':
      return 'Ready for Pickup';
    default:
      return s[0].toUpperCase() + s.substring(1);
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
  final int? count;
  const _PillSegmentItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.accent,
    this.count,
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
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    if (item.count != null && item.count! > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
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
// ── Single-status list (Pending / Active / Ready / Cancelled) ──────────────

class _MobileQueueList extends StatefulWidget {
  final String status;
  const _MobileQueueList({required this.status});

  @override
  State<_MobileQueueList> createState() => _MobileQueueListState();
}

class _MobileQueueListState extends State<_MobileQueueList> {
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Stream<List<QueryDocumentSnapshot>> _stream() {
    return FirebaseFirestore.instance
        .collection('Orders')
        .where('status', isEqualTo: widget.status)
        .snapshots()
        .map((s) {
      final docs = [...s.docs]..sort((a, b) {
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
      children: [
        // ── Search bar (mirrors web version) ─────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: _blurFilter,
              child: Container(
                height: 40,
                decoration: _Glass.glass(radius: 12),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: _Glass.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search order ID or customer…',
                    hintStyle: const TextStyle(color: _Glass.textMuted, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded,
                        size: 16, color: _Glass.textMuted),
                    suffixIcon: _search.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              setState(() => _search = '');
                            },
                            child: const Icon(Icons.close_rounded,
                                size: 16, color: _Glass.textMuted),
                          )
                        : null,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                  onChanged: (v) => setState(() => _search = v.trim()),
                ),
              ),
            ),
          ),
        ),
        // ── Card list ─────────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<QueryDocumentSnapshot>>(
            stream: _stream(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: AppTheme.gold));
              }
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Error loading orders: ${snap.error}',
                      style: TextStyle(
                          color: Colors.redAccent.withValues(alpha: 0.8),
                          fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              var docs = snap.data ?? [];
              if (_search.isNotEmpty) {
                final q = _search.toLowerCase();
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return (data['order_id'] ?? '').toString().toLowerCase().contains(q) ||
                      (data['customer_name'] ?? '').toString().toLowerCase().contains(q) ||
                      (data['customer_id'] ?? '').toString().toLowerCase().contains(q);
                }).toList();
              }
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_rounded,
                          size: 48, color: Colors.white.withValues(alpha: 0.2)),
                      const SizedBox(height: 12),
                      Text(
                        _search.isNotEmpty
                            ? 'No results for "$_search"'
                            : 'No ${_statusLabel(widget.status).toLowerCase()} orders',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 14),
                      ),
                    ],
                  ),
                );
              }
              // ── Responsive: constrained width on tablet/wide screens ────
              return LayoutBuilder(
                builder: (_, constraints) {
                  final wide = constraints.maxWidth >= 600;
                  final hPad = wide ? 32.0 : 16.0;
                  return Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: ListView.builder(
                        padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 20),
                        itemCount: docs.length,
                        itemBuilder: (_, i) =>
                            _MobileOrderCard(doc: docs[i], showStatus: false),
                      ),
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

// ── Order history (all statuses) ───────────────────────────────────────────

class _MobileOrderHistory extends StatefulWidget {
  const _MobileOrderHistory();

  @override
  State<_MobileOrderHistory> createState() => _MobileOrderHistoryState();
}

class _MobileOrderHistoryState extends State<_MobileOrderHistory> {
  String _filter = 'all';
  String _search = '';
  final _ctrl = TextEditingController();

  static const _filterOpts = [
    ('all', 'All'),
    ('pending', 'Pending'),
    ('in_production', 'Active'),
    ('ready', 'Ready'),
    ('completed', 'Completed'),
    ('cancelled', 'Cancelled'),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Stream<List<QueryDocumentSnapshot>> _stream() {
    Query q = FirebaseFirestore.instance.collection('Orders');
    if (_filter == 'all') {
      q = q.where('status', whereIn: [
        'pending', 'in_production', 'ready', 'completed', 'cancelled'
      ]);
    } else {
      q = q.where('status', isEqualTo: _filter);
    }
    return q.snapshots().map((snap) {
      final docs = [...snap.docs]..sort((a, b) {
        final ta = (a.data() as Map)['created_at'] as Timestamp?;
        final tb = (b.data() as Map)['created_at'] as Timestamp?;
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
      children: [
        // Search + filter
        // ── Search + filter chips ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search field
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: _blurFilter,
                  child: Container(
                    height: 38,
                    decoration: _Glass.glass(radius: 12),
                    child: TextField(
                      controller: _ctrl,
                      style: const TextStyle(
                          color: _Glass.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search order ID or customer…',
                        hintStyle: const TextStyle(
                            color: _Glass.textMuted, fontSize: 13),
                        prefixIcon: const Icon(Icons.search,
                            size: 16, color: _Glass.textMuted),
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                      ),
                      onChanged: (v) => setState(() => _search = v.trim()),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Filter pill chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filterOpts.map((opt) {
                    final isActive = _filter == opt.$1;
                    final chipColor = switch (opt.$1) {
                      'pending'      => _Glass.accentAmber,
                      'in_production'=> _Glass.accentBlue,
                      'ready'        => _Glass.accentEmerald,
                      'completed'    => _Glass.accentEmerald,
                      'cancelled'    => _Glass.accentRose,
                      _              => _navyBlue,
                    };
                    return GestureDetector(
                      onTap: () => setState(() => _filter = opt.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: isActive
                            ? BoxDecoration(
                          color: chipColor,
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: [
                            BoxShadow(
                              color: chipColor.withValues(alpha: 0.28),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        )
                            : BoxDecoration(
                          color: _Glass.surfaceThin,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                              color: _Glass.borderMid, width: 0.9),
                        ),
                        child: Text(
                          opt.$2,
                          style: TextStyle(
                            color:
                            isActive ? Colors.white : _Glass.textSecondary,
                            fontSize: 12,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: StreamBuilder<List<QueryDocumentSnapshot>>(
            stream: _stream(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child:
                    CircularProgressIndicator(color: AppTheme.gold));
              }
              var docs = snap.data ?? [];
              if (_search.isNotEmpty) {
                final q = _search.toLowerCase();
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return d.id.toLowerCase().contains(q) ||
                      (data['customer_name'] ?? '')
                          .toString()
                          .toLowerCase()
                          .contains(q);
                }).toList();
              }
              if (docs.isEmpty) {
                return Center(
                  child: Text('No orders found.',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 14)),
                );
              }
              return LayoutBuilder(
                builder: (_, constraints) {
                  final wide = constraints.maxWidth >= 600;
                  final hPad = wide ? 32.0 : 16.0;
                  return Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: ListView.builder(
                        padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 20),
                        itemCount: docs.length,
                        itemBuilder: (_, i) =>
                            _MobileOrderCard(doc: docs[i], showStatus: true),
                      ),
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

// ── Helpers ────────────────────────────────────────────────────────────────

String _resolveNotes(Map<String, dynamic> data) {
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

// ── Read-only order card (Liquid Glass style) ──────────────────────────────

class _MobileOrderCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final bool showStatus;

  const _MobileOrderCard({required this.doc, required this.showStatus});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final orderId = data['order_id']?.toString().isNotEmpty == true
        ? data['order_id'].toString()
        : '#${doc.id.length > 8 ? doc.id.substring(0, 8).toUpperCase() : doc.id.toUpperCase()}';
    final customerName = data['customer_name']?.toString() ?? 'Unknown Customer';
    final customerId = data['customer_id']?.toString() ?? '';
    final status = data['status']?.toString() ?? 'pending';
    final products = (data['products'] as List<dynamic>?)?.cast<Map>() ?? [];
    final total = (data['total_price'] as num?)?.toDouble() ?? 0.0;
    final amountPaid = (data['amount_paid'] as num?)?.toDouble() ?? 0.0;
    final dateStr = _fmtDate(data['created_at']);
    final isWalkIn = data['walk_in'] == true;

    final statusColor = switch (status) {
      'in_production' => _Glass.accentBlue,
      'ready'         => _Glass.accentEmerald,
      'cancelled'     => _Glass.accentRose,
      'completed'     => _Glass.accentEmerald,
      _               => _Glass.accentAmber,
    };
    final statusLabel = switch (status) {
      'in_production' => 'Active',
      'ready'         => 'Ready for Pickup',
      'completed'     => 'Completed',
      'cancelled'     => 'Cancelled',
      _               => 'Pending',
    };

    final DateTime? estimatedCompletion = (() {
      final ts = data['estimated_completion'] as Timestamp?;
      if (ts != null) return ts.toDate().toLocal();
      final created = (data['created_at'] as Timestamp?)?.toDate().toLocal();
      final ta = data['turnaround_days'] as int?;
      if (created == null || ta == null) return null;
      return created.add(Duration(days: ta));
    })();

    final productSummary = products.isNotEmpty
        ? products.map((p) => '${p['name'] ?? '?'} ×${p['qty'] ?? 1}').join(', ')
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _BlurCard(
        radius: 14,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: order ID + walk-in badge + status pill ──────────
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
                            orderId,
                            style: const TextStyle(
                              color: _Glass.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (isWalkIn) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _Glass.accentAmber.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _Glass.accentAmber.withValues(alpha: 0.40),
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
                      const SizedBox(height: 2),
                      Text(
                        customerName,
                        style: const TextStyle(
                          color: _Glass.textSecondary,
                          fontSize: 12,
                        ),
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
                if (showStatus)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 4),
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

            // ── Products ────────────────────────────────────────────────
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
              DesignFilesSection(products: products),
            ],

            // ── Special instructions ────────────────────────────────────
            Builder(builder: (_) {
              final notes = _resolveNotes(data);
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes_outlined,
                        size: 12, color: _Glass.textMuted),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Special Instructions: ${notes.isNotEmpty ? notes : 'None'}',
                        style: const TextStyle(
                            color: _Glass.textMuted, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              );
            }),

            // ── Due date row ─────────────────────────────────────────────
            if (estimatedCompletion != null &&
                status != 'cancelled' &&
                status != 'completed') ...[
              const SizedBox(height: 6),
              _DueDateRow(
                  dueDate: estimatedCompletion, statusColor: statusColor),
            ],

            const SizedBox(height: 10),
            Divider(height: 0.8, color: _Glass.borderDim),
            const SizedBox(height: 8),

            // ── Footer: date + total ─────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 11, color: _Glass.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(dateStr,
                      style: const TextStyle(
                          color: _Glass.textMuted, fontSize: 12)),
                ),
                Column(
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
                    if (amountPaid > 0)
                      Text(
                        'Paid: ₱${amountPaid.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: _Glass.accentEmerald,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // ── Read-only notice ─────────────────────────────────────────
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.remove_red_eye_outlined,
                    size: 12,
                    color: _Glass.textMuted.withValues(alpha: 0.5)),
                const SizedBox(width: 4),
                Text(
                  'Read-only — open on web to manage this order',
                  style: TextStyle(
                    color: _Glass.textMuted.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
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
// _DueDateRow
// =============================================================================
class _DueDateRow extends StatelessWidget {
  final DateTime dueDate;
  final Color? statusColor;
  const _DueDateRow({required this.dueDate, this.statusColor});

  @override
  Widget build(BuildContext context) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due   = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final diff  = due.difference(today).inDays;

    final Color color;
    final String label;

    if (diff < 0) {
      color = _Glass.accentRose;
      label = 'Overdue by ${-diff} day${diff == -1 ? '' : 's'} (${_fmt(dueDate)})';
    } else if (diff == 0) {
      color = _Glass.accentRose;
      label = 'Target completion: TODAY';
    } else if (diff == 1) {
      color = _Glass.accentAmber;
      label = 'Target completion: Tomorrow, ${_fmt(dueDate)}';
    } else {
      color = _Glass.accentEmerald;
      label = 'Target completion: ${_fmt(dueDate)}';
    }

    return Row(
      children: [
        if (statusColor != null) ...[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Icon(Icons.flag_rounded, size: 14,
            color: color.withValues(alpha: 0.85)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: diff <= 0 ? FontWeight.w700 : FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
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
// _MobileDeadlineBanner — sticky alert banner at top of mobile job queue
// =============================================================================
class _MobileDeadlineBanner extends StatefulWidget {
  const _MobileDeadlineBanner();
  @override
  State<_MobileDeadlineBanner> createState() => _MobileDeadlineBannerState();
}

class _MobileDeadlineBannerState extends State<_MobileDeadlineBanner> {
  bool _expanded = false;

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
          final ts   = data['estimated_completion'] as Timestamp?;
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
        final accent = isUrgent ? _Glass.accentRose : _Glass.accentAmber;

        return AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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
                                ? '$overdueCount overdue${due.length - overdueCount > 0 ? ' · ${due.length - overdueCount} due soon' : ''}'
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
                  ...due.map((doc) {
                    final data     = doc.data() as Map<String, dynamic>;
                    final orderId  = data['order_id']?.toString() ?? doc.id;
                    final customer = data['customer_name']?.toString() ?? '—';
                    final ts       = data['estimated_completion'] as Timestamp?;
                    final dueDate  = ts?.toDate().toLocal();
                    final isOver   = dueDate != null && dueDate.isBefore(now);
                    final todayMid = DateTime(now.year, now.month, now.day);
                    final dueMid   = dueDate != null
                        ? DateTime(dueDate.year, dueDate.month, dueDate.day)
                        : null;
                    final diff     = dueMid?.difference(todayMid).inDays;
                    final c = isOver ? _Glass.accentRose : _Glass.accentAmber;
                    final dueLabel = dueDate == null
                        ? '—'
                        : diff! < 0
                            ? 'Overdue'
                            : diff == 0 ? 'Due TODAY' : 'Due ${_fmtBanner(dueDate)}';

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 7),
                      child: Row(
                        children: [
                          const SizedBox(width: 22),
                          Expanded(
                            child: Text(
                              '$orderId · $customer',
                              style: TextStyle(
                                color: _Glass.textSecondary,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              dueLabel,
                              style: TextStyle(
                                color: c,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
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
