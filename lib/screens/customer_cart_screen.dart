import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import '../services/cart_manager.dart';
import '../services/paymongo_service.dart';
import '../services/file_utils.dart' as file_utils;
import 'app_theme.dart';
import 'payment_webview_screen.dart';
import 'invoice_screen.dart';
import 'customer_order_screen.dart';

class CustomerCartScreen extends StatefulWidget {
  final VoidCallback? onOrderPlaced;
  const CustomerCartScreen({super.key, this.onOrderPlaced});

  @override
  State<CustomerCartScreen> createState() => _CustomerCartScreenState();
}

class _CustomerCartScreenState extends State<CustomerCartScreen> {
  final Set<int> _selected = {};
  bool _checkingOut       = false;
  bool _processingPayment = false; // true while verifying a pending payment

  @override
  void initState() {
    super.initState();
    _selectAll();
    if (kIsWeb) {
      // Check synchronously: if pending data exists, show processing screen
      // immediately so the user never sees the old cart flash before the API
      // calls complete.
      if (file_utils.loadPendingPayment() != null) {
        _processingPayment = true;
      }
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _checkPendingPayment(),
      );
    }
  }

  void _selectAll() {
    _selected
      ..clear()
      ..addAll(List.generate(CartManager.items.length, (i) => i));
  }

  double get _subtotal =>
      _selected.fold(0.0, (sum, i) => sum + CartManager.items[i].subtotal);

  double get _downpayment => (_subtotal * 0.5 * 100).round() / 100;

  // ── Image compression ────────────────────────────────────────────────────

  Uint8List _compress(Uint8List bytes, String ext) {
    if (kIsWeb) return bytes; // package:image uses dart:io on some paths
    if (!{'jpg', 'jpeg', 'png'}.contains(ext)) return bytes;
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;
      img.Image out = decoded;
      const maxDim = 2048;
      if (decoded.width > maxDim || decoded.height > maxDim) {
        out = decoded.width >= decoded.height
            ? img.copyResize(decoded, width: maxDim)
            : img.copyResize(decoded, height: maxDim);
      }
      return Uint8List.fromList(
          ext == 'png' ? img.encodePng(out) : img.encodeJpg(out, quality: 78));
    } catch (_) {
      return bytes;
    }
  }

  String _mime(String ext) => switch (ext) {
    'pdf'           => 'application/pdf',
    'jpg' || 'jpeg' => 'image/jpeg',
    'png'           => 'image/png',
    'psd'           => 'image/vnd.adobe.photoshop',
    'ai'            => 'application/postscript',
    _               => 'application/octet-stream',
  };

  // ── Firestore ID generators ───────────────────────────────────────────────

  Future<String> _nextOrderId() async {
    final ref = FirebaseFirestore.instance.collection('Counters').doc('order');
    return FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final next = ((snap.data()?['last_id'] as int?) ?? 0) + 1;
      tx.set(ref, {'last_id': next});
      return 'ORD-${next.toString().padLeft(4, '0')}';
    });
  }

  Future<String> _nextInvoiceId() async {
    final ref = FirebaseFirestore.instance.collection('Counters').doc('invoice');
    return FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final next = ((snap.data()?['last_id'] as int?) ?? 0) + 1;
      tx.set(ref, {'last_id': next});
      return 'INV-${next.toString().padLeft(4, '0')}';
    });
  }

  // ── File upload ───────────────────────────────────────────────────────────

  Future<({List<String> urls, List<String> paths})> _uploadFiles(
      String orderId, int itemIndex, CartItem item) async {
    final urls  = <String>[];
    final paths = <String>[];
    for (final file in item.files) {
      if (file.url != null && file.url!.isNotEmpty) {
        // Already uploaded when added to cart — reuse the existing file.
        urls.add(file.url!);
        paths.add(file.path ?? '');
      } else if (file.bytes != null) {
        final ext   = file.name.split('.').last.toLowerCase();
        final bytes = _compress(file.bytes!, ext);
        final ts    = DateTime.now().millisecondsSinceEpoch;
        final path  = 'order_files/$orderId/${itemIndex}_${ts}_${file.name}';
        final ref   = FirebaseStorage.instance.ref(path);
        final task  = await ref.putData(bytes, SettableMetadata(contentType: _mime(ext)));
        urls.add(await task.ref.getDownloadURL());
        paths.add(path);
      }
    }
    return (urls: urls, paths: paths);
  }

  // ── Checkout sheet ────────────────────────────────────────────────────────

  void _showCheckoutSheet() {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one item to checkout.')),
      );
      return;
    }

    final items        = CartManager.items;
    final selectedList = _selected.toList()..sort();
    final total        = _subtotal;
    final minPay       = _downpayment;

    // Build per-item turnaround info for summary
    final summaryItems   = selectedList.map((i) => items[i]).toList();
    final turnaroundExact = summaryItems.fold<double>(
        0.0, (sum, item) => sum + item.estimatedDaysExact);
    final turnaroundDays = turnaroundExact.ceil().clamp(1, 21);
    final turnaroundLabel = () {
      final d = turnaroundExact;
      if (d <= 0.5) return 'Same day';
      if (d <  1.0) return '< 1 day';
      if (d == 1.0) return '~1 day';
      if (d <= 1.5) return '~1–2 days';
      if (d <= 2.0) return '~2 days';
      return '~${d.ceil()} days';
    }();

    final amountCtrl = TextEditingController(text: minPay.toStringAsFixed(2));

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          double payAmount = double.tryParse(amountCtrl.text) ?? minPay;
          payAmount        = payAmount.clamp(minPay, total);
          final remaining  = total - payAmount;
          final pct        = (payAmount / total * 100).round();

          return DraggableScrollableSheet(
            initialChildSize: 0.88,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, scrollCtrl) => SafeArea(
              child: Column(
                children: [
                  // Drag handle
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollCtrl,
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                        left: 20, right: 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // ── ORDER SUMMARY SECTION ─────────────────────────
                          const Text('Order Summary',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),

                          // Items
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Column(
                              children: [
                                ...summaryItems.asMap().entries.map((entry) {
                                  final idx  = entry.key;
                                  final item = entry.value;
                                  return Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 10),
                                        child: Row(
                                          children: [
                                            // Thumbnail
                                            Container(
                                              width: 42, height: 42,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(6),
                                                color: Colors.white.withValues(alpha: 0.08),
                                              ),
                                              clipBehavior: Clip.antiAlias,
                                              child: item.imageUrl.isNotEmpty
                                                  ? Image.network(item.imageUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                  const Icon(Icons.image_outlined,
                                                      color: Colors.white24, size: 18))
                                                  : const Icon(Icons.image_outlined,
                                                  color: Colors.white24, size: 18),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(item.productName,
                                                      style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w600),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    [
                                                      if (item.hasSizeInput) item.sizeLabel,
                                                      'Qty: ${item.quantity}',
                                                      if (item.material != null) item.material!,
                                                    ].join(' · '),
                                                    style: const TextStyle(
                                                        color: Colors.white54, fontSize: 11),
                                                  ),
                                                  Text(
                                                    '${item.estimatedDaysLabel} production',
                                                    style: const TextStyle(
                                                        color: AppTheme.gold, fontSize: 10),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text('₱${item.subtotal.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                    color: AppTheme.gold,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                      if (idx < summaryItems.length - 1)
                                        Divider(
                                            height: 1,
                                            color: Colors.white.withValues(alpha: 0.08)),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Turnaround + subtotal row
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.gold.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppTheme.gold.withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.schedule_rounded,
                                        color: AppTheme.gold, size: 15),
                                    const SizedBox(width: 6),
                                    const Text('Estimated Turnaround',
                                        style: TextStyle(
                                            color: Colors.white70, fontSize: 13)),
                                    const Spacer(),
                                    Text(
                                      turnaroundLabel,
                                      style: const TextStyle(
                                          color: AppTheme.gold,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Text('Order Total',
                                        style: TextStyle(
                                            color: Colors.white70, fontSize: 13)),
                                    const Spacer(),
                                    Text('₱${total.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),

                          // ── PAYMENT SECTION ───────────────────────────────
                          const Text('Payment',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),

                          // 50% info banner
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.gold.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppTheme.gold.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline,
                                    color: AppTheme.gold, size: 14),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Minimum required: ₱${minPay.toStringAsFixed(2)} (50% downpayment)',
                                    style: const TextStyle(
                                        color: AppTheme.gold,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Amount input
                          const Text('Enter payment amount',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15)),
                            ),
                            child: Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 14),
                                  child: Text('₱',
                                      style: TextStyle(
                                          color:
                                          Colors.white.withValues(alpha: 0.6),
                                          fontSize: 18)),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: amountCtrl,
                                    keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      hintText: '0.00',
                                      hintStyle: TextStyle(
                                          color: Colors.white24, fontSize: 18),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 14),
                                    ),
                                    onChanged: (v) {
                                      if (double.tryParse(v) != null) {
                                        setSheet(() {});
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Breakdown
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.gold.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppTheme.gold.withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              children: [
                                _SummaryRow(
                                    label: 'Order Total',
                                    value: total,
                                    color: Colors.white),
                                const SizedBox(height: 6),
                                _SummaryRow(
                                    label: 'You Pay Now ($pct%)',
                                    value: payAmount,
                                    color: AppTheme.gold,
                                    bold: true),
                                const Divider(color: Colors.white12, height: 14),
                                remaining > 0.009
                                    ? _SummaryRow(
                                    label: 'Remaining on Pickup',
                                    value: remaining,
                                    color: Colors.white54)
                                    : const _SummaryRow(
                                    label: 'Remaining on Pickup',
                                    value: 0,
                                    color: Colors.green),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // PayMongo info
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.blue.withValues(alpha: 0.18)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline,
                                    color: Colors.blue, size: 15),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'PayMongo opens a secure checkout with GCash, Maya, '
                                        'and card options — including a scannable QR code.',
                                    style: TextStyle(
                                        color:
                                        Colors.white.withValues(alpha: 0.65),
                                        fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Pay button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: payAmount < minPay - 0.009
                                  ? null
                                  : () {
                                final chosenAmt =
                                    double.tryParse(amountCtrl.text) ??
                                        minPay;
                                final finalAmt =
                                chosenAmt.clamp(minPay, total);
                                Navigator.pop(ctx);
                                _processCheckout(payAmount: finalAmt);
                              },
                              icon: const Icon(Icons.payment_rounded),
                              label: Text(
                                'Pay ₱${payAmount.toStringAsFixed(2)} via PayMongo',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15),
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: AppTheme.primaryButton(),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Main checkout logic ───────────────────────────────────────────────────

  Future<void> _processCheckout({required double payAmount}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _checkingOut = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      // 1. Customer info
      final userDoc = await FirebaseFirestore.instance
          .collection('User').doc(user.uid).get();
      final customerName  = userDoc.data()?['full_name']  ?? '';
      final customerEmail = userDoc.data()?['email']      ?? user.email ?? '';
      final customerId    = userDoc.data()?['customer_id']?.toString() ?? '';

      // 2. Reserve order ID + build products (files already pre-uploaded to cart)
      final orderId      = await _nextOrderId();
      final items        = CartManager.items;
      final selectedList = _selected.toList()..sort();
      final products     = <Map<String, dynamic>>[];

      for (int i = 0; i < selectedList.length; i++) {
        final item   = items[selectedList[i]];
        final upload = await _uploadFiles(orderId, i, item);
        products.add({
          'product_id':   item.productId,
          'name':         item.productName,
          'category':     item.category,
          if (item.hasSizeInput) ...{
            'width_ft':   item.widthFt,
            'height_ft':  item.heightFt,
            'size_label': item.sizeLabel,
          },
          'qty':          item.quantity,
          if (item.material != null) 'material': item.material,
          'unit_price':   item.unitPrice,
          'pricing_unit': item.pricingUnit,
          'price':        item.subtotal,
          'file_urls':    upload.urls,
          'file_paths':   upload.paths,
          'file_names':   item.files.map((f) => f.name).toList(),
          'notes':        item.notes,
        });
      }

      // 3. Turnaround
      final selectedItems  = selectedList.map((i) => items[i]).toList();
      final turnaroundDays = selectedItems
          .fold<double>(0.0, (s, it) => s + it.estimatedDaysExact)
          .ceil()
          .clamp(1, 21);
      final estimatedCompletion = DateTime.now().add(Duration(days: turnaroundDays));

      // 4. Create PayMongo link (Cloud Function also resolves pm.link redirect
      //    to direct checkout.paymongo.com URL, bypassing Firefox bounce-tracker).
      final pctLabel = (payAmount / _subtotal * 100).round();
      final link = await PayMongoService.createLink(
        amount:      payAmount,
        description: '$pctLabel% Payment - $orderId (Imprenta X)',
      );

      // 5. Log link for webhook (minimal — no Order doc yet)
      await FirebaseFirestore.instance.collection('PayMongoLinks').doc(link.id).set({
        'order_id':        orderId,
        'purpose':         'downpayment',
        'expected_amount': payAmount,
        'processed':       false,
        'created_at':      FieldValue.serverTimestamp(),
      });

      setState(() => _checkingOut = false);
      if (!mounted) return;

      if (kIsWeb) {
        // ── Web: navigate the current tab to PayMongo (no popup needed).
        // Save all order data to localStorage (no plugin needed) so
        // _checkPendingPayment() can restore it when the user returns.
        file_utils.savePendingPayment(jsonEncode({
          'orderId':             orderId,
          'linkId':              link.id,
          'uid':                 user.uid,
          'customerName':        customerName,
          'customerEmail':       customerEmail,
          'customerId':          customerId,
          'products':            products,
          'subtotal':            _subtotal,
          'payAmount':           payAmount,
          'turnaroundDays':      turnaroundDays,
          'estimatedCompletion': estimatedCompletion.toIso8601String(),
          'cartIndices':         selectedList,
        }));
        file_utils.navigateCurrentPage(link.checkoutUrl);
        return;
      }

      // ── Mobile: use PaymentWebViewScreen with background polling.
      final paid = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PaymentWebViewScreen(
            checkoutUrl: link.checkoutUrl,
            linkId:      link.id,
            orderId:     orderId,
            payAmount:   payAmount,
          ),
        ),
      );

      if (!mounted) return;

      if (paid == true) {
        CartManager.removeIndices(selectedList);
        widget.onOrderPlaced?.call();
        await _onPaymentConfirmed(
          orderId:             orderId,
          customerName:        customerName,
          customerEmail:       customerEmail,
          customerId:          customerId,
          products:            products,
          paidAmount:          payAmount,
          total:               _subtotal,
          turnaroundDays:      turnaroundDays,
          estimatedCompletion: estimatedCompletion,
          linkId:              link.id,
          uid:                 user.uid,
        );
      }
      // If not paid on mobile: cart unchanged, nothing in Firestore.

    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Checkout failed: $e'),
        backgroundColor: Colors.red.shade700,
      ));
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  // ── Web: called on screen init to process a payment return ─────────────────

  Future<void> _checkPendingPayment() async {
    // Clean up any ?pm= URL param if present (from an explicit redirect).
    final returnStatus = file_utils.getPaymentReturnStatus();
    if (returnStatus.isNotEmpty) file_utils.clearPaymentReturnParam();

    // Check localStorage regardless of URL params — PayMongo Payment Links
    // don't support redirect URLs, so the user always returns via back button.
    // We detect completion by calling getLinkStatus directly.
    final raw = file_utils.loadPendingPayment();
    if (raw == null) return;

    final data   = jsonDecode(raw) as Map<String, dynamic>;
    final linkId = data['linkId'] as String;
    final uid    = data['uid']    as String;

    String payStatus;
    try {
      payStatus = await PayMongoService.getLinkStatus(linkId);
    } catch (_) {
      return; // can't verify — leave pending data for next cart open
    }

    if (payStatus != 'paid') {
      if (returnStatus == 'failed') file_utils.clearPendingPayment();
      if (mounted) setState(() => _processingPayment = false);
      return;
    }

    // Payment confirmed — process the order.
    file_utils.clearPendingPayment();
    if (!mounted) return;

    // Ensure cart is loaded before removing items.
    await CartManager.loadForUser(uid);
    if (!mounted) return;

    final orderId           = data['orderId']       as String;
    final customerName      = data['customerName']  as String;
    final customerEmail     = data['customerEmail'] as String;
    final customerId        = data['customerId']    as String;
    final products          = List<Map<String, dynamic>>.from(
        (data['products'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
    final subtotal          = (data['subtotal']     as num).toDouble();
    final payAmount         = (data['payAmount']    as num).toDouble();
    final turnaroundDays    = data['turnaroundDays'] as int;
    final estimatedCompletion = DateTime.parse(data['estimatedCompletion'] as String);
    final cartIndices       = (data['cartIndices']  as List?)
        ?.map((e) => e as int).toList() ?? [];

    if (cartIndices.isNotEmpty) {
      CartManager.removeIndices(cartIndices);
      widget.onOrderPlaced?.call();
      if (mounted) setState(() {});
    }

    await _onPaymentConfirmed(
      orderId:             orderId,
      customerName:        customerName,
      customerEmail:       customerEmail,
      customerId:          customerId,
      products:            products,
      paidAmount:          payAmount,
      total:               subtotal,
      turnaroundDays:      turnaroundDays,
      estimatedCompletion: estimatedCompletion,
      linkId:              linkId,
      uid:                 uid,
    );
  }

  Future<void> _onPaymentConfirmed({
    required String orderId,
    required String customerName,
    required String customerEmail,
    required String customerId,
    required List<Map<String, dynamic>> products,
    required double paidAmount,
    required double total,
    required int    turnaroundDays,
    required DateTime estimatedCompletion,
    required String linkId,
    required String uid,
  }) async {
    final remaining   = (total - paidAmount).clamp(0.0, double.infinity);
    final isFullyPaid = remaining < 0.01;

    final invoiceId = await _nextInvoiceId();
    final batch     = FirebaseFirestore.instance.batch();
    final now       = FieldValue.serverTimestamp();

    // Create Order (directly as 'pending' — no awaiting_payment step)
    final orderRef = FirebaseFirestore.instance.collection('Orders').doc(orderId);
    batch.set(orderRef, {
      'order_id':               orderId,
      'customer_uid':           uid,
      'customer_id':            customerId,
      'customer_name':          customerName,
      'customer_email':         customerEmail,
      'status':                 'pending',
      'products':               products,
      'total_price':            total,
      'amount_paid':            paidAmount,
      'remaining_balance':      remaining,
      'payment_status':         isFullyPaid ? 'paid' : 'partial',
      'payment_method':         'online',
      'paymongo_link_id':       linkId,
      'invoice_id':             invoiceId,
      'turnaround_days':        turnaroundDays,
      'estimated_completion':   Timestamp.fromDate(estimatedCompletion),
      'shipping':               'pickup',
      'has_review':             false,
      'paid_at':                now,
      'created_at':             now,
    });

    // Create Invoice
    final invoiceRef = FirebaseFirestore.instance.collection('Invoices').doc(invoiceId);
    batch.set(invoiceRef, {
      'invoice_id':        invoiceId,
      'order_id':          orderId,
      'customer_name':     customerName,
      'customer_email':    customerEmail,
      'issued_date':       now,
      'items':             products,
      'total_amount':      total,
      'amount_paid':       paidAmount,
      'remaining_balance': remaining,
      'payment_method':    'online',
      'transaction_ref':   linkId,
    });

    // Create Order_Queue entry
    final queueRef = FirebaseFirestore.instance.collection('Order_Queue').doc();
    batch.set(queueRef, {
      'order_id':        orderId,
      'customer_uid':    uid,
      'customer_name':   customerName,
      'job_status':      'pending',
      'turnaround_days': turnaroundDays,
      'products':        products,
      'total_price':     total,
      'created_at':      now,
    });

    await batch.commit();

    // Sales record
    await FirebaseFirestore.instance.collection('Sales_Records').add({
      'order_id':              orderId,
      'customer_name':         customerName,
      'customer_id':           customerId,
      'payment_type':          isFullyPaid ? 'full' : 'downpayment',
      'payment_method':        'online',
      'transaction_reference': linkId,
      'sale_amount':           paidAmount,
      'order_total':           total,
      'sale_date':             now,
    });

    // Chat system message
    final threadRef = FirebaseFirestore.instance
        .collection('Messages').doc('chat_$uid');
    await threadRef.set({
      'customer_uid':    uid,
      'customer_name':   customerName,
      'last_message':    'Payment confirmed: $orderId',
      'last_updated':    now,
      'unread_customer': 0,
      'unread_employee': FieldValue.increment(1),
    }, SetOptions(merge: true));
    await threadRef.collection('chat').add({
      'sender_uid':  'system',
      'sender_role': 'system',
      'text': 'Payment confirmed for $orderId\n'
              'Paid: ₱${paidAmount.toStringAsFixed(2)}'
              '${remaining > 0 ? ' | Balance due: ₱${remaining.toStringAsFixed(2)}' : ' (Fully paid)'}',
      'timestamp': now,
    });

    if (!mounted) return;

    // Navigate immediately to invoice — no snackbar, no delay.
    // Remove the cart screen from the stack so back goes straight to homepage.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => InvoiceScreen(
          invoiceId:   invoiceId,
          fromPayment: true,
        ),
      ),
      (route) => route.isFirst, // keep only the root (CustomerHomepage)
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Show a full-screen spinner while verifying a pending web payment.
    // This prevents a flash of the old cart before the check resolves.
    if (_processingPayment) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.gold),
            SizedBox(height: 16),
            Text('Confirming your payment…',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ),
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: CartManager.count,
      builder: (context, _, __) {
        final items = CartManager.items;
        _selected.removeWhere((i) => i >= items.length);

        if (items.isEmpty) return _emptyState();

        return Column(
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  const Text('My Cart',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.gold.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                        '${items.length} item${items.length != 1 ? 's' : ''}',
                        style: const TextStyle(color: AppTheme.gold, fontSize: 11)),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _selected.length == items.length && items.isNotEmpty,
                        tristate: _selected.isNotEmpty && _selected.length < items.length,
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selectAll();
                          } else {
                            _selected.clear();
                          }
                        }),
                        activeColor: AppTheme.gold,
                        checkColor: Colors.black,
                        side: const BorderSide(color: Colors.white38),
                      ),
                      const Text('All',
                          style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),

            // ── Items list ─────────────────────────────────────────────────
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _CartItemTile(
                  item:       items[i],
                  index:      i,
                  isSelected: _selected.contains(i),
                  onToggle: (val) => setState(() {
                    if (val) _selected.add(i);
                    else     _selected.remove(i);
                  }),
                  onDelete: () => setState(() {
                    final newSelected = <int>{};
                    for (final s in _selected) {
                      if (s < i)      newSelected.add(s);
                      else if (s > i) newSelected.add(s - 1);
                    }
                    _selected..clear()..addAll(newSelected);
                    CartManager.removeAt(i);
                  }),
                  onEdit: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CustomerOrderScreen(
                      product: {
                        'product_id':   items[i].productId,
                        'product_name': items[i].productName,
                        'category':     items[i].category,
                        'image_url':    items[i].imageUrl,
                        'price':        items[i].unitPrice,
                        'pricing_unit': items[i].pricingUnit,
                        'min_quantity': 1,
                        'description':  '',
                      },
                      initialItem: items[i],
                      editIndex:   i,
                    ),
                  )),
                ),
              ),
            ),

            // ── Summary + checkout ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${_selected.length} of ${items.length} selected',
                                style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            Text(
                                '50% down: ₱${_downpayment.toStringAsFixed(2)}',
                                style: const TextStyle(color: AppTheme.gold, fontSize: 11)),
                          ],
                        ),
                        const Spacer(),
                        Text(
                            '₱${_subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _selected.isEmpty || _checkingOut
                            ? null
                            : _showCheckoutSheet,
                        style: AppTheme.primaryButton(),
                        child: _checkingOut
                            ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                            : const Text('Checkout',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _emptyState() => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shopping_cart_outlined, size: 56, color: Colors.white24),
        SizedBox(height: 16),
        Text('Your cart is empty',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: 6),
        Text('Browse products and add items to your cart',
            style: TextStyle(color: Colors.white38, fontSize: 13),
            textAlign: TextAlign.center),
      ],
    ),
  );
}

// ── Summary row ───────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final String label;
  final double value;
  final Color  color;
  final bool   bold;

  const _SummaryRow({required this.label, required this.value, required this.color, this.bold = false});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13))),
      Text('₱${value.toStringAsFixed(2)}',
          style: TextStyle(
              color: color,
              fontSize: bold ? 15 : 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
    ],
  );
}

// ── Cart item tile ────────────────────────────────────────────────────────────

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final int index;
  final bool isSelected;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;

  const _CartItemTile({
    required this.item,
    required this.index,
    required this.isSelected,
    required this.onToggle,
    required this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.glassCard(opacity: isSelected ? 0.18 : 0.09, radius: 14),
      child: Row(
        children: [
          Checkbox(
            value: isSelected,
            onChanged: (v) => onToggle(v ?? false),
            activeColor: AppTheme.gold,
            checkColor: Colors.black,
            side: const BorderSide(color: Colors.white38),
          ),
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white.withValues(alpha: 0.08),
            ),
            clipBehavior: Clip.antiAlias,
            child: item.imageUrl.isNotEmpty
                ? Image.network(item.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                const Icon(Icons.image_outlined, color: Colors.white24, size: 22))
                : const Icon(Icons.image_outlined, color: Colors.white24, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.productName,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (item.hasSizeInput) item.sizeLabel,
                      'Qty: ${item.quantity}',
                      if (item.material != null) item.material!,
                    ].join(' · '),
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  if (item.files.isNotEmpty)
                    Text(
                        '${item.files.length} file${item.files.length != 1 ? 's' : ''} attached',
                        style: const TextStyle(color: AppTheme.gold, fontSize: 10))
                  else
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Colors.orangeAccent, size: 11),
                        const SizedBox(width: 3),
                        Text('No design file — tap edit to attach',
                            style: TextStyle(
                                color: Colors.orangeAccent.withValues(alpha: 0.85),
                                fontSize: 10)),
                      ],
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('₱${item.subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onEdit != null)
                      GestureDetector(
                        onTap: onEdit,
                        child: const Icon(Icons.edit_outlined, color: Colors.white54, size: 18),
                      ),
                    if (onEdit != null) const SizedBox(width: 10),
                    GestureDetector(
                      onTap: onDelete,
                      child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}