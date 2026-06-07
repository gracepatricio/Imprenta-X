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

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'design_file_viewer.dart';

class EmployeeMobileJobQueueScreen extends StatefulWidget {
  const EmployeeMobileJobQueueScreen({super.key});

  @override
  State<EmployeeMobileJobQueueScreen> createState() =>
      _EmployeeMobileJobQueueScreenState();
}

class _EmployeeMobileJobQueueScreenState
    extends State<EmployeeMobileJobQueueScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  static const _tabLabels = [
    'Pending',
    'Active',
    'Ready',
    'Cancelled',
    'History',
  ];

  // Firestore status values that map to each tab
  static const _tabStatuses = [
    'pending',
    'in_production',
    'ready',
    'cancelled',
    null, // History = all statuses
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Read-only banner ───────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.amber.withValues(alpha: 0.15),
          child: Row(
            children: [
              const Icon(Icons.lock_outline_rounded,
                  size: 14, color: Colors.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'View-only mode — job management is available on web.',
                  style: TextStyle(
                    color: Colors.amber.shade200,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Tab bar ────────────────────────────────────────────────────────
        Container(
          color: Colors.white.withValues(alpha: 0.04),
          child: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppTheme.gold,
            indicatorWeight: 2.5,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 13,
            ),
            tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
          ),
        ),

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

// ── Single-status list (Pending / Active / Ready / Cancelled) ──────────────

class _MobileQueueList extends StatelessWidget {
  final String status;
  const _MobileQueueList({required this.status});

  Stream<List<QueryDocumentSnapshot>> _stream() {
    final q = FirebaseFirestore.instance
        .collection('Orders')
        .where('status', isEqualTo: status);
    return q.snapshots().map((s) {
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
    return StreamBuilder<List<QueryDocumentSnapshot>>(
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
        final docs = snap.data ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_rounded,
                    size: 48, color: Colors.white.withValues(alpha: 0.2)),
                const SizedBox(height: 12),
                Text(
                  'No ${_statusLabel(status).toLowerCase()} orders',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 14),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          itemCount: docs.length,
          itemBuilder: (_, i) =>
              _MobileOrderCard(doc: docs[i], showStatus: false),
        );
      },
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              // Search field
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _ctrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search order ID or customer…',
                      hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 13),
                      prefixIcon: Icon(Icons.search,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.4)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) => setState(() => _search = v.trim()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Status filter
              SizedBox(
                height: 36,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _filter,
                    dropdownColor: const Color(0xFF1E2235),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    borderRadius: BorderRadius.circular(10),
                    items: _filterOpts
                        .map((o) => DropdownMenuItem(
                        value: o.$1,
                        child: Text(o.$2,
                            style: const TextStyle(fontSize: 12))))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _filter = v ?? 'all'),
                  ),
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
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                itemCount: docs.length,
                itemBuilder: (_, i) =>
                    _MobileOrderCard(doc: docs[i], showStatus: true),
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

// ── Read-only order card ───────────────────────────────────────────────────

class _MobileOrderCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final bool showStatus;

  const _MobileOrderCard({required this.doc, required this.showStatus});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final orderId = doc.id;
    final customer =
        data['customer_name']?.toString() ?? 'Unknown Customer';
    final customerId = data['customer_id']?.toString() ?? '';
    final status = data['status']?.toString() ?? 'pending';
    final products =
        (data['products'] as List<dynamic>?)?.cast<Map>() ?? [];
    final total = (data['total_price'] as num?)?.toDouble() ?? 0.0;
    final turnaround = data['turnaround_days'] as int?;
    final date = _fmtDate(data['created_at']);
    final color = _statusColor(status);

    // Estimated completion — from stored Timestamp or computed fallback
    final DateTime? estimatedCompletion = (() {
      final ts = data['estimated_completion'] as Timestamp?;
      if (ts != null) return ts.toDate().toLocal();
      final created = (data['created_at'] as Timestamp?)?.toDate().toLocal();
      final ta = data['turnaround_days'] as int?;
      if (created == null || ta == null) return null;
      return created.add(Duration(days: ta));
    })();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border:
        Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Expanded(
                child: Text(
                  customer,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showStatus)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: color.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),

          // Order ID + Customer ID
          Row(
            children: [
              Text(
                data['order_id']?.toString().isNotEmpty == true
                    ? data['order_id'].toString()
                    : '#${orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase()}',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11),
              ),
              if (customerId.isNotEmpty) ...[
                Text(
                  '  ·  ID: $customerId',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Products
          if (products.isNotEmpty) ...[
            Text(
              products
                  .map((p) =>
              '${p['name'] ?? '?'} ×${p['qty'] ?? 1}')
                  .join(', '),
              style:
              const TextStyle(color: Colors.white70, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            DesignFilesSection(products: products),
            const SizedBox(height: 8),
          ],

          // Special instructions
          Builder(builder: (_) {
            final notes = _resolveNotes(data);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes_outlined,
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.4)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Special Instructions: ${notes.isNotEmpty ? notes : 'None'}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 11),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Footer row
          Row(
            children: [
              Icon(Icons.schedule,
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.4)),
              const SizedBox(width: 4),
              Text(
                turnaround != null
                    ? '$turnaround day${turnaround == 1 ? '' : 's'}'
                    : 'TBD',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11),
              ),
              const SizedBox(width: 12),
              Icon(Icons.calendar_today,
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.4)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  date,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11),
                ),
              ),
              Text(
                '₱${total.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: AppTheme.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ],
          ),

          // Target completion row
          if (estimatedCompletion != null && status != 'cancelled' &&
              status != 'completed') ...[
            const SizedBox(height: 5),
            _MobileDueDateRow(dueDate: estimatedCompletion),
          ],

          // Read-only notice in place of action buttons
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.remove_red_eye_outlined,
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.25)),
              const SizedBox(width: 4),
              Text(
                'Read-only — open on web to manage this order',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25),
                    fontSize: 11,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _MobileDueDateRow — compact due-date indicator for mobile order cards
// =============================================================================
class _MobileDueDateRow extends StatelessWidget {
  final DateTime dueDate;
  const _MobileDueDateRow({required this.dueDate});

  @override
  Widget build(BuildContext context) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due   = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final diff  = due.difference(today).inDays;

    final Color color;
    final String label;

    if (diff < 0) {
      color = Colors.redAccent;
      label = 'Overdue by ${-diff} day${diff == -1 ? '' : 's'} (${_fmt(dueDate)})';
    } else if (diff == 0) {
      color = Colors.redAccent;
      label = 'Target completion: TODAY';
    } else if (diff == 1) {
      color = Colors.amber;
      label = 'Target completion: Tomorrow, ${_fmt(dueDate)}';
    } else {
      color = Colors.greenAccent.shade400;
      label = 'Target completion: ${_fmt(dueDate)}';
    }

    return Row(
      children: [
        Icon(Icons.flag_rounded, size: 11, color: color.withValues(alpha: 0.85)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: diff <= 0 ? FontWeight.w700 : FontWeight.w400,
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
        final accent   = isUrgent ? Colors.redAccent : Colors.amber;

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
                    final c        = isOver ? Colors.redAccent : Colors.amber;
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
                                color: Colors.white.withValues(alpha: 0.65),
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
