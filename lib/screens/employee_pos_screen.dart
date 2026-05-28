import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'invoice_screen.dart';

class EmployeePosScreen extends StatefulWidget {
  const EmployeePosScreen({super.key});

  @override
  State<EmployeePosScreen> createState() => _EmployeePosScreenState();
}

class _EmployeePosScreenState extends State<EmployeePosScreen> {
  final _searchCtrl = TextEditingController();
  final _db = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _customers = [];
  Map<String, dynamic>? _selectedCustomer;
  List<Map<String, dynamic>> _activeOrders = [];

  bool _loadingCustomers = false;
  bool _loadingOrders = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _loadAllCustomers();
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
    _searchQuery = q;
    if (q.isEmpty) {
      setState(() {
        _selectedCustomer = null;
        _activeOrders = [];
      });
      _loadAllCustomers();
      return;
    }
    _searchCustomers(q);
  }

  Future<void> _loadAllCustomers() async {
    setState(() => _loadingCustomers = true);
    try {
      final snap = await _db
          .collection('User')
          .where('role', isEqualTo: 'customer')
          .limit(100)
          .get()
          .catchError((_) => null);
      final results = <Map<String, dynamic>>[];
      if (snap != null) {
        for (final doc in snap.docs) {
          results.add({'uid': doc.id, ...doc.data()});
        }
        results.sort((a, b) {
          final na = (a['full_name'] as String? ?? '').toLowerCase();
          final nb = (b['full_name'] as String? ?? '').toLowerCase();
          return na.compareTo(nb);
        });
      }
      if (mounted) setState(() => _customers = results);
    } catch (e) {
      _showSnack('Could not load customers: $e');
    } finally {
      if (mounted) setState(() => _loadingCustomers = false);
    }
  }

  Future<void> _searchCustomers(String query) async {
    setState(() => _loadingCustomers = true);
    try {
      final seen    = <String>{};
      final results = <Map<String, dynamic>>[];

      void addDoc(String id, Map<String, dynamic> data) {
        if (seen.contains(id)) return;
        seen.add(id);
        results.add({'uid': id, ...data});
      }

      void addSnap(QuerySnapshot? snap) {
        if (snap == null) return;
        for (final doc in snap.docs) {
          addDoc(doc.id, doc.data() as Map<String, dynamic>);
        }
      }

      final variants = <String>{
        query,
        query.toLowerCase(),
        query[0].toUpperCase() +
            (query.length > 1 ? query.substring(1).toLowerCase() : ''),
      };
      for (final v in variants) {
        addSnap(await _db
            .collection('User')
            .orderBy('full_name')
            .startAt([v])
            .endAt(['\$v\uf8ff'])
            .limit(15)
            .get()
            .catchError((_) => null));
      }

      addSnap(await _db
          .collection('User')
          .orderBy('customer_id')
          .startAt([query])
          .endAt(['\$query\uf8ff'])
          .limit(10)
          .get()
          .catchError((_) => null));

      if (results.isEmpty) {
        final all = await _db
            .collection('User')
            .limit(300)
            .get()
            .catchError((_) => null);
        if (all != null) {
          final q = query.toLowerCase();
          for (final doc in all.docs) {
            final data       = doc.data();
            final name       = (data['full_name']   as String? ?? '').toLowerCase();
            final customerId = (data['customer_id'] as String? ?? '').toLowerCase();
            final email      = (data['email']       as String? ?? '').toLowerCase();
            if (name.contains(q) || customerId.contains(q) || email.startsWith(q)) {
              addDoc(doc.id, data);
            }
          }
        }
      }

      if (mounted) setState(() => _customers = results);
    } catch (e) {
      _showSnack('Search failed: $e');
    } finally {
      if (mounted) setState(() => _loadingCustomers = false);
    }
  }

  // ── Select customer → load active orders ─────────────────────────────────

  Future<void> _selectCustomer(Map<String, dynamic> customer) async {
    setState(() {
      _selectedCustomer = customer;
      _activeOrders = [];
      _loadingOrders = true;
    });

    try {
      final uid = customer['uid'] as String;
      final snap = await _db
          .collection('Orders')
          .where('customer_uid', isEqualTo: uid)
          .where('status', whereIn: ['pending', 'in_production', 'ready'])
          .where('payment_status', whereIn: ['unpaid', 'partial'])
          .get()
          .catchError((_) => null);

      final orders = <Map<String, dynamic>>[];

      if (snap != null) {
        for (final d in snap.docs) {
          final data      = d.data();
          final total     = (data['total_price']   as num?)?.toDouble() ?? 0.0;
          final paid      = (data['amount_paid']   as num?)?.toDouble() ?? 0.0;
          final remaining = (data['remaining_balance'] as num?)?.toDouble() ?? (total - paid);
          orders.add({
            'orderId':     d.id,
            ...data,
            'total_amount': total,
            'paid_amount':  paid,
            'remaining':    remaining,
          });
        }
      }

      orders.sort((a, b) {
        final ta = a['created_at'];
        final tb = b['created_at'];
        if (ta == null || tb == null) return 0;
        return (tb as Timestamp).compareTo(ta as Timestamp);
      });

      if (mounted) setState(() => _activeOrders = orders);
    } catch (e) {
      _showSnack('Could not load orders: $e');
    } finally {
      if (mounted) setState(() => _loadingOrders = false);
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedCustomer = null;
      _activeOrders = [];
    });
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

          // Step 1 — downpayment (no prior payment exists):
          //   Create exactly ONE record containing only order_id.
          //   payment_type is set to 'downpayment'.
          //
          // Step 2 — balance (prior payment already recorded):
          //   Query Sales_Records by order_id, find that one record,
          //   and update payment_type from 'downpayment' to 'balance'.
          //   NEVER create a second record.

          if (prevPaid == 0) {
            // ── Downpayment: create the single Sales_Record ───────────
            await _db.collection('Sales_Records').add({
              'order_id':     salesOrderId,
              'payment_type': 'downpayment',
              'sale_date':    FieldValue.serverTimestamp(),
            });
          } else {
            // ── Balance: find the record by order_id and update it ────
            final snap = await _db
                .collection('Sales_Records')
                .where('order_id', isEqualTo: salesOrderId)
                .limit(1)
                .get();

            if (snap.docs.isNotEmpty) {
              await _db
                  .collection('Sales_Records')
                  .doc(snap.docs.first.id)
                  .update({
                'payment_type': 'balance',
                'balance_date': FieldValue.serverTimestamp(),
              });
            }
            // If somehow no record exists yet, do nothing —
            // do NOT create a new record on a balance payment.
          }

          // ── 5. Refresh orders panel ───────────────────────────────────
          if (_selectedCustomer != null) {
            _selectCustomer(_selectedCustomer!);
          }
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                      color: AppTheme.gold.withValues(alpha: 0.40), width: 1),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.point_of_sale_rounded,
                        color: AppTheme.gold, size: 16),
                    SizedBox(width: 6),
                    Text('Point of Sale',
                        style: TextStyle(
                            color: AppTheme.gold,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Search bar ──
          _SearchBar(controller: _searchCtrl, loading: _loadingCustomers),
          const SizedBox(height: 12),

          Expanded(
            child: _selectedCustomer == null
                ? _CustomerResultsList(
              customers: _customers,
              query: _searchQuery,
              loading: _loadingCustomers,
              onSelect: _selectCustomer,
            )
                : _CustomerOrdersView(
              customer: _selectedCustomer!,
              orders: _activeOrders,
              loading: _loadingOrders,
              onBack: _clearSelection,
              onSelectOrder: _openPaymentSheet,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Search bar
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;

  const _SearchBar({required this.controller, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search by customer name or ID…',
          hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
          prefixIcon:
          Icon(Icons.search, color: Colors.white.withValues(alpha: 0.5)),
          suffixIcon: loading
              ? Padding(
            padding: const EdgeInsets.all(14),
            child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.gold.withValues(alpha: 0.7))),
          )
              : controller.text.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.close,
                color: Colors.white.withValues(alpha: 0.5), size: 18),
            onPressed: () => controller.clear(),
          )
              : null,
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Customer search results
// ─────────────────────────────────────────────────────────────────────────────

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
      return const Center(child: CircularProgressIndicator());
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

    return Container(
      decoration: AppTheme.glassCard(opacity: 0.13, radius: 18),
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: customers.length,
        separatorBuilder: (_, __) =>
            Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),
        itemBuilder: (_, i) {
          final c        = customers[i];
          final name     = c['full_name'] ?? 'Unknown';
          final cid      = c['customer_id']?.toString() ?? '—';
          final email    = c['email'] ?? '';
          return ListTile(
            onTap: () => onSelect(c),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: AppTheme.gold.withValues(alpha: 0.18),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: AppTheme.gold, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(name,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            subtitle: Text('ID: $cid${email.isNotEmpty ? '  •  $email' : ''}',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
            trailing: Icon(Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.3)),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Customer orders view
// ─────────────────────────────────────────────────────────────────────────────

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
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.gold.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppTheme.gold.withValues(alpha: 0.25), width: 1),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white70, size: 14),
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.gold.withValues(alpha: 0.2),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: AppTheme.gold,
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
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    const SizedBox(height: 2),
                    Text('Customer ID: $cid',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${orders.length} unpaid order${orders.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Label ──
        Text('Active Orders',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8)),
        const SizedBox(height: 8),

        // ── Orders list ──
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
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

// ─────────────────────────────────────────────────────────────────────────────
//  Order card
// ─────────────────────────────────────────────────────────────────────────────

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
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.glassCard(opacity: 0.13, radius: 16),
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
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('# $orderId',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontFamily: 'monospace')),
                ),
                const SizedBox(width: 8),
                Text(date,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: needsDownpayment
                        ? Colors.red.withValues(alpha: 0.18)
                        : remaining > 0
                        ? Colors.orange.withValues(alpha: 0.18)
                        : Colors.green.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    needsDownpayment
                        ? '↓ Downpayment Required'
                        : remaining > 0
                        ? 'Unpaid'
                        : 'Paid',
                    style: TextStyle(
                      color: needsDownpayment
                          ? Colors.red.shade300
                          : remaining > 0
                          ? Colors.orange
                          : Colors.green,
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
                    label: 'Total', value: total, color: Colors.white70),
                const SizedBox(width: 12),
                _AmountChip(
                    label: 'Paid',
                    value: paid,
                    color: Colors.green.shade300),
                const SizedBox(width: 12),
                _AmountChip(
                    label: 'Remaining',
                    value: remaining,
                    color: AppTheme.gold,
                    bold: true),
              ],
            ),
            const SizedBox(height: 12),

            // ── Progress bar ──
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                    pct >= 1.0 ? Colors.green : AppTheme.gold),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 8),

            // ── Tap hint + invoice ──
            Row(
              children: [
                Builder(builder: (ctx) => GestureDetector(
                  onTap: () async {
                    final rawId = order['order_id']?.toString()
                        ?? (order['orderId'] as String? ?? '');
                    final orderSnap = await FirebaseFirestore.instance
                        .collection('Orders').doc(rawId).get();
                    final invId = orderSnap.data()?['invoice_id']?.toString();
                    if (invId != null && ctx.mounted) {
                      Navigator.of(ctx).push(MaterialPageRoute(
                        builder: (_) => InvoiceScreen(invoiceId: invId),
                      ));
                    } else if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('No invoice for this order')),
                      );
                    }
                  },
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          color: Colors.white.withValues(alpha: 0.4), size: 14),
                      const SizedBox(width: 4),
                      Text('Invoice',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11)),
                    ],
                  ),
                )),
                const Spacer(),
                Text('Tap to collect payment',
                    style: TextStyle(color: AppTheme.gold.withValues(alpha: 0.7), fontSize: 11)),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios_rounded,
                    color: AppTheme.gold.withValues(alpha: 0.7), size: 10),
              ],
            ),
          ],
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
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
        const SizedBox(height: 2),
        Text('₱${value.toStringAsFixed(2)}',
            style: TextStyle(
                color: color,
                fontSize: bold ? 15 : 13,
                fontWeight:
                bold ? FontWeight.w700 : FontWeight.w500)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Payment bottom-sheet
// ─────────────────────────────────────────────────────────────────────────────

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
              'A minimum downpayment of ₱${minimumDown.toStringAsFixed(2)} '
                  '(50% of ₱${_total.toStringAsFixed(2)}) is required '
                  'to process this order.',
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
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
    final quickAmounts = [
      _remaining,
      ...[100.0, 200.0, 500.0, 1000.0]
          .where((a) => a > _remaining)
          .take(3),
    ];

    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF16162A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text('Collect Payment',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Order #${_orderId.substring(0, 8)}',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12),
              ),

              if (_requiresDownpayment) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Minimum 50% downpayment required '
                              '(₱${(_total * 0.5).toStringAsFixed(2)})',
                          style: const TextStyle(
                              color: Colors.orange,
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
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppTheme.gold.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _BalanceRow('Total', _total),
                    _BalanceRow('Paid', _paid,
                        color: Colors.green.shade300),
                    _BalanceRow('Remaining', _remaining,
                        color: AppTheme.gold, large: true),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Quick-amount chips ──
              Wrap(
                spacing: 8,
                children: quickAmounts
                    .map((a) => GestureDetector(
                  onTap: () => _setQuickAmount(a),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white
                              .withValues(alpha: 0.15)),
                    ),
                    child: Text(
                      '₱${a.toStringAsFixed(a == _remaining ? 2 : 0)}',
                      style: TextStyle(
                          color: a == _remaining
                              ? AppTheme.gold
                              : Colors.white70,
                          fontSize: 13,
                          fontWeight: a == _remaining
                              ? FontWeight.w700
                              : FontWeight.w400),
                    ),
                  ),
                ))
                    .toList(),
              ),
              const SizedBox(height: 14),

              // ── Amount field ──
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: TextField(
                  controller: _ctrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    prefixText: '₱  ',
                    prefixStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 22),
                    hintText: '0.00',
                    hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 22),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
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
                    backgroundColor: AppTheme.gold,
                    foregroundColor: Colors.black,
                    padding:
                    const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _processing
                      ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black))
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
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool large;

  const _BalanceRow(this.label, this.value,
      {this.color = Colors.white70, this.large = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45), fontSize: 11)),
        const SizedBox(height: 4),
        Text('₱${value.toStringAsFixed(2)}',
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
            color: Colors.green.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded,
              color: Colors.green, size: 48),
        ),
        const SizedBox(height: 16),
        const Text('Payment Recorded',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (change > 0) ...[
          Text('Change',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
          const SizedBox(height: 4),
          Text('₱${change.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: AppTheme.gold,
                  fontSize: 36,
                  fontWeight: FontWeight.w800)),
        ] else
          Text('No change due',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onDone,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.12),
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

// ─────────────────────────────────────────────────────────────────────────────
//  Empty state helper
// ─────────────────────────────────────────────────────────────────────────────

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
          Icon(icon, size: 52, color: Colors.white24),
          const SizedBox(height: 14),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }
}