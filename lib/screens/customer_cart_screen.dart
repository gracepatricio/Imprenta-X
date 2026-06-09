import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import '../services/cart_manager.dart';
import '../services/paymongo_service.dart';
import '../services/turnaround_service.dart';
import 'app_theme.dart';
import 'payment_webview_screen.dart';
import 'invoice_screen.dart';
import 'customer_order_screen.dart';
import '../services/inventory_service.dart';

class CustomerCartScreen extends StatefulWidget {
  final VoidCallback? onOrderPlaced;
  const CustomerCartScreen({super.key, this.onOrderPlaced});

  @override
  State<CustomerCartScreen> createState() => _CustomerCartScreenState();
}

class _CustomerCartScreenState extends State<CustomerCartScreen> {
  final Set<int> _selected = {};
  bool _checkingOut = false;

  @override
  void initState() {
    super.initState();
    _selectAll();
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
    if (kIsWeb) return bytes;
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
        ext == 'png' ? img.encodePng(out) : img.encodeJpg(out, quality: 78),
      );
    } catch (_) {
      return bytes;
    }
  }

  String _mime(String ext) => switch (ext) {
    'pdf' => 'application/pdf',
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'psd' => 'image/vnd.adobe.photoshop',
    'ai' => 'application/postscript',
    _ => 'application/octet-stream',
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
    final ref = FirebaseFirestore.instance
        .collection('Counters')
        .doc('invoice');
    return FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final next = ((snap.data()?['last_id'] as int?) ?? 0) + 1;
      tx.set(ref, {'last_id': next});
      return 'INV-${next.toString().padLeft(4, '0')}';
    });
  }

  // ── File upload ───────────────────────────────────────────────────────────

  Future<({List<String> urls, List<String> paths})> _uploadFiles(
    String orderId,
    int itemIndex,
    CartItem item,
  ) async {
    final urls = <String>[];
    final paths = <String>[];
    for (final file in item.files) {
      if (file.url != null && file.url!.isNotEmpty) {
        urls.add(file.url!);
        paths.add(file.path ?? '');
      } else if (file.bytes != null) {
        final ext = file.name.split('.').last.toLowerCase();
        final bytes = _compress(file.bytes!, ext);
        final ts = DateTime.now().millisecondsSinceEpoch;
        final path = 'order_files/$orderId/${itemIndex}_${ts}_${file.name}';
        final ref = FirebaseStorage.instance.ref(path);
        final task = await ref.putData(
          bytes,
          SettableMetadata(contentType: _mime(ext)),
        );
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

    final items = CartManager.items;
    final selectedList = _selected.toList()..sort();
    final total = _subtotal;
    final minPay = _downpayment;

    final summaryItems = selectedList.map((i) => items[i]).toList();
    const turnaroundLabel = 'Same day – 4 days';

    final amountCtrl = TextEditingController(text: minPay.toStringAsFixed(2));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          double payAmount = double.tryParse(amountCtrl.text) ?? minPay;
          payAmount = payAmount.clamp(minPay, total);
          final remaining = total - payAmount;
          final pct = (payAmount / total * 100).round();

          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0C091F).withValues(alpha: 0.95),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: DraggableScrollableSheet(
                  initialChildSize: 0.88,
                  minChildSize: 0.5,
                  maxChildSize: 0.95,
                  expand: false,
                  builder: (_, scrollCtrl) => SafeArea(
                    child: Column(
                      children: [
                        // Drag handle
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Container(
                              width: 44,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),

                        Expanded(
                          child: SingleChildScrollView(
                            controller: scrollCtrl,
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
                              left: 20,
                              right: 20,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── ORDER SUMMARY SECTION ─────────────────────
                                _SheetSectionHeader(title: 'Order Summary'),
                                const SizedBox(height: 14),

                                // Items card
                                _FrostedCard(
                                  child: Column(
                                    children: [
                                      ...summaryItems.asMap().entries.map((
                                        entry,
                                      ) {
                                        final idx = entry.key;
                                        final item = entry.value;
                                        return Column(
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 12,
                                                  ),
                                              child: Row(
                                                children: [
                                                  // Thumbnail
                                                  Container(
                                                    width: 46,
                                                    height: 46,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.08,
                                                          ),
                                                      border: Border.all(
                                                        color: Colors.white
                                                            .withValues(
                                                              alpha: 0.1,
                                                            ),
                                                      ),
                                                    ),
                                                    clipBehavior:
                                                        Clip.antiAlias,
                                                    child:
                                                        item.imageUrl.isNotEmpty
                                                        ? Image.network(
                                                            item.imageUrl,
                                                            fit: BoxFit.cover,
                                                            errorBuilder:
                                                                (
                                                                  _,
                                                                  __,
                                                                  ___,
                                                                ) => const Icon(
                                                                  Icons
                                                                      .image_outlined,
                                                                  color: Colors
                                                                      .white24,
                                                                  size: 18,
                                                                ),
                                                          )
                                                        : const Icon(
                                                            Icons
                                                                .image_outlined,
                                                            color:
                                                                Colors.white24,
                                                            size: 18,
                                                          ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          item.productName,
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                        const SizedBox(
                                                          height: 3,
                                                        ),
                                                        Text(
                                                          [
                                                            if (item
                                                                .hasSizeInput)
                                                              item.sizeLabel,
                                                            'Qty: ${item.quantity}',
                                                            if (item.material !=
                                                                null)
                                                              item.material!,
                                                          ].join(' · '),
                                                          style: TextStyle(
                                                            color: Colors.white
                                                                .withValues(
                                                                  alpha: 0.5,
                                                                ),
                                                            fontSize: 11,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                        Row(
                                                          children: [
                                                            const Icon(
                                                              Icons
                                                                  .schedule_rounded,
                                                              color:
                                                                  AppTheme.gold,
                                                              size: 11,
                                                            ),
                                                            const SizedBox(
                                                              width: 3,
                                                            ),
                                                            Text(
                                                              '${item.estimatedDaysLabel} production',
                                                              style:
                                                                  const TextStyle(
                                                                    color:
                                                                        AppTheme
                                                                            .gold,
                                                                    fontSize:
                                                                        10,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '₱${item.subtotal.toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                      color: AppTheme.gold,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (idx < summaryItems.length - 1)
                                              Divider(
                                                height: 1,
                                                color: Colors.white.withValues(
                                                  alpha: 0.07,
                                                ),
                                              ),
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
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.gold.withValues(
                                      alpha: 0.07,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppTheme.gold.withValues(
                                        alpha: 0.22,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: AppTheme.gold.withValues(
                                                alpha: 0.15,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.schedule_rounded,
                                              color: AppTheme.gold,
                                              size: 14,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          const Text(
                                            'Estimated Turnaround',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            turnaroundLabel,
                                            style: const TextStyle(
                                              color: AppTheme.gold,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Divider(
                                        height: 1,
                                        color: AppTheme.gold.withValues(
                                          alpha: 0.15,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          const Text(
                                            'Order Total',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            '₱${total.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 26),

                                // ── PAYMENT SECTION ───────────────────────────
                                _SheetSectionHeader(title: 'Payment'),
                                const SizedBox(height: 14),

                                // 50% info banner
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.gold.withValues(
                                      alpha: 0.09,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.gold.withValues(
                                        alpha: 0.28,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color: AppTheme.gold.withValues(
                                            alpha: 0.18,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.info_outline,
                                          color: AppTheme.gold,
                                          size: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Minimum required: ₱${minPay.toStringAsFixed(2)} (50% downpayment)',
                                          style: const TextStyle(
                                            color: AppTheme.gold,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Amount input label
                                Text(
                                  'Enter payment amount',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Amount input field
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.14,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.only(
                                          left: 16,
                                        ),
                                        child: Text(
                                          '₱',
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.55,
                                            ),
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: TextField(
                                          controller: amountCtrl,
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          decoration: InputDecoration(
                                            border: InputBorder.none,
                                            hintText: '0.00',
                                            hintStyle: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.2,
                                              ),
                                              fontSize: 20,
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 16,
                                                ),
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

                                // Breakdown card
                                _FrostedCard(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      children: [
                                        _SheetSummaryRow(
                                          label: 'Order Total',
                                          value: total,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(height: 8),
                                        _SheetSummaryRow(
                                          label: 'You Pay Now ($pct%)',
                                          value: payAmount,
                                          color: AppTheme.gold,
                                          bold: true,
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                          child: Divider(
                                            height: 1,
                                            color: Colors.white.withValues(
                                              alpha: 0.08,
                                            ),
                                          ),
                                        ),
                                        remaining > 0.009
                                            ? _SheetSummaryRow(
                                                label: 'Remaining on Pickup',
                                                value: remaining,
                                                color: Colors.white54,
                                              )
                                            : const _SheetSummaryRow(
                                                label: 'Remaining on Pickup',
                                                value: 0,
                                                color: Colors.green,
                                              ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // PayMongo info
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF1E3A6E,
                                    ).withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.blue.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withValues(
                                            alpha: 0.18,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.shield_outlined,
                                          color: Colors.blue,
                                          size: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'PayMongo opens a secure checkout with GCash, Maya, '
                                          'and card options — including a scannable QR code.',
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.6,
                                            ),
                                            fontSize: 11,
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Pay button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: payAmount < minPay - 0.009
                                        ? null
                                        : () {
                                            final chosenAmt =
                                                double.tryParse(
                                                  amountCtrl.text,
                                                ) ??
                                                minPay;
                                            final finalAmt = chosenAmt.clamp(
                                              minPay,
                                              total,
                                            );
                                            Navigator.pop(ctx);
                                            _processCheckout(
                                              payAmount: finalAmt,
                                            );
                                          },
                                    icon: const Icon(
                                      Icons.payment_rounded,
                                      size: 18,
                                    ),
                                    label: Text(
                                      'Pay ₱${payAmount.toStringAsFixed(2)} via PayMongo',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
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
                ),
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
          .collection('User')
          .doc(user.uid)
          .get();
      final customerName = userDoc.data()?['full_name'] ?? '';
      final customerEmail = userDoc.data()?['email'] ?? user.email ?? '';
      final customerId = userDoc.data()?['customer_id']?.toString() ?? '';

      // 2. Reserve order ID + build products
      final orderId = await _nextOrderId();
      final items = CartManager.items;
      final selectedList = _selected.toList()..sort();
      final products = <Map<String, dynamic>>[];

      for (int i = 0; i < selectedList.length; i++) {
        final item = items[selectedList[i]];
        final upload = await _uploadFiles(orderId, i, item);
        products.add({
          'product_id': item.productId,
          'name': item.productName,
          'category': item.category,
          if (item.hasSizeInput) ...{
            'width_ft': item.widthFt,
            'height_ft': item.heightFt,
            'size_label': item.sizeLabel,
          },
          'qty': item.quantity,
          if (item.material != null) 'material': item.material,
          'unit_price': item.unitPrice,
          'pricing_unit': item.pricingUnit,
          'price': item.subtotal,
          'file_urls': upload.urls,
          'file_paths': upload.paths,
          'file_names': item.files.map((f) => f.name).toList(),
          'notes': item.notes,
        });
      }

      // 3. Turnaround
      final selectedItems = selectedList.map((i) => items[i]).toList();
      const turnaroundDays = 4;
      final estimatedCompletion = DateTime.now().add(
        const Duration(days: turnaroundDays),
      );

      // 4. Create PayMongo link
      final pctLabel = (payAmount / _subtotal * 100).round();
      final link = await PayMongoService.createLink(
        amount: payAmount,
        description: '$pctLabel% Payment - $orderId (Imprenta X)',
      );

      // 5. Log link for webhook
      await FirebaseFirestore.instance
          .collection('PayMongoLinks')
          .doc(link.id)
          .set({
            'order_id': orderId,
            'purpose': 'downpayment',
            'expected_amount': payAmount,
            'processed': false,
            'created_at': FieldValue.serverTimestamp(),
          });

      setState(() => _checkingOut = false);
      if (!mounted) return;

      final paid = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PaymentWebViewScreen(
            checkoutUrl: link.checkoutUrl,
            linkId: link.id,
            orderId: orderId,
            payAmount: payAmount,
          ),
        ),
      );

      if (!mounted) return;

      if (paid == true) {
        final total = _subtotal;
        CartManager.removeIndices(selectedList);
        widget.onOrderPlaced?.call();
        await _onPaymentConfirmed(
          orderId: orderId,
          customerName: customerName,
          customerEmail: customerEmail,
          customerId: customerId,
          products: products,
          paidAmount: payAmount,
          total: total,
          turnaroundDays: turnaroundDays,
          estimatedCompletion: estimatedCompletion,
          linkId: link.id,
          uid: user.uid,
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Checkout failed: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  Future<void> _onPaymentConfirmed({
    required String orderId,
    required String customerName,
    required String customerEmail,
    required String customerId,
    required List<Map<String, dynamic>> products,
    required double paidAmount,
    required double total,
    required int turnaroundDays,
    required DateTime estimatedCompletion,
    required String linkId,
    required String uid,
  }) async {
    final remaining = (total - paidAmount).clamp(0.0, double.infinity);
    final isFullyPaid = remaining < 0.01;

    final invoiceId = await _nextInvoiceId();
    final batch = FirebaseFirestore.instance.batch();
    final now = FieldValue.serverTimestamp();

    final orderRef = FirebaseFirestore.instance
        .collection('Orders')
        .doc(orderId);
    batch.set(orderRef, {
      'order_id': orderId,
      'customer_uid': uid,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_email': customerEmail,
      'status': 'pending',
      'products': products,
      'total_price': total,
      'amount_paid': paidAmount,
      'remaining_balance': remaining,
      'payment_status': isFullyPaid ? 'paid' : 'partial',
      'payment_method': 'online',
      'paymongo_link_id': linkId,
      'invoice_id': invoiceId,
      'turnaround_days': turnaroundDays,
      'estimated_completion': Timestamp.fromDate(estimatedCompletion),
      'shipping': 'pickup',
      'has_review': false,
      'paid_at': now,
      'created_at': now,
    });

    final invoiceRef = FirebaseFirestore.instance
        .collection('Invoices')
        .doc(invoiceId);
    batch.set(invoiceRef, {
      'invoice_id': invoiceId,
      'order_id': orderId,
      'customer_name': customerName,
      'customer_email': customerEmail,
      'customer_id': customerId,
      'issued_date': now,
      'items': products,
      'total_amount': total,
      'amount_paid': paidAmount,
      'remaining_balance': remaining,
      'payment_method': 'online',
      'transaction_ref': linkId,
    });

    final queueRef = FirebaseFirestore.instance.collection('Order_Queue').doc();
    batch.set(queueRef, {
      'order_id': orderId,
      'customer_uid': uid,
      'customer_name': customerName,
      'customer_id': customerId,
      'job_status': 'pending',
      'turnaround_days': turnaroundDays,
      'estimated_completion': Timestamp.fromDate(estimatedCompletion),
      'products': products,
      'total_price': total,
      'created_at': now,
    });

    await batch.commit();

    // Soft-reserve raw materials so customers browsing see accurate availability.
    // Best-effort: a reservation failure must not block a completed order.
    try {
      await InventoryService.reserveForOrder(
        orderId: orderId,
        products: products,
      );
    } catch (_) {}

    await FirebaseFirestore.instance.collection('Sales_Records').add({
      'order_id': orderId,
      'customer_name': customerName,
      'customer_id': customerId,
      'payment_type': isFullyPaid ? 'full' : 'downpayment',
      'payment_method': 'online',
      'transaction_reference': linkId,
      'sale_amount': paidAmount,
      'order_total': total,
      'sale_date': now,
    });

    final threadRef = FirebaseFirestore.instance
        .collection('Messages')
        .doc('chat_$uid');
    await threadRef.set({
      'customer_uid': uid,
      'customer_name': customerName,
      'last_message': 'Payment confirmed: $orderId',
      'last_updated': now,
      'unread_customer': 0,
      'unread_employee': FieldValue.increment(1),
    }, SetOptions(merge: true));
    await threadRef.collection('chat').add({
      'sender_uid': 'system',
      'sender_role': 'system',
      'text':
          'Payment confirmed for $orderId\n'
          'Paid: ₱${paidAmount.toStringAsFixed(2)}'
          '${remaining > 0 ? ' | Balance due: ₱${remaining.toStringAsFixed(2)}' : ' (Fully paid)'}',
      'timestamp': now,
    });

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => InvoiceScreen(invoiceId: invoiceId, fromPayment: true),
      ),
      (route) => route.isFirst,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        final hPad = isWide ? 24.0 : 16.0;

        return ValueListenableBuilder<int>(
          valueListenable: CartManager.count,
          builder: (context, _, __) {
            final items = CartManager.items;
            _selected.removeWhere((i) => i >= items.length);

            if (items.isEmpty) return _emptyState();

            return Column(
              children: [
                // ── My Cart frosted glass enclosure ────────────────────────
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 12, 9, 31).withValues(alpha: 0.40),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.30),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 32,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // ── Header ────────────────────────────────────
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppTheme.gold,
                                            AppTheme.gold.withValues(alpha: 0.5),
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                        borderRadius: BorderRadius.circular(2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.gold.withValues(alpha: 0.45),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      'My Cart',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.gold.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppTheme.gold.withValues(alpha: 0.45),
                                        ),
                                      ),
                                      child: Text(
                                        '${items.length} item${items.length != 1 ? 's' : ''}',
                                        style: const TextStyle(
                                          color: AppTheme.gold,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Checkbox(
                                          value:
                                              _selected.length == items.length &&
                                              items.isNotEmpty,
                                          tristate:
                                              _selected.isNotEmpty &&
                                              _selected.length < items.length,
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
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        Text(
                                          'All',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.5),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // ── Items list (newest first) ───────────────────
                              Expanded(
                                child: ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                  itemCount: items.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (_, d) {
                                    // Reverse display: newest item shown at top
                                    final i = items.length - 1 - d;
                                    return _CartItemTile(
                                      item: items[i],
                                      index: i,
                                      isSelected: _selected.contains(i),
                                      onToggle: (val) => setState(() {
                                        if (val) _selected.add(i);
                                        else _selected.remove(i);
                                      }),
                                      onDelete: () => setState(() {
                                        final newSelected = <int>{};
                                        for (final s in _selected) {
                                          if (s < i) newSelected.add(s);
                                          else if (s > i) newSelected.add(s - 1);
                                        }
                                        _selected
                                          ..clear()
                                          ..addAll(newSelected);
                                        CartManager.removeAt(i);
                                      }),
                                      onEdit: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => CustomerOrderScreen(
                                            product: {
                                              'product_id': items[i].productId,
                                              'product_name': items[i].productName,
                                              'category': items[i].category,
                                              'image_url': items[i].imageUrl,
                                              'price': items[i].unitPrice,
                                              'pricing_unit': items[i].pricingUnit,
                                              'min_quantity': 1,
                                              'description': '',
                                            },
                                            initialItem: items[i],
                                            editIndex: i,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Summary + checkout ─────────────────────────────────────
                ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C091F).withValues(alpha: 0.88),
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                // Selection + downpayment hint
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_selected.length} of ${items.length} selected',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.45,
                                        ),
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.lock_outline_rounded,
                                          color: AppTheme.gold,
                                          size: 11,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '50% down: ₱${_downpayment.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: AppTheme.gold,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                // Subtotal
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Total',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.45,
                                        ),
                                        fontSize: 11,
                                      ),
                                    ),
                                    Text(
                                      '₱${_subtotal.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
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
                                          strokeWidth: 2,
                                          color: Colors.black,
                                        ),
                                      )
                                    : const Text(
                                        'Checkout',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _emptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: const Icon(
            Icons.shopping_cart_outlined,
            size: 36,
            color: Colors.white24,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Your cart is empty',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Browse products and add items to get started.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.38),
            fontSize: 13,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

// ── Shared UI Helpers ─────────────────────────────────────────────────────────

/// Frosted glass card — mirrors _FrostedSectionContainer from CustomerHomeScreen
class _FrostedCard extends StatelessWidget {
  final Widget child;
  const _FrostedCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0C091F).withValues(alpha: 0.40),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Section header with gold accent bar — mirrors _SectionHeader
class _SheetSectionHeader extends StatelessWidget {
  final String title;
  const _SheetSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.gold, AppTheme.gold.withValues(alpha: 0.5)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.gold.withValues(alpha: 0.5),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Summary row used inside the checkout sheet breakdown card
class _SheetSummaryRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool bold;

  const _SheetSummaryRow({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 13,
          ),
        ),
      ),
      Text(
        '₱${value.toStringAsFixed(2)}',
        style: TextStyle(
          color: color,
          fontSize: bold ? 15 : 13,
          fontWeight: bold ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    ],
  );
}

// ── Cart item tile ────────────────────────────────────────────────────────────

class _CartItemTile extends StatefulWidget {
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
  State<_CartItemTile> createState() => _CartItemTileState();
}

class _CartItemTileState extends State<_CartItemTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: widget.isSelected
              ? Colors.white.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.10),
          border: Border.all(
            color: widget.isSelected
                ? (_hovered
                      ? AppTheme.gold.withValues(alpha: 0.75)
                      : AppTheme.gold.withValues(alpha: 0.45))
                : Colors.white.withValues(alpha: _hovered ? 0.35 : 0.22),
            width: widget.isSelected ? 1.3 : 1.1,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: widget.isSelected
                        ? AppTheme.gold.withValues(alpha: 0.18)
                        : Colors.black.withValues(alpha: 0.20),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Checkbox
            Checkbox(
              value: widget.isSelected,
              onChanged: (v) => widget.onToggle(v ?? false),
              activeColor: AppTheme.gold,
              checkColor: Colors.black,
              side: const BorderSide(color: Colors.white38),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),

            // Thumbnail
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white.withValues(alpha: 0.07),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              clipBehavior: Clip.antiAlias,
              child: item.imageUrl.isNotEmpty
                  ? Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.image_outlined,
                        color: Colors.white24,
                        size: 22,
                      ),
                    )
                  : const Icon(
                      Icons.image_outlined,
                      color: Colors.white24,
                      size: 22,
                    ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (item.hasSizeInput) item.sizeLabel,
                        'Qty: ${item.quantity}',
                        if (item.material != null) item.material!,
                      ].join(' · '),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (item.files.isNotEmpty)
                      Row(
                        children: [
                          const Icon(
                            Icons.attach_file_rounded,
                            color: AppTheme.gold,
                            size: 11,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${item.files.length} file${item.files.length != 1 ? 's' : ''} attached',
                            style: const TextStyle(
                              color: AppTheme.gold,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orangeAccent,
                            size: 11,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'No design file — tap edit to attach',
                            style: TextStyle(
                              color: Colors.orangeAccent.withValues(
                                alpha: 0.85,
                              ),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            // Price + actions
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '₱${item.subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppTheme.gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.onEdit != null)
                        GestureDetector(
                          onTap: widget.onEdit,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: const Icon(
                              Icons.edit_outlined,
                              color: Colors.white54,
                              size: 15,
                            ),
                          ),
                        ),
                      if (widget.onEdit != null) const SizedBox(width: 6),
                      GestureDetector(
                        onTap: widget.onDelete,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                            size: 15,
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
    );
  }
}
