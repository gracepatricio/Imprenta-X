import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/paymongo_service.dart';
import 'app_theme.dart';
import 'payment_webview_screen.dart';
import 'invoice_screen.dart';

class CustomerOrdersScreen extends StatefulWidget {
  final int initialTabIndex;
  const CustomerOrdersScreen({super.key, this.initialTabIndex = 0});

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _statuses = [
    null,
    'awaiting_payment',
    'pending',
    'in_production',
    'ready',
    'cancelled',
    'completed',
  ];

  static const _tabLabels = [
    'All',
    'Awaiting Payment',
    'Pending',
    'In Production',
    'Ready',
    'Cancelled',
    'Completed',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length:       _statuses.length,
      vsync:        this,
      initialIndex: widget.initialTabIndex.clamp(0, _statuses.length - 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    // When pushed as a standalone route (e.g. from dashboard tap), wrap in Scaffold
    final isRoute = ModalRoute.of(context)?.settings.name != null ||
        Navigator.of(context).canPop();

    final body = SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('My Orders',
                    style: TextStyle(
                        color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                SizedBox(height: 2),
                Text('Track and manage your orders',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppTheme.gold,
            unselectedLabelColor: Colors.white38,
            indicatorColor: AppTheme.gold,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 2.5,
            dividerColor: Colors.white12,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            labelStyle: const TextStyle(
                fontFamily: 'Spartan', fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle:
                const TextStyle(fontFamily: 'Spartan', fontSize: 13),
            tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _statuses
                  .map((s) => _OrderList(uid: uid, status: s))
                  .toList(),
            ),
          ),
        ],
      ),
    );

    // If used as a pushed route (from dashboard), wrap in Scaffold
    if (Navigator.of(context).canPop()) {
      return Scaffold(
        backgroundColor: const Color(0xFF0f0f23),
        body: Container(
          decoration: AppTheme.backgroundDecoration,
          child: body,
        ),
      );
    }
    return body;
  }
}

// ── Order list ────────────────────────────────────────────────────────────────

class _OrderList extends StatelessWidget {
  final String? uid;
  final String? status;

  const _OrderList({required this.uid, required this.status});

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Center(
          child: Text('Not logged in', style: TextStyle(color: Colors.white54)));
    }

    Query query = FirebaseFirestore.instance
        .collection('Orders')
        .where('customer_uid', isEqualTo: uid)
        .orderBy('created_at', descending: true);

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _EmptyOrders(status: status);
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, i) {
            final doc = snapshot.data!.docs[i];
            return _OrderCard(docId: doc.id, order: doc.data() as Map<String, dynamic>);
          },
        );
      },
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyOrders extends StatelessWidget {
  final String? status;
  const _EmptyOrders({required this.status});

  String get _label {
    switch (status) {
      case 'awaiting_payment': return 'awaiting payment';
      case 'pending':          return 'pending';
      case 'in_production':    return 'in production';
      case 'ready':            return 'ready for pickup';
      case 'cancelled':        return 'cancelled';
      case 'completed':        return 'completed';
      default:                 return '';
    }
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long_outlined, size: 60, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            status == null ? 'No orders yet' : 'No $_label orders',
            style: const TextStyle(color: Colors.white38, fontSize: 15),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text('Orders you place will appear here',
              style: TextStyle(color: Colors.white24, fontSize: 12),
              textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

// ── Order card ────────────────────────────────────────────────────────────────

class _OrderCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> order;

  const _OrderCard({required this.docId, required this.order});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _payingNow = false;

  String get _status => widget.order['status']?.toString() ?? 'pending';
  double get _total  => (widget.order['total_price'] as num?)?.toDouble() ?? 0;
  double get _paid   => (widget.order['amount_paid'] as num?)?.toDouble() ?? 0;
  double get _remaining => (widget.order['remaining_balance'] as num?)?.toDouble()
      ?? (_total - _paid);

  Color _statusColor(String s) {
    switch (s) {
      case 'awaiting_payment': return Colors.orangeAccent;
      case 'pending':          return Colors.amber;
      case 'in_production':    return Colors.blueAccent;
      case 'ready':            return Colors.green;
      case 'cancelled':        return Colors.redAccent;
      case 'completed':        return AppTheme.accent;
      default:                 return Colors.white54;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'awaiting_payment': return Icons.payment_outlined;
      case 'pending':          return Icons.hourglass_empty;
      case 'in_production':    return Icons.precision_manufacturing_outlined;
      case 'ready':            return Icons.check_circle_outline;
      case 'cancelled':        return Icons.cancel_outlined;
      case 'completed':        return Icons.task_alt;
      default:                 return Icons.receipt_long_outlined;
    }
  }

  // Shows amount selector sheet, creates a fresh PayMongo link, opens WebView.
  // isInitial = true → for awaiting_payment orders (min 50% of total)
  // isInitial = false → for remaining balance on confirmed orders (min ₱1)
  Future<void> _payNow({bool isInitial = true}) async {
    final orderId = widget.order['order_id']?.toString() ?? widget.docId;
    final maxAmt  = isInitial ? _total : _remaining;
    final minAmt  = isInitial ? (_total * 0.5 * 100).round() / 100 : 1.0;

    if (maxAmt <= 0) return;

    // Show amount selector
    final chosen = await _showPayAmountSheet(
      context,
      total:    _total,
      minAmt:   minAmt,
      maxAmt:   maxAmt,
      isInitial: isInitial,
    );
    if (chosen == null || !mounted) return;

    setState(() => _payingNow = true);
    try {
      // For balance payments, reuse existing unpaid link if available
      String? reuseUrl;
      String? reuseLinkId;
      double? reuseLinkAmount;

      if (!isInitial) {
        final existingUrl    = widget.order['balance_checkout_url'] as String?;
        final existingLinkId = widget.order['balance_link_id']      as String?;
        final existingAmt    = (widget.order['balance_link_amount'] as num?)?.toDouble();

        if (existingUrl != null && existingLinkId != null) {
          try {
            final status = await PayMongoService.getLinkStatus(existingLinkId);
            if (status == 'unpaid') {
              reuseUrl       = existingUrl;
              reuseLinkId    = existingLinkId;
              reuseLinkAmount = existingAmt ?? chosen;
            }
          } catch (_) {}
        }
      }

      final checkoutUrl;
      final linkId;
      final payAmt;

      if (reuseUrl != null) {
        checkoutUrl = reuseUrl;
        linkId      = reuseLinkId!;
        payAmt      = reuseUrl == null ? chosen : (reuseLinkAmount ?? chosen);
      } else {
        final link = await PayMongoService.createLink(
          amount:      chosen,
          description: isInitial
              ? 'Downpayment $orderId (Imprenta X)'
              : 'Balance Payment $orderId (Imprenta X)',
        );

        // Log link → order mapping so webhook can find the order
        await FirebaseFirestore.instance.collection('PayMongoLinks').doc(link.id).set({
          'order_id':        orderId,
          'purpose':         isInitial ? 'downpayment' : 'balance',
          'expected_amount': chosen,
          'processed':       false,
          'created_at':      FieldValue.serverTimestamp(),
        });

        // For balance payments: persist link on order so the QR is always accessible
        if (!isInitial) {
          await FirebaseFirestore.instance.collection('Orders').doc(orderId).update({
            'balance_link_id':      link.id,
            'balance_checkout_url': link.checkoutUrl,
            'balance_link_amount':  chosen,
          });
        }

        checkoutUrl = link.checkoutUrl;
        linkId      = link.id;
        payAmt      = chosen;
      }

      if (!mounted) return;

      final paid = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PaymentWebViewScreen(
            checkoutUrl: checkoutUrl,
            linkId:      linkId,
            orderId:     orderId,
            payAmount:   payAmt,
          ),
        ),
      );

      if (paid == true && mounted) {
        if (isInitial) {
          await _confirmInitialPayment(linkId: linkId, paidAmount: payAmt);
        } else {
          await _recordBalancePayment(linkId: linkId, paidAmount: payAmt);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade700));
      }
    } finally {
      if (mounted) setState(() => _payingNow = false);
    }
  }

  // Reusable amount-picker sheet — returns null if dismissed
  static Future<double?> _showPayAmountSheet(BuildContext context, {
    required double total,
    required double minAmt,
    required double maxAmt,
    required bool   isInitial,
  }) {
    final ctrl = TextEditingController(text: maxAmt.toStringAsFixed(2));
    return showModalBottomSheet<double>(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          double chosen = (double.tryParse(ctrl.text) ?? maxAmt).clamp(minAmt, maxAmt);

          void setAmt(double v) {
            final c = v.clamp(minAmt, maxAmt);
            setSheet(() { ctrl.text = c.toStringAsFixed(2); });
          }


          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                left: 20, right: 20, top: 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                          color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isInitial ? 'Confirm Order & Pay' : 'Pay Remaining Balance',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  // Minimum info banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppTheme.gold, size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isInitial
                                ? 'Minimum: ₱${minAmt.toStringAsFixed(2)} (50% downpayment)'
                                : 'Outstanding balance: ₱${maxAmt.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: AppTheme.gold, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Amount input
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 14),
                          child: Text('₱',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6), fontSize: 20)),
                        ),
                        Expanded(
                          child: TextField(
                            controller: ctrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: '0.00',
                              hintStyle: TextStyle(color: Colors.white24, fontSize: 20),
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                            ),
                            onChanged: (_) => setSheet(() {}),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // QR note
                  Row(
                    children: [
                      const Icon(Icons.qr_code_2_rounded, color: Colors.white38, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'PayMongo checkout includes GCash & Maya QR codes',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: chosen < minAmt - 0.009
                          ? null
                          : () => Navigator.pop(ctx, chosen),
                      icon: const Icon(Icons.payment_rounded),
                      label: Text(
                        'Pay ₱${chosen.toStringAsFixed(2)} via PayMongo',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmInitialPayment({
    required String linkId,
    required double paidAmount,
  }) async {
    final orderId       = widget.order['order_id']?.toString() ?? widget.docId;
    final total         = _total;
    final remaining     = (total - paidAmount).clamp(0.0, double.infinity);
    final isFullyPaid   = remaining < 0.01;
    final customerName  = widget.order['customer_name']?.toString() ?? '';
    final customerEmail = widget.order['customer_email']?.toString() ?? '';
    final products      = (widget.order['products'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final turnaroundDays = (widget.order['turnaround_days'] as int?) ?? 3;

    // Generate invoice ID
    final invoiceRef = FirebaseFirestore.instance.collection('Counters').doc('invoice');
    final invoiceId  = await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(invoiceRef);
      final next = ((snap.data()?['last_id'] as int?) ?? 0) + 1;
      tx.set(invoiceRef, {'last_id': next});
      return 'INV-${next.toString().padLeft(4, '0')}';
    });

    final batch = FirebaseFirestore.instance.batch();

    batch.update(FirebaseFirestore.instance.collection('Orders').doc(orderId), {
      'status':            'pending',
      'amount_paid':       paidAmount,
      'remaining_balance': remaining,
      'payment_status':    isFullyPaid ? 'paid' : 'partial',
      'invoice_id':        invoiceId,
      'paid_at':           FieldValue.serverTimestamp(),
    });

    batch.set(FirebaseFirestore.instance.collection('Invoices').doc(invoiceId), {
      'invoice_id':        invoiceId,
      'order_id':          orderId,
      'customer_name':     customerName,
      'customer_email':    customerEmail,
      'issued_date':       FieldValue.serverTimestamp(),
      'items':             products,
      'total_amount':      total,
      'amount_paid':       paidAmount,
      'remaining_balance': remaining,
      'payment_method':    'online',
      'transaction_ref':   linkId,
    });

    final queueRef = FirebaseFirestore.instance.collection('Order_Queue').doc();
    batch.set(queueRef, {
      'order_id':          orderId,
      'customer_uid':      FirebaseAuth.instance.currentUser?.uid ?? '',
      'customer_name':     customerName,
      'job_status':        'pending',
      'turnaround_days':   turnaroundDays,
      'products':          products,
      'total_price':       total,
      'created_at':        FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // Sales record for this downpayment
    await FirebaseFirestore.instance.collection('Sales_Records').add({
      'order_id':             orderId,
      'customer_name':        customerName,
      'payment_type':         isFullyPaid ? 'full' : 'downpayment',
      'payment_method':       'online',
      'transaction_reference': linkId,
      'sale_amount':          paidAmount,
      'order_total':          total,
      'sale_date':            FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Payment confirmed! $orderId is now in the queue.'),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 3),
      ));
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => InvoiceScreen(invoiceId: invoiceId)),
      );
    }
  }

  Future<void> _recordBalancePayment({
    required String linkId,
    required double paidAmount,
  }) async {
    final orderId    = widget.order['order_id']?.toString() ?? widget.docId;
    final newPaid    = _paid + paidAmount;
    final newRemain  = (_total - newPaid).clamp(0.0, double.infinity);
    final isFullyPaid = newRemain < 0.01;

    final batch = FirebaseFirestore.instance.batch();

    batch.update(FirebaseFirestore.instance.collection('Orders').doc(orderId), {
      'amount_paid':         newPaid,
      'remaining_balance':   newRemain,
      'payment_status':      isFullyPaid ? 'paid' : 'partial',
      if (isFullyPaid) 'fully_paid_at': FieldValue.serverTimestamp(),
      // Clear the persisted balance link — it's been used
      'balance_link_id':      FieldValue.delete(),
      'balance_checkout_url': FieldValue.delete(),
      'balance_link_amount':  FieldValue.delete(),
    });

    // Update invoice if exists
    final invoiceId = widget.order['invoice_id']?.toString();
    if (invoiceId != null) {
      batch.update(
        FirebaseFirestore.instance.collection('Invoices').doc(invoiceId),
        {
          'amount_paid':       newPaid,
          'remaining_balance': newRemain,
        },
      );
    }

    // Log payment
    batch.set(FirebaseFirestore.instance.collection('Payments').doc(), {
      'order_id':            orderId,
      'amount':              paidAmount,
      'payment_type':        'balance',
      'payment_method':      'online',
      'transaction_reference': linkId,
      'payment_date':        FieldValue.serverTimestamp(),
      'status':              'paid',
    });

    await batch.commit();

    // Sales record for this balance payment
    await FirebaseFirestore.instance.collection('Sales_Records').add({
      'order_id':             orderId,
      'customer_name':        widget.order['customer_name']?.toString() ?? '',
      'payment_type':         'balance',
      'payment_method':       'online',
      'transaction_reference': linkId,
      'sale_amount':          paidAmount,
      'order_total':          _total,
      'sale_date':            FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isFullyPaid
            ? '₱${paidAmount.toStringAsFixed(2)} paid — order is now fully settled!'
            : '₱${paidAmount.toStringAsFixed(2)} paid. Remaining: ₱${newRemain.toStringAsFixed(2)}'),
        backgroundColor: isFullyPaid ? Colors.green.shade700 : Colors.blue.shade700,
        duration: const Duration(seconds: 4),
      ));
    }
  }

  void _showDetail() {
    final showPayBtn = _status == 'awaiting_payment' ||
        (_remaining > 0.009 && ['pending', 'in_production', 'ready'].contains(_status));
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => _OrderDetailSheet(
        docId:    widget.docId,
        order:    widget.order,
        onPayNow: showPayBtn
            ? () => _payNow(isInitial: _status == 'awaiting_payment')
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(_status);

    return GestureDetector(
      onTap: _showDetail,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.glassCard(opacity: 0.15, radius: 16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_statusIcon(_status), color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.order['order_id']?.toString() ?? widget.docId,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(
                        (() {
                          final prods = widget.order['products'];
                          if (prods is List && prods.isNotEmpty) {
                            return prods
                                .map((p) => (p as Map)['name']?.toString() ?? '')
                                .where((n) => n.isNotEmpty)
                                .join(', ');
                          }
                          return 'Order';
                        })(),
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: _status),
              ],
            ),

            // Balance bar (shown when order has been confirmed)
            if (_status != 'awaiting_payment' && _total > 0) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Paid ₱${_paid.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.green, fontSize: 10)),
                            Text(
                              _remaining > 0
                                  ? 'Due ₱${_remaining.toStringAsFixed(2)}'
                                  : 'Fully Paid',
                              style: TextStyle(
                                  color: _remaining > 0 ? AppTheme.gold : Colors.green,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: _total > 0 ? (_paid / _total).clamp(0, 1) : 0,
                            backgroundColor: Colors.white.withValues(alpha: 0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(
                                _remaining <= 0 ? Colors.green : AppTheme.gold),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            // Pay Now / Pay Remaining button
            if (_status == 'awaiting_payment' ||
                (_remaining > 0.009 &&
                    ['pending', 'in_production', 'ready'].contains(_status))) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _payingNow
                      ? null
                      : () => _payNow(isInitial: _status == 'awaiting_payment'),
                  icon: _payingNow
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.payment_rounded, size: 16),
                  label: Text(
                    _payingNow
                        ? 'Loading…'
                        : _status == 'awaiting_payment'
                            ? 'Pay via PayMongo (min 50%)'
                            : 'Pay Remaining ₱${_remaining.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Order detail bottom sheet ─────────────────────────────────────────────────

class _OrderDetailSheet extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> order;
  final VoidCallback? onPayNow;

  const _OrderDetailSheet({required this.docId, required this.order, this.onPayNow});

  String _fmtDate(dynamic ts) {
    if (ts == null) return '—';
    try {
      final d = (ts as dynamic).toDate() as DateTime;
      return '${d.month}/${d.day}/${d.year}';
    } catch (_) { return '—'; }
  }

  @override
  Widget build(BuildContext context) {
    final products  = (order['products'] as List?) ?? [];
    final status    = order['status']?.toString() ?? 'pending';
    final total     = (order['total_price']       as num?)?.toDouble() ?? 0;
    final paid      = (order['amount_paid']       as num?)?.toDouble() ?? 0;
    final remaining = (order['remaining_balance'] as num?)?.toDouble() ?? (total - paid);
    final turnaround = order['turnaround_days'] as int?;
    final invoiceId  = order['invoice_id']?.toString();
    final dateStr    = _fmtDate(order['created_at']);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (_, ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  order['order_id']?.toString() ?? docId,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              _StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 4),
          Text('Placed $dateStr', style: const TextStyle(color: Colors.white38, fontSize: 12)),
          if (turnaround != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.gold.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, color: AppTheme.gold, size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estimated Turnaround: ~$turnaround business day${turnaround == 1 ? '' : 's'}',
                          style: const TextStyle(color: AppTheme.gold, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        if (order['estimated_completion'] != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Target completion: ${_fmtDate(order['estimated_completion'])}',
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          const Text('Items',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...products.map((p) {
            final name     = p['name']?.toString() ?? 'Item';
            final qty      = p['qty']?.toString() ?? '1';
            final price    = (p['price'] as num?)?.toStringAsFixed(2) ?? '—';
            final size     = p['size_label']?.toString();
            final mat      = p['material']?.toString();
            final notes    = p['notes']?.toString() ?? '';
            final fileCount = (p['file_urls'] as List?)?.length ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13))),
                      Text('₱$price',
                          style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(['Qty: $qty', if (size != null) size, if (mat != null) mat].join(' · '),
                      style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Note: $notes', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                  if (fileCount > 0) ...[
                    const SizedBox(height: 4),
                    Text('$fileCount file${fileCount != 1 ? 's' : ''} attached',
                        style: const TextStyle(color: Color(0xFFFFD700), fontSize: 11)),
                  ],
                ],
              ),
            );
          }),

          const Divider(color: Colors.white12, height: 24),

          // Balance summary
          Row(children: [
            const Expanded(child: Text('Total', style: TextStyle(color: Colors.white70, fontSize: 13))),
            Text('₱${total.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            const Expanded(child: Text('Paid', style: TextStyle(color: Colors.white70, fontSize: 13))),
            Text('₱${paid.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 14)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: Text(remaining > 0 ? 'Balance Due' : 'Fully Paid',
                style: TextStyle(
                    color: remaining > 0 ? AppTheme.gold : Colors.green,
                    fontSize: 14, fontWeight: FontWeight.bold))),
            Text('₱${remaining.toStringAsFixed(2)}',
                style: TextStyle(
                    color: remaining > 0 ? AppTheme.gold : Colors.green,
                    fontWeight: FontWeight.bold, fontSize: 18)),
          ]),
          if (remaining > 0)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Balance is due upon pickup',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
            ),


          // Action buttons
          if (onPayNow != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onPayNow!();
                },
                icon: const Icon(Icons.payment_rounded),
                label: Text(
                  status == 'awaiting_payment'
                      ? 'Pay via PayMongo (min 50%)'
                      : 'Pay Remaining ₱${remaining.toStringAsFixed(2)} via PayMongo',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                style: AppTheme.primaryButton(),
              ),
            ),
          ],

          if (invoiceId != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => InvoiceScreen(invoiceId: invoiceId),
                  ));
                },
                icon: const Icon(Icons.receipt_long_rounded, color: AppTheme.gold),
                label: const Text('View Invoice',
                    style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.gold.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Persistent payment QR section ────────────────────────────────────────────

class _PaymentQrSection extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> order;
  final String status;
  final double remaining;

  const _PaymentQrSection({
    required this.docId,
    required this.order,
    required this.status,
    required this.remaining,
  });

  @override
  State<_PaymentQrSection> createState() => _PaymentQrSectionState();
}

class _PaymentQrSectionState extends State<_PaymentQrSection> {
  String? _localUrl;
  bool    _generating = false;
  bool    _stale      = false; // true while a stale link is being replaced

  @override
  void initState() {
    super.initState();
    // Validate the stored balance link against the live API on load.
    // If it was created with the old test key it won't exist in live mode
    // and we regenerate it silently.
    if (widget.status != 'awaiting_payment') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _validateStoredLink());
    }
  }

  Future<void> _validateStoredLink() async {
    final linkId = widget.order['balance_link_id'] as String?;
    if (linkId == null || !mounted) return;
    try {
      await PayMongoService.getLinkStatus(linkId);
    } catch (_) {
      // Link not found in current API mode — clear the stale entry and
      // regenerate so the customer always has a scannable live QR.
      if (!mounted) return;
      setState(() => _stale = true);
      final orderId = widget.order['order_id']?.toString() ?? widget.docId;
      FirebaseFirestore.instance.collection('Orders').doc(orderId).update({
        'balance_link_id':      FieldValue.delete(),
        'balance_checkout_url': FieldValue.delete(),
        'balance_link_amount':  FieldValue.delete(),
      }).catchError((_) {});
      if (mounted) await _generate();
    }
  }

  String? get _checkoutUrl {
    if (_stale) return _localUrl; // hide stale URL while regenerating
    return _localUrl ??
        (widget.status == 'awaiting_payment'
            ? widget.order['paymongo_checkout_url'] as String?
            : widget.order['balance_checkout_url'] as String?);
  }

  double? get _linkAmount =>
      (widget.order['balance_link_amount'] as num?)?.toDouble();

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final orderId = widget.order['order_id']?.toString() ?? widget.docId;
      final link = await PayMongoService.createLink(
        amount:      widget.remaining,
        description: 'Balance Payment $orderId (Imprenta X)',
      );

      // Save to Firestore so it persists across app restarts
      await Future.wait([
        FirebaseFirestore.instance.collection('PayMongoLinks').doc(link.id).set({
          'order_id':        orderId,
          'purpose':         'balance',
          'expected_amount': widget.remaining,
          'processed':       false,
          'created_at':      FieldValue.serverTimestamp(),
        }),
        FirebaseFirestore.instance.collection('Orders').doc(orderId).update({
          'balance_link_id':      link.id,
          'balance_checkout_url': link.checkoutUrl,
          'balance_link_amount':  widget.remaining,
        }),
      ]);

      if (mounted) setState(() => _localUrl = link.checkoutUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('QR generation failed: $e'),
              backgroundColor: Colors.red.shade700));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url    = _checkoutUrl;
    final amount = _linkAmount ?? widget.remaining;

    // No URL yet and not awaiting_payment → show Generate button
    if (url == null && widget.status != 'awaiting_payment') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.qr_code_2_rounded, color: Colors.white38, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Generate a payment QR so you or someone else can scan '
                    'and pay the remaining balance anytime.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _generating ? null : _generate,
                icon: _generating
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.gold))
                    : const Icon(Icons.qr_code_2_rounded, color: AppTheme.gold, size: 16),
                label: Text(
                  _generating ? 'Generating…' : 'Generate Payment QR Code',
                  style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.gold.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (url == null) return const SizedBox.shrink(); // awaiting_payment with no url yet

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_2_rounded, color: AppTheme.gold, size: 18),
              const SizedBox(width: 8),
              Text(
                widget.status == 'awaiting_payment'
                    ? 'SCAN TO PAY DOWNPAYMENT'
                    : 'SCAN TO PAY REMAINING BALANCE',
                style: const TextStyle(
                    color: AppTheme.gold, fontSize: 11,
                    fontWeight: FontWeight.bold, letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data:            url,
                size:            180,
                eyeStyle:        const QrEyeStyle(
                    eyeShape: QrEyeShape.square, color: Color(0xFF0f0f23)),
                dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square, color: Color(0xFF0f0f23)),
              ),
            ),
          ),

          const SizedBox(height: 12),
          Text('₱${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          const Text('Opens PayMongo → GCash / Maya / Card',
              style: TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 2),
          const Text('This QR is unique to this order and safe to share.',
              style: TextStyle(color: Colors.white24, fontSize: 10)),
        ],
      ),
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  String get _label {
    switch (status) {
      case 'awaiting_payment': return 'Awaiting Payment';
      case 'pending':          return 'Pending';
      case 'in_production':    return 'In Production';
      case 'ready':            return 'Ready';
      case 'cancelled':        return 'Cancelled';
      case 'completed':        return 'Completed';
      default:                 return status;
    }
  }

  Color get _color {
    switch (status) {
      case 'awaiting_payment': return Colors.orangeAccent;
      case 'pending':          return Colors.amber;
      case 'in_production':    return Colors.blueAccent;
      case 'ready':            return Colors.green;
      case 'cancelled':        return Colors.redAccent;
      case 'completed':        return AppTheme.accent;
      default:                 return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: _color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _color.withValues(alpha: 0.4)),
    ),
    child: Text(_label,
        style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}
