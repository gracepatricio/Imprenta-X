import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_theme.dart';
import 'sales_widgets.dart';
import 'employee_pos_screen.dart';
import 'invoice_screen.dart';
import '../services/inventory_service.dart';

class EmployeeLogsScreen extends StatefulWidget {
  // 0 = Job Queue Pending, 1 = Job Queue Active, 2 = Ready for Pickup
  final int initialJobQueueTab;
  const EmployeeLogsScreen({super.key, this.initialJobQueueTab = 0});

  @override
  State<EmployeeLogsScreen> createState() => _EmployeeLogsScreenState();
}

class _EmployeeLogsScreenState extends State<EmployeeLogsScreen> {
  int _topTab = 0; // 0 = Job Queue, 1 = Sales Record, 2 = POS

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PillTabBar(
            tabs: const ['Job Queue', 'Sales Record', 'POS'],
            active: _topTab,
            onTap: (i) => setState(() => _topTab = i),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: switch (_topTab) {
              0 => _JobQueueSection(initialTab: widget.initialJobQueueTab),
              1 => const _SalesSection(),
              2 => const EmployeePosScreen(),
              _ => const SizedBox.shrink(),
            },
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
            thickness: 1,
          ),
          Expanded(
            child: _subTab == 0
                ? const SalesRecordTable() // ← from sales_widgets.dart
                : const SalesReportView(), // ← from sales_widgets.dart
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
  const _PillTabBar({
    required this.tabs,
    required this.active,
    required this.onTap,
  });

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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
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
  const _UnderlineTabBar({
    required this.tabs,
    required this.active,
    required this.onTap,
  });

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
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// =============================================================================
// Job Queue Section — 5 sub-tabs: Pending, Active, Ready for Pickup,
// Cancelled, Order History
// =============================================================================
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
    return Column(
      children: [
        // Tab bar row
        Row(
          children: [
            Expanded(
              child: _UnderlineTabBar(
                tabs: _tabLabels,
                active: _tabs.index,
                onTap: (i) => _tabs.animateTo(i),
              ),
            ),
            // Add walk-in button (hidden on Order History tab)
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
                  decoration: BoxDecoration(
                    color: AppTheme.gold,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    size: 20,
                    color: Colors.black,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
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
      ],
    );
  }
}

// =============================================================================
// Employee Order History tab (inside job queue)
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
                  decoration: BoxDecoration(
                    color: active
                        ? AppTheme.gold
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active
                          ? AppTheme.gold
                          : Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Text(
                    opt.$2,
                    style: TextStyle(
                      color: active ? Colors.black : Colors.white70,
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
        TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search by order ID or customer…',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
            prefixIcon: const Icon(
              Icons.search,
              color: Colors.white38,
              size: 18,
            ),
            suffixIcon: _search.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() => _search = '');
                    },
                    child: const Icon(
                      Icons.clear,
                      color: Colors.white38,
                      size: 18,
                    ),
                  )
                : null,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.gold.withValues(alpha: 0.5),
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
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.gold),
                );
              }
              if (snap.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snap.error}',
                    style: const TextStyle(
                      color: Colors.redAccent,
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
                  return id.contains(_search) || name.contains(_search);
                }).toList();
              }

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.history,
                        size: 52,
                        color: Colors.white24,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'No orders found',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
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

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: AppTheme.glassCard(opacity: 0.13, radius: 16),
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
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$customer · $dateStr',
                                      style: const TextStyle(
                                        color: Colors.white54,
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
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: statusColor.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  _statusLabel(status),
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          if (products.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              products
                                  .map(
                                    (p) =>
                                        '${p['name'] ?? '?'} ×${p['qty'] ?? 1}',
                                  )
                                  .join(', '),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],

                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _Chip(
                                'Total',
                                '₱${total.toStringAsFixed(2)}',
                                Colors.white70,
                              ),
                              const SizedBox(width: 10),
                              _Chip(
                                'Paid',
                                '₱${paid.toStringAsFixed(2)}',
                                Colors.green,
                              ),
                              const SizedBox(width: 10),
                              _Chip(
                                remaining < 0.01 ? 'Fully Paid' : 'Balance',
                                remaining < 0.01
                                    ? '—'
                                    : '₱${remaining.toStringAsFixed(2)}',
                                remaining < 0.01 ? Colors.green : AppTheme.gold,
                                bold: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Invoice button
                          Builder(
                            builder: (ctx) => OutlinedButton.icon(
                              onPressed: () async {
                                String? invId = invoiceId;
                                if (invId == null) {
                                  final orderSnap = await FirebaseFirestore
                                      .instance
                                      .collection('Orders')
                                      .doc(doc.id)
                                      .get();
                                  invId = orderSnap
                                      .data()?['invoice_id']
                                      ?.toString();
                                }
                                if (invId != null && ctx.mounted) {
                                  Navigator.of(ctx).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          InvoiceScreen(invoiceId: invId!),
                                    ),
                                  );
                                } else if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'No invoice for this order',
                                      ),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(
                                Icons.receipt_long_rounded,
                                size: 16,
                                color: AppTheme.gold,
                              ),
                              label: const Text(
                                'View Invoice',
                                style: TextStyle(
                                  color: AppTheme.gold,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: AppTheme.gold.withValues(alpha: 0.5),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
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

// ── Walk-in Job Order Dialog ──────────────────────────────────────────────────

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
    if (mounted)
      setState(() {
        _products = snap.docs;
        _loadingProducts = false;
      });
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
    final days = _items.fold<double>(0.0, (s, item) {
      final cat = (item.productData['category']?.toString() ?? '')
          .toLowerCase();
      final qty = item.qty;
      double d;
      if (cat.contains('calling card')) {
        if (qty <= 100)
          d = 0.5;
        else if (qty <= 500)
          d = 1.0;
        else
          d = (qty / 500).ceilToDouble().clamp(2.0, 7.0);
      } else if (cat.contains('sticker') || cat.contains('photo')) {
        if (qty <= 50)
          d = 0.5;
        else if (qty <= 200)
          d = 1.0;
        else
          d = (qty / 200).ceilToDouble().clamp(2.0, 5.0);
      } else if (cat.contains('large format')) {
        d = 1.0;
      } else if (cat.contains('invitation')) {
        if (qty <= 50)
          d = 1.0;
        else if (qty <= 200)
          d = 2.0;
        else
          d = 3.0;
      } else {
        d = 1.0;
      }
      return s + d;
    });
    return days.ceil().clamp(1, 21);
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
        'order_id': orderId,
        'customer_uid': '',
        'customer_name': customerName,
        'job_status': 'pending',
        'turnaround_days': turnaroundDays,
        'products': products,
        'total_price': total,
        'walk_in': true,
        'created_at': now,
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
            backgroundColor: Colors.red.shade700,
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
      backgroundColor: const Color(0xFF1a1a2e),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
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
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'New Walk-In Job Order',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Walk-in customer · cash or GCash',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white54,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _nameCtrl,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          decoration: AppTheme.inputDecoration(
                            'Customer Name *',
                            icon: Icons.person_outline,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _emailCtrl,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          decoration: AppTheme.inputDecoration(
                            'Customer Email (optional)',
                            icon: Icons.email_outlined,
                          ),
                        ),
                        const SizedBox(height: 20),

                        Row(
                          children: [
                            const Text(
                              'Products',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: _loadingProducts
                                  ? null
                                  : _showAddProductSheet,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.gold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppTheme.gold.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.add_rounded,
                                      size: 14,
                                      color: AppTheme.gold,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _loadingProducts
                                          ? 'Loading…'
                                          : 'Add Product',
                                      style: const TextStyle(
                                        color: AppTheme.gold,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
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
                            decoration: AppTheme.glassCard(
                              opacity: 0.08,
                              radius: 10,
                            ),
                            child: const Center(
                              child: Text(
                                'No products added yet.',
                                style: TextStyle(
                                  color: Colors.white38,
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
                              decoration: AppTheme.glassCard(
                                opacity: 0.12,
                                radius: 12,
                              ),
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
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
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
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                        ),
                                        if (item.notes.isNotEmpty)
                                          Text(
                                            item.notes,
                                            style: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 11,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () =>
                                        setState(() => _items.removeAt(i)),
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                      color: Colors.redAccent,
                                      size: 18,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
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
                              color: AppTheme.gold.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.gold.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Est. Turnaround: ~$_turnaround day${_turnaround == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'Total: ₱${_total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: AppTheme.gold,
                                    fontWeight: FontWeight.bold,
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
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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
                        TextFormField(
                          controller: _paidCtrl,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: AppTheme.inputDecoration(
                            'Amount Paid (₱) *',
                            icon: Icons.monetization_on_outlined,
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
                        TextFormField(
                          controller: _notesCtrl,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          decoration: AppTheme.inputDecoration(
                            'Order Notes (optional)',
                            icon: Icons.notes_outlined,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting
                            ? null
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.gold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black54,
                                ),
                              )
                            : const Text(
                                'Create Job Order',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.gold.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? AppTheme.gold.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? AppTheme.gold : Colors.white54,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? AppTheme.gold : Colors.white54,
                fontSize: 13,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Walk-in item model ────────────────────────────────────────────────────────

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

// ── Product picker dialog ─────────────────────────────────────────────────────

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
    'Large Format Printing': ['Standard Tarp', 'Premium Tarp', 'Mesh Tarp'],
    'Sticker Printing': ['Glossy Vinyl', 'Matte Vinyl', 'Clear Vinyl'],
    'Photo Printing': ['Glossy', 'Matte', 'Satin'],
    'Menu Board': ['Standard', 'Premium Backlit'],
    'Invitations': ['Matte', 'Glossy', 'Kraft Paper'],
    'Calling Cards': ['Matte', 'Glossy', 'UV Coated'],
  };

  static const _categories = [
    'Large Format Printing',
    'Menu Boards',
    'Stationery & Cards',
    'Sticker Printing',
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

  List<QueryDocumentSnapshot> get _filtered {
    return widget.products.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['product_name']?.toString() ?? '').toLowerCase();
      final cat = data['category']?.toString() ?? '';
      final matchSearch =
          _search.isEmpty || name.contains(_search.toLowerCase());
      final matchCategory = _category == null || cat == _category;
      return matchSearch && matchCategory;
    }).toList();
  }

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
      backgroundColor: const Color(0xFF1a1a2e),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Select Product',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white54,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search products…',
                  hintStyle: const TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.white38,
                    size: 18,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.07),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: AppTheme.gold.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

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

              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'No products found.',
                          style: TextStyle(color: Colors.white38, fontSize: 13),
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
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.gold.withValues(alpha: 0.12)
                                    : Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.gold.withValues(alpha: 0.5)
                                      : Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
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
                                            color: Colors.white,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (cat.isNotEmpty)
                                          Text(
                                            cat,
                                            style: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 10,
                                            ),
                                          ),
                                        if (desc.isNotEmpty)
                                          Text(
                                            desc,
                                            style: const TextStyle(
                                              color: Colors.white38,
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
                                                ? AppTheme.gold
                                                : Colors.white70,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (unit.isNotEmpty)
                                          Text(
                                            '/ $unit',
                                            style: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 10,
                                            ),
                                          ),
                                        if (isSelected)
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: AppTheme.gold,
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
                const Divider(color: Colors.white12),
                const SizedBox(height: 12),

                if (_needsSize) ...[
                  _pickerLabel('Size (in feet)'),
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
                          style: TextStyle(color: Colors.white54, fontSize: 18),
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
                  _pickerLabel('Material / Finish'),
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
                      style: TextStyle(color: Colors.white70, fontSize: 13),
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
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        onChanged: (v) {
                          final n = int.tryParse(v);
                          if (n != null && n > 0) setState(() => _qty = n);
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.1),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.white54),
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
                        color: AppTheme.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _notesCtrl,
                  onChanged: (v) => _notes = v,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  maxLines: 2,
                  decoration: AppTheme.inputDecoration(
                    'Product notes / specifications (optional)',
                  ),
                ),
              ],
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selected == null
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.gold,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.white.withValues(
                      alpha: 0.1,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _selected == null
                        ? 'Select a product first'
                        : 'Add to Order',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _selected == null ? Colors.white38 : Colors.black,
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
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: active
                ? AppTheme.gold.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active
                  ? AppTheme.gold.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.15),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? AppTheme.gold : Colors.white70,
              fontSize: 11,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );

  Widget _imgPlaceholder() => Container(
    color: Colors.white.withValues(alpha: 0.06),
    child: const Center(
      child: Icon(Icons.image_outlined, color: Colors.white24, size: 24),
    ),
  );

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Icon(icon, color: Colors.white70, size: 16),
    ),
  );

  Widget _pickerLabel(String text) => Text(
    text,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _selChip(String label, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? AppTheme.gold.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active
                  ? AppTheme.gold.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.15),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? AppTheme.gold : Colors.white70,
              fontSize: 12,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );

  Widget _dimField(
    String label,
    TextEditingController ctrl,
    ValueChanged<String> onChanged,
  ) => TextField(
    controller: ctrl,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    style: const TextStyle(color: Colors.white, fontSize: 13),
    decoration: AppTheme.inputDecoration('$label (ft)'),
    onChanged: onChanged,
  );
}

// ── Queue list (Pending / Active / Cancelled) ─────────────────────────────────

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
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.gold),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Queue error: ${snap.error}',
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
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
                Icon(icon, size: 52, color: Colors.white24),
                const SizedBox(height: 14),
                Text(
                  jobStatus == 'pending'
                      ? 'No pending jobs'
                      : jobStatus == 'cancelled'
                      ? 'No cancelled jobs'
                      : 'No active jobs',
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
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

// ── Ready for Pickup list ─────────────────────────────────────────────────────

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
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.gold),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'Error: ${snap.error}',
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
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
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 52,
                  color: Colors.white24,
                ),
                SizedBox(height: 14),
                Text(
                  'No orders ready for pickup',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
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
          backgroundColor: Colors.green.shade700,
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
      decoration: AppTheme.glassCard(opacity: 0.13, radius: 16),
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
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '$customer · $dateStr',
                        style: const TextStyle(
                          color: Colors.white54,
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
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Text(
                    'Ready',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                _Chip('Total', '₱${total.toStringAsFixed(2)}', Colors.white70),
                const SizedBox(width: 10),
                _Chip('Paid', '₱${paid.toStringAsFixed(2)}', Colors.green),
                const SizedBox(width: 10),
                _Chip(
                  fullyPaid ? 'Fully Paid' : 'Balance Due',
                  fullyPaid ? '—' : '₱${remaining.toStringAsFixed(2)}',
                  fullyPaid ? Colors.green : AppTheme.gold,
                  bold: true,
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                  fullyPaid ? Colors.green : AppTheme.gold,
                ),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Invoice button — always visible in Ready for Pickup
                OutlinedButton(
                  onPressed: () => _viewInvoice(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.gold,
                    side: BorderSide(
                      color: AppTheme.gold.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, size: 18),
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
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.orange,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Collect ₱${remaining.toStringAsFixed(2)} via POS before release',
                              style: const TextStyle(
                                color: Colors.orange,
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
                    child: ElevatedButton.icon(
                      onPressed: () => _markCompleted(context),
                      icon: const Icon(Icons.task_alt_rounded, size: 16),
                      label: const Text(
                        'Mark as Completed',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
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

class _Chip extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool bold;
  const _Chip(this.label, this.value, this.color, {this.bold = false});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 9,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: bold ? 13 : 11,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    ],
  );
}

// ── Queue card ────────────────────────────────────────────────────────────────

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
      return '${m[d.month - 1]} ${d.day}, ${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
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
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        title: const Text(
          'Cancel Order?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to cancel order $orderId? This cannot be undone.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'No, Keep It',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
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
      final threadRef = db.collection('Messages').doc('chat_$customerUid');
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
          backgroundColor: Colors.red.shade700,
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

    // Automatically deduct raw materials from inventory for each product
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
        ((data['products'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map)),
      );

      for (final p in products) {
        final productId = p['product_id']?.toString() ?? '';
        if (productId.isEmpty) continue;
        final qty = (p['qty'] as num?)?.toDouble() ?? 1.0;
        final widthFt = (p['width_ft'] as num?)?.toDouble();
        final heightFt = (p['height_ft'] as num?)?.toDouble();
        final selectedMaterial = p['material']?.toString();
        // For area-based products pass total sqft; for piece-based pass qty
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
          // Non-critical: log and continue — production must not be blocked
          debugPrint('Inventory deduction failed for $productId: $e');
        }
      }
    }

    if (customerUid != null && customerUid.isNotEmpty) {
      final threadRef = db.collection('Messages').doc('chat_$customerUid');
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
          backgroundColor: Colors.blue.shade700,
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
      final threadRef = db.collection('Messages').doc('chat_$customerUid');
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
          backgroundColor: Colors.green.shade700,
        ),
      );
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

    final statusColor = jobStatus == 'active'
        ? Colors.blueAccent
        : jobStatus == 'cancelled'
        ? Colors.redAccent
        : Colors.amber;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.glassCard(opacity: 0.13, radius: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.gold.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '#$position',
                      style: const TextStyle(
                        color: AppTheme.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
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
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        customerName,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.4),
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
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
            ],

            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 13,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 4),
                Text(
                  turnaround != null
                      ? 'Est. $turnaround day${turnaround == 1 ? '' : 's'}'
                      : 'Turnaround TBD',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.calendar_today,
                  size: 13,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    dateStr,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ),
                Text(
                  '₱${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppTheme.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Action buttons — hidden for cancelled
            if (jobStatus != 'cancelled')
              Row(
                children: [
                  if (jobStatus == 'pending')
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _startJob(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Start Job',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  if (jobStatus == 'active')
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _markReady(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Mark Ready',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Builder(
                    builder: (ctx) => OutlinedButton(
                      onPressed: () => _cancelOrder(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: BorderSide(
                          color: Colors.redAccent.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Icon(Icons.cancel_outlined, size: 18),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Builder(
                    builder: (ctx) => OutlinedButton(
                      onPressed: () async {
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
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.gold,
                        side: BorderSide(
                          color: AppTheme.gold.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, size: 18),
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
