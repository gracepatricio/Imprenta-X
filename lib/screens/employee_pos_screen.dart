import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'invoice_screen.dart';
import 'app_theme.dart';

// ── Design tokens (aligned with employee-side Liquid Glass system) ─────────────
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
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentOrange = Color(0xFFF97316);

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
  }) =>
      BoxDecoration(
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

// ── Reusable frosted-glass card ────────────────────────────────────────────────
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
// EmployeePosScreen
// =============================================================================

class EmployeePosScreen extends StatefulWidget {
  const EmployeePosScreen({super.key});

  @override
  State<EmployeePosScreen> createState() => _EmployeePosScreenState();
}

class _EmployeePosScreenState extends State<EmployeePosScreen> {
  final _searchCtrl = TextEditingController();
  final _db = FirebaseFirestore.instance;

  // All orders with remaining balance
  List<Map<String, dynamic>> _allOrders = [];
  List<Map<String, dynamic>> get _displayOrders {
    var orders = _allOrders;
    if (_statusFilter != 'all') {
      orders = orders
          .where((o) => o['status']?.toString() == _statusFilter)
          .toList();
    }
    if (_searchQuery.isEmpty) return orders;
    final q = _searchQuery.toLowerCase();
    return orders.where((o) {
      final orderId  = (o['order_id']?.toString() ?? '').toLowerCase();
      final custName = (o['customer_name']?.toString() ?? '').toLowerCase();
      final custId   = (o['customer_id']?.toString() ?? '').toLowerCase();
      return orderId.contains(q) || custName.contains(q) || custId.contains(q);
    }).toList();
  }

  Map<String, dynamic>? _selectedCustomer; // kept for payment refresh
  bool _loading = false;
  String _searchQuery = '';
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _loadOrdersWithBalance();
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Search ────────────────────────────────────────────────────────────────

  void _onSearchChanged() {
    final q = _searchCtrl.text.trim();
    if (q == _searchQuery) return;
    setState(() => _searchQuery = q);
  }

  Future<void> _loadOrdersWithBalance() async {
    setState(() => _loading = true);
    try {
      final snap = await _db
          .collection('Orders')
          .where('status', whereIn: ['pending', 'in_production', 'ready'])
          .where('payment_status', whereIn: ['unpaid', 'partial'])
          .get()
          .catchError((_) => null);
      final results = <Map<String, dynamic>>[];
      if (snap != null) {
        for (final doc in snap.docs) {
          final data      = doc.data();
          final total     = (data['total_price'] as num?)?.toDouble() ?? 0.0;
          final paid      = (data['amount_paid'] as num?)?.toDouble() ?? 0.0;
          final remaining = (data['remaining_balance'] as num?)?.toDouble() ?? (total - paid);
          if (remaining > 0.01) {
            results.add({
              'orderId': doc.id,
              ...data,
              'total_amount': total,
              'paid_amount':  paid,
              'remaining':    remaining,
            });
          }
        }
        results.sort((a, b) {
          final ta = a['created_at'] as Timestamp?;
          final tb = b['created_at'] as Timestamp?;
          if (ta == null && tb == null) return 0;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return tb.compareTo(ta);
        });
      }
      if (mounted) setState(() => _allOrders = results);
    } catch (e) {
      _showSnack('Could not load orders: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // These methods are no longer called (POS now shows orders directly).
  Future<void> _selectCustomer(Map<String, dynamic> customer) async {
    setState(() => _selectedCustomer = customer);
  }

  void _clearSelection() {
    setState(() => _selectedCustomer = null);
  }

  // ── Payment bottom-sheet ──────────────────────────────────────────────────

  void _openPaymentSheet(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentSheet(
        order: order,
        onPaymentRecorded: (orderId, newPaid, wasFullyPaid) async {
          final orderSnap = await _db.collection('Orders').doc(orderId).get();
          final orderData = orderSnap.data() ?? {};
          final total     = (orderData['total_price'] as num?)?.toDouble() ?? 0.0;
          final prevPaid  = (orderData['amount_paid'] as num?)?.toDouble() ?? 0.0;
          final remaining = (total - newPaid).clamp(0.0, double.infinity);
          final cashPaid  = newPaid - prevPaid;
          final custName  = orderData['customer_name']?.toString() ?? '';
          final custId    = orderData['customer_id']?.toString() ?? '';
          final walkIn    = orderData['walk_in'] == true;

          // ── 1. Update the Order document ──────────────────────────────
          await _db.collection('Orders').doc(orderId).update({
            'amount_paid':       newPaid,
            'remaining_balance': remaining,
            'payment_status':    wasFullyPaid ? 'paid' : 'partial',
          });

          // ── 2. Keep Invoice in sync ───────────────────────────────────
          final invId = orderData['invoice_id']?.toString();
          if (invId != null && invId.isNotEmpty) {
            await _db.collection('Invoices').doc(invId).update({
              'amount_paid':       newPaid,
              'remaining_balance': remaining,
            }).catchError((_) {});
          }

          // ── 3. Log to Payments collection ─────────────────────────────
          await _db.collection('Payments').add({
            'order_id':              orderId,
            'amount':                cashPaid,
            'payment_type':          wasFullyPaid ? 'full' : 'partial',
            'payment_method':        'cash',
            'transaction_reference': 'cash_onsite',
            'payment_date':          FieldValue.serverTimestamp(),
            'status':                'paid',
            'paid_by':               'employee',
          });

          // ── 4. Sales_Records ──────────────────────────────────────────
          // Always read order_id from the Orders document itself so
          // the value used for CREATE and FIND is guaranteed identical.
          final salesOrderId = orderData['order_id']?.toString() ?? orderId;

          // Step 1 — first payment (no prior payment exists):
          //   Create exactly ONE Sales_Record.
          //   payment_type: 'full' if the entire order is settled in one go,
          //                 'downpayment' if only a partial amount was paid.
          //
          // Step 2 — balance (prior payment already recorded):
          //   Query Sales_Records by order_id, find that one record,
          //   and update payment_type to 'balance'.
          //   NEVER create a second record.

          if (prevPaid == 0) {
            // ── First payment: full upfront or partial downpayment ────
            await _db.collection('Sales_Records').add({
              'order_id':       salesOrderId,
              'customer_name':  custName,
              'customer_id':    custId,
              'payment_type':   wasFullyPaid ? 'full' : 'downpayment',
              'payment_method': 'cash',
              'sale_amount':    cashPaid,
              'order_total':    total,
              'sale_date':      FieldValue.serverTimestamp(),
              if (walkIn) 'walk_in': true,
            });
          } else {
            // ── Balance: add a separate Sales_Record for the balance ──
            // The original downpayment record stays intact so dpTotal
            // in reports is not affected. sale_amount is cashPaid only
            // (the balance amount), never the cumulative newPaid total.
            await _db.collection('Sales_Records').add({
              'order_id':       salesOrderId,
              'customer_name':  custName,
              'customer_id':    custId,
              'payment_type':   'balance',
              'payment_method': 'cash',
              'sale_amount':    cashPaid,
              'order_total':    total,
              'sale_date':      FieldValue.serverTimestamp(),
              if (walkIn) 'walk_in': true,
            });
          }

          // ── 5. POS Activity Log ───────────────────────────────────────
          try {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              String employeeName = user.displayName ?? user.email ?? 'Employee';
              String employeeDisplayId = '';
              try {
                final userDoc = await _db.collection('User').doc(user.uid).get();
                if (userDoc.exists) {
                  employeeName = userDoc.data()?['full_name'] ?? employeeName;
                  employeeDisplayId = userDoc.data()?['employee_id']?.toString() ?? '';
                }
              } catch (_) {}
              await _db.collection('PosActivityLogs').add({
                'employee_uid':        user.uid,
                'employee_name':       employeeName,
                'employee_display_id': employeeDisplayId,
                'order_id':            salesOrderId,
                'customer_name':       custName,
                'customer_id':         custId,
                'amount_paid':         cashPaid,
                'total_order':         total,
                'payment_type':        wasFullyPaid
                    ? (prevPaid == 0 ? 'full' : 'balance')
                    : 'downpayment',
                'timestamp':           FieldValue.serverTimestamp(),
              });
            }
          } catch (e) {
            debugPrint('[POSLog] write failed: $e');
          }

          // ── 6. Refresh orders panel ───────────────────────────────────
          _loadOrdersWithBalance();
        },
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return _BlurCard(
        radius: 20,
        elevated: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header + controls ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Title row ──
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _navyBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.point_of_sale_rounded,
                            color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Point of Sale',
                              style: TextStyle(
                                color: _Glass.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 1),
                            Text(
                              'Collect payments for outstanding orders',
                              style: TextStyle(
                                color: _Glass.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_loading)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _navyBlue.withValues(alpha: 0.6)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, thickness: 0.5, color: _Glass.borderDim),
                  const SizedBox(height: 12),

                  // ── Search + filter row ──
                  Row(
                    children: [
                      Expanded(
                        child: _SearchBar(
                            controller: _searchCtrl, loading: _loading),
                      ),
                      const SizedBox(width: 8),
                      _StatusDropdown(
                        value: _statusFilter,
                        onChanged: (v) =>
                            setState(() => _statusFilter = v ?? 'all'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Order list ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: _OrderWithBalanceList(
                  orders: _displayOrders,
                  loading: _loading,
                  onRefresh: _loadOrdersWithBalance,
                  onSelectOrder: _openPaymentSheet,
                ),
              ),
            ),
          ],
        ),
    );
  }
}

// =============================================================================
// Search bar
// =============================================================================

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;

  const _SearchBar({required this.controller, required this.loading});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: _blurFilter,
        child: Container(
          decoration: _Glass.glass(radius: 14),
          child: TextField(
            controller: controller,
            style: const TextStyle(color: _Glass.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search by order ID, customer name or ID…',
              hintStyle:
                  const TextStyle(color: _Glass.textMuted, fontSize: 14),
              prefixIcon:
                  const Icon(Icons.search, color: _Glass.textMuted),
              suffixIcon: loading
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _navyBlue.withValues(alpha: 0.5))),
                    )
                  : controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close,
                              color: _Glass.textMuted, size: 18),
                          onPressed: () => controller.clear(),
                        )
                      : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Status filter dropdown
// =============================================================================

class _StatusDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;

  const _StatusDropdown({required this.value, required this.onChanged});

  static const _values = ['all', 'pending', 'in_production', 'ready'];
  static const _labels = ['All', 'Pending', 'In Production', 'Ready'];
  static const _icons = [
    Icons.list_rounded,
    Icons.hourglass_empty_rounded,
    Icons.precision_manufacturing_outlined,
    Icons.check_circle_outline_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: _blurFilter,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: _Glass.glass(radius: 14),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              onChanged: onChanged,
              isDense: true,
              dropdownColor: _Glass.surface,
              borderRadius: BorderRadius.circular(14),
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: _Glass.textMuted, size: 18),
              style: const TextStyle(
                  color: _Glass.textPrimary, fontSize: 13),
              items: List.generate(_values.length, (i) {
                return DropdownMenuItem<String>(
                  value: _values[i],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_icons[i], size: 14, color: _Glass.textMuted),
                      const SizedBox(width: 6),
                      Text(_labels[i],
                          style: const TextStyle(
                              color: _Glass.textPrimary, fontSize: 13)),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Customer search results (legacy — kept for completeness)
// =============================================================================

class _CustomerResultsList extends StatelessWidget {
  final List<Map<String, dynamic>> customers;
  final String query;
  final bool loading;
  final ValueChanged<Map<String, dynamic>> onSelect;

  const _CustomerResultsList({
    required this.customers,
    required this.query,
    required this.loading,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && customers.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: _navyBlue));
    }
    if (query.isEmpty && customers.isEmpty) {
      return _EmptyHint(
        icon: Icons.person_search_outlined,
        title: 'No customers found',
        subtitle: 'Could not load customer list',
      );
    }
    if (customers.isEmpty) {
      return _EmptyHint(
        icon: Icons.search_off_rounded,
        title: 'No customers found',
        subtitle: 'Try a different name or ID',
      );
    }

    return _BlurCard(
      radius: 18,
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: customers.length,
        separatorBuilder: (_, __) =>
            const Divider(color: _Glass.borderDim, height: 1),
        itemBuilder: (_, i) {
          final c     = customers[i];
          final name  = c['full_name'] ?? 'Unknown';
          final cid   = c['customer_id']?.toString() ?? '—';
          final email = c['email'] ?? '';
          return ListTile(
            onTap: () => onSelect(c),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: _navyBlue.withValues(alpha: 0.10),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: _navyBlue, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(name,
                style: const TextStyle(
                    color: _Glass.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            subtitle: Text(
                'ID: $cid${email.isNotEmpty ? '  •  $email' : ''}',
                style:
                    const TextStyle(color: _Glass.textMuted, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right,
                color: _Glass.textMuted),
          );
        },
      ),
    );
  }
}

// =============================================================================
// Customer orders view (legacy — kept for completeness)
// =============================================================================

class _CustomerOrdersView extends StatelessWidget {
  final Map<String, dynamic> customer;
  final List<Map<String, dynamic>> orders;
  final bool loading;
  final VoidCallback onBack;
  final ValueChanged<Map<String, dynamic>> onSelectOrder;

  const _CustomerOrdersView({
    required this.customer,
    required this.orders,
    required this.loading,
    required this.onBack,
    required this.onSelectOrder,
  });

  @override
  Widget build(BuildContext context) {
    final name = customer['full_name'] ?? 'Customer';
    final cid  = customer['customer_id']?.toString() ?? '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Customer card ──
        _BlurCard(
          radius: 14,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _navyBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: _navyBlue, size: 14),
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 22,
                backgroundColor: _navyBlue.withValues(alpha: 0.10),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: _navyBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            color: _Glass.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    const SizedBox(height: 2),
                    Text('Customer ID: $cid',
                        style: const TextStyle(
                            color: _Glass.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _navyBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${orders.length} unpaid order${orders.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                      color: _Glass.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Label ──
        const Text('Active Orders',
            style: TextStyle(
                color: _Glass.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8)),
        const SizedBox(height: 8),

        // ── Orders list ──
        Expanded(
          child: loading
              ? const Center(
                  child: CircularProgressIndicator(color: _navyBlue))
              : orders.isEmpty
                  ? _EmptyHint(
                      icon: Icons.check_circle_outline_rounded,
                      title: 'All settled up',
                      subtitle:
                          'This customer has no outstanding balance',
                    )
                  : ListView.builder(
                      itemCount: orders.length,
                      itemBuilder: (_, i) => _OrderCard(
                        order: orders[i],
                        onTap: () => onSelectOrder(orders[i]),
                      ),
                    ),
        ),
      ],
    );
  }
}

// =============================================================================
// Order card
// =============================================================================

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.onTap});

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':       return 'Pending';
      case 'in_production': return 'In Production';
      case 'ready':         return 'Ready';
      default:              return s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':       return Colors.amber;
      case 'in_production': return Colors.blueAccent;
      case 'ready':         return Colors.green;
      default:              return Colors.orange;
    }
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '—';
    try {
      final dt = (ts as Timestamp).toDate();
      return '${dt.month}/${dt.day}/${dt.year}';
    } catch (_) {
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final total     = (order['total_amount'] as double?) ?? 0.0;
    final paid      = (order['paid_amount']  as double?) ?? 0.0;
    final remaining = (order['remaining']    as double?) ?? (total - paid);
    final pct       = total > 0 ? (paid / total).clamp(0.0, 1.0) : 0.0;
    final rawId     = order['order_id']?.toString() ?? (order['orderId'] as String? ?? '—');
    final orderId   = rawId.length > 8 ? rawId.substring(0, 8) : rawId;
    final date      = _formatDate(order['date_created']);

    final needsDownpayment = paid < (total * 0.50);

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _BlurCard(
          radius: 16,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _navyBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('# $orderId',
                        style: const TextStyle(
                            color: _Glass.textSecondary,
                            fontSize: 11,
                            fontFamily: 'monospace')),
                  ),
                  const SizedBox(width: 8),
                  Text(date,
                      style: const TextStyle(
                          color: _Glass.textMuted, fontSize: 11)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: needsDownpayment
                          ? _Glass.accentRose.withValues(alpha: 0.12)
                          : remaining > 0
                              ? _Glass.accentAmber.withValues(alpha: 0.12)
                              : _Glass.accentEmerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: needsDownpayment
                            ? _Glass.accentRose.withValues(alpha: 0.35)
                            : remaining > 0
                                ? _Glass.accentAmber.withValues(alpha: 0.35)
                                : _Glass.accentEmerald.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      needsDownpayment
                          ? '↓ Downpayment Required'
                          : remaining > 0
                              ? 'Unpaid'
                              : 'Paid',
                      style: TextStyle(
                        color: needsDownpayment
                            ? _Glass.accentRose
                            : remaining > 0
                                ? _Glass.accentAmber
                                : _Glass.accentEmerald,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Amounts ──
              Row(
                children: [
                  _AmountChip(
                      label: 'Total',
                      value: total,
                      color: _Glass.textSecondary),
                  const SizedBox(width: 12),
                  _AmountChip(
                      label: 'Paid',
                      value: paid,
                      color: _Glass.accentEmerald),
                  const SizedBox(width: 12),
                  _AmountChip(
                      label: 'Remaining',
                      value: remaining,
                      color: _amber,
                      bold: true),
                ],
              ),
              const SizedBox(height: 12),

              // ── Progress bar ──
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: _Glass.borderDim,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      pct >= 1.0 ? _Glass.accentEmerald : _amber),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 8),

              // ── Tap hint + invoice ──
              Row(
                children: [
                  Builder(
                      builder: (ctx) => GestureDetector(
                            onTap: () async {
                              final rawId = order['order_id']?.toString() ??
                                  (order['orderId'] as String? ?? '');
                              final orderSnap =
                                  await FirebaseFirestore.instance
                                      .collection('Orders')
                                      .doc(rawId)
                                      .get();
                              final invId = orderSnap
                                  .data()?['invoice_id']
                                  ?.toString();
                              if (invId != null && ctx.mounted) {
                                Navigator.of(ctx).push(MaterialPageRoute(
                                  builder: (_) =>
                                      InvoiceScreen(invoiceId: invId),
                                ));
                              } else if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'No invoice for this order')),
                                );
                              }
                            },
                            child: Row(
                              children: const [
                                Icon(Icons.receipt_long_outlined,
                                    color: _Glass.textMuted, size: 14),
                                SizedBox(width: 4),
                                Text('Invoice',
                                    style: TextStyle(
                                        color: _Glass.textMuted,
                                        fontSize: 11)),
                              ],
                            ),
                          )),
                  const Spacer(),
                  Text('Tap to collect payment',
                      style: TextStyle(
                          color: _amber.withValues(alpha: 0.8),
                          fontSize: 11)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios_rounded,
                      color: _amber.withValues(alpha: 0.8), size: 10),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool bold;

  const _AmountChip({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: _Glass.textMuted, fontSize: 10)),
        const SizedBox(height: 2),
        Text('₱${AppTheme.fmtAmt(value)}',
            style: TextStyle(
                color: color,
                fontSize: bold ? 15 : 13,
                fontWeight:
                    bold ? FontWeight.w700 : FontWeight.w500)),
      ],
    );
  }
}

// =============================================================================
// Payment bottom-sheet
// =============================================================================

class _PaymentSheet extends StatefulWidget {
  final Map<String, dynamic> order;
  final Future<void> Function(String orderId, double newPaid, bool wasFullyPaid)
      onPaymentRecorded;

  const _PaymentSheet(
      {required this.order, required this.onPaymentRecorded});

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  final _ctrl = TextEditingController();
  bool _processing = false;
  double? _change;

  double get _remaining =>
      (widget.order['remaining']    as double?) ?? 0.0;
  double get _total =>
      (widget.order['total_amount'] as double?) ?? 0.0;
  double get _paid =>
      (widget.order['paid_amount']  as double?) ?? 0.0;
  String get _orderId => widget.order['orderId'] as String;

  void _setQuickAmount(double amt) {
    _ctrl.text = amt.toStringAsFixed(2);
    setState(() => _change = null);
  }

  bool get _requiresDownpayment => _paid == 0.0;

  Future<void> _confirm() async {
    final tendered = double.tryParse(_ctrl.text.trim());
    if (tendered == null || tendered <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid amount')));
      return;
    }

    if (_requiresDownpayment) {
      final minimumDown = _total * 0.50;
      if (tendered < minimumDown) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'A minimum downpayment of ₱${AppTheme.fmtAmt(minimumDown)} '
              '(50% of ₱${AppTheme.fmtAmt(_total)}) is required '
              'to process this order.',
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    if (tendered > _remaining + 0.009) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a valid amount. Maximum payable is ₱${AppTheme.fmtAmt(_remaining)}.'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final change = tendered - _remaining;
    final newPaid = _paid + (tendered < _remaining ? tendered : _remaining);
    final wasFullyPaid = newPaid >= _total;

    setState(() => _processing = true);
    try {
      await widget.onPaymentRecorded(_orderId, newPaid, wasFullyPaid);
      if (mounted) {
        setState(() {
          _change = change > 0 ? change : 0;
          _processing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const _fixedChips = [75.0, 100.0, 200.0, 500.0];

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: _blurFilter,
        child: Container(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: BoxDecoration(
            color: _Glass.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
                top: BorderSide(color: _Glass.borderMid, width: 0.9)),
            boxShadow: const [_Glass.elevatedShadow],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: _change != null
                  ? _SuccessView(
                      change: _change!,
                      onDone: () => Navigator.pop(context),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Handle ──
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: _Glass.textMuted
                                  .withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        const Text('Collect Payment',
                            style: TextStyle(
                                color: _Glass.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                          'Order #${_orderId.substring(0, 8)}',
                          style: const TextStyle(
                              color: _Glass.textMuted, fontSize: 12),
                        ),

                        if (_requiresDownpayment) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _Glass.accentAmber
                                  .withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: _Glass.accentAmber
                                      .withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded,
                                    color: _Glass.accentAmber, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Minimum 50% downpayment required '
                                    '(₱${AppTheme.fmtAmt(_total * 0.5)})',
                                    style: const TextStyle(
                                        color: _Glass.accentAmber,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // ── Balance summary ──
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: _Glass.glass(radius: 14),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              _BalanceRow('Total', _total),
                              _BalanceRow('Paid', _paid,
                                  color: _Glass.accentEmerald),
                              _BalanceRow('Remaining', _remaining,
                                  color: _amber, large: true),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Quick-amount chips ──
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            // Exact remaining chip
                            GestureDetector(
                              onTap: () => _setQuickAmount(_remaining),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 7),
                                decoration: _Glass.solidPill(_navyBlue),
                                child: Text(
                                  '₱${AppTheme.fmtAmt(_remaining)}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            // Fixed denomination chips — greyed when > remaining
                            ..._fixedChips.map((a) {
                              final disabled = a > _remaining + 0.009;
                              return GestureDetector(
                                onTap: disabled ? null : () => _setQuickAmount(a),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: disabled
                                        ? _Glass.borderDim
                                        : _Glass.surfaceThin,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: disabled
                                            ? _Glass.borderDim
                                            : _Glass.borderMid),
                                  ),
                                  child: Text(
                                    '₱${a.toStringAsFixed(0)}',
                                    style: TextStyle(
                                        color: disabled
                                            ? _Glass.textMuted
                                            : _Glass.textSecondary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // ── Amount field ──
                        Container(
                          decoration: _Glass.glass(radius: 14),
                          child: TextField(
                            controller: _ctrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            style: const TextStyle(
                                color: _Glass.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w700),
                            decoration: const InputDecoration(
                              prefixText: '₱  ',
                              prefixStyle: TextStyle(
                                  color: _Glass.textMuted, fontSize: 22),
                              hintText: '0.00',
                              hintStyle: TextStyle(
                                  color: _Glass.textMuted, fontSize: 22),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Confirm button ──
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _processing ? null : _confirm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _navyBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: _processing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white))
                                : const Text('Confirm Payment',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15)),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool large;

  const _BalanceRow(this.label, this.value,
      {this.color = _Glass.textSecondary, this.large = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                color: _Glass.textMuted, fontSize: 11)),
        const SizedBox(height: 4),
        Text('₱${AppTheme.fmtAmt(value)}',
            style: TextStyle(
                color: color,
                fontSize: large ? 18 : 14,
                fontWeight:
                    large ? FontWeight.w800 : FontWeight.w500)),
      ],
    );
  }
}

// ── Success view shown after payment recorded ─────────────────────────────

class _SuccessView extends StatelessWidget {
  final double change;
  final VoidCallback onDone;

  const _SuccessView({required this.change, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _Glass.accentEmerald.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded,
              color: _Glass.accentEmerald, size: 48),
        ),
        const SizedBox(height: 16),
        const Text('Payment Recorded',
            style: TextStyle(
                color: _Glass.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (change > 0) ...[
          const Text('Change',
              style: TextStyle(color: _Glass.textMuted, fontSize: 13)),
          const SizedBox(height: 4),
          Text('₱${AppTheme.fmtAmt(change)}',
              style: const TextStyle(
                  color: _amber,
                  fontSize: 36,
                  fontWeight: FontWeight.w800)),
        ] else
          const Text('No change due',
              style: TextStyle(color: _Glass.textMuted, fontSize: 14)),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onDone,
            style: ElevatedButton.styleFrom(
              backgroundColor: _navyBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text('Done', style: TextStyle(fontSize: 15)),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Orders with balance list
// =============================================================================

class _OrderWithBalanceList extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  final bool loading;
  final VoidCallback onRefresh;
  final ValueChanged<Map<String, dynamic>> onSelectOrder;

  const _OrderWithBalanceList({
    required this.orders,
    required this.loading,
    required this.onRefresh,
    required this.onSelectOrder,
  });

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':       return 'Pending';
      case 'in_production': return 'In Production';
      case 'ready':         return 'Ready';
      case 'cancelled':     return 'Cancelled';
      default:
        return s.isNotEmpty
            ? '${s[0].toUpperCase()}${s.substring(1)}'
            : s;
    }
  }

  String _fmtDate(dynamic ts) {
    if (ts == null) return '';
    try {
      final d = (ts as Timestamp).toDate().toLocal();
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${m[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading && orders.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: _navyBlue));
    }
    if (orders.isEmpty) {
      return _EmptyHint(
        icon: Icons.receipt_long_outlined,
        title: 'No outstanding balances',
        subtitle: 'All orders are fully paid',
      );
    }
    return ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: orders.length,
        separatorBuilder: (_, __) =>
            const Divider(color: _Glass.borderDim, height: 1),
        itemBuilder: (_, i) {
          final o         = orders[i];
          final orderId    = o['order_id']?.toString() ?? o['orderId']?.toString() ?? '—';
          final custName   = o['customer_name']?.toString() ?? 'Walk-in';
          final custId     = o['customer_id']?.toString() ?? '';
          final remaining  = (o['remaining'] as num?)?.toDouble() ?? 0.0;
          final total      = (o['total_amount'] as num?)?.toDouble() ?? 0.0;
          final dateStr    = _fmtDate(o['created_at']);
          final rawStatus  = o['status']?.toString() ?? 'pending';
          final statusStr  = _statusLabel(rawStatus);
          final isWalkIn = o['walk_in'] == true;

          return ListTile(
            onTap: () => onSelectOrder(o),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _navyBlue.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                    color: _navyBlue.withValues(alpha: 0.20)),
              ),
              child: Icon(Icons.receipt_outlined,
                  color: _navyBlue, size: 18),
            ),
            title: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  orderId,
                  style: const TextStyle(
                      color: _Glass.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
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
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _Glass.accentOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                        color: _Glass.accentOrange
                            .withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    '₱${AppTheme.fmtAmt(remaining)} due',
                    style: const TextStyle(
                        color: _Glass.accentOrange,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              '$custName${custId.isNotEmpty ? '  ·  ID: $custId' : ''}${dateStr.isNotEmpty ? '  •  $dateStr' : ''}  •  $statusStr',
              style:
                  const TextStyle(color: _Glass.textMuted, fontSize: 11),
            ),
            trailing: const Icon(Icons.chevron_right,
                color: _Glass.textMuted),
          );
        },
    );
  }
}

// =============================================================================
// Empty state helper
// =============================================================================

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyHint(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: _Glass.textMuted),
          const SizedBox(height: 14),
          Text(title,
              style: const TextStyle(
                  color: _Glass.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(
                  color: _Glass.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}
