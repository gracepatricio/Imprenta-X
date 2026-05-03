import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import '../services/cart_manager.dart';
import 'app_theme.dart';

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

  // ── Compression ───────────────────────────────────────────────────────────────

  Uint8List _compress(Uint8List bytes, String ext) {
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

  // ── Checkout ──────────────────────────────────────────────────────────────────

  Future<String> _nextOrderId() async {
    final ref = FirebaseFirestore.instance.collection('Counters').doc('order');
    return FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final next = ((snap.data()?['last_id'] as int?) ?? 0) + 1;
      tx.set(ref, {'last_id': next});
      return 'ORD-${next.toString().padLeft(4, '0')}';
    });
  }

  Future<({List<String> urls, List<String> paths})> _uploadFiles(
      String orderId, int itemIndex, CartItem item) async {
    final urls  = <String>[];
    final paths = <String>[];
    for (final file in item.files) {
      final ext   = file.name.split('.').last.toLowerCase();
      final bytes = _compress(file.bytes, ext);
      final ts    = DateTime.now().millisecondsSinceEpoch;
      final path  = 'order_files/$orderId/${itemIndex}_${ts}_${file.name}';
      final ref   = FirebaseStorage.instance.ref(path);
      final task  = await ref.putData(
          bytes, SettableMetadata(contentType: _mime(ext)));
      urls.add(await task.ref.getDownloadURL());
      paths.add(path);
    }
    return (urls: urls, paths: paths);
  }

  Future<void> _checkout() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one item to checkout.')),
      );
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _checkingOut = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('User').doc(user.uid).get();
      final customerName  = userDoc.data()?['full_name']  ?? '';
      final customerEmail = userDoc.data()?['email']      ?? user.email ?? '';

      final orderId    = await _nextOrderId();
      final items      = CartManager.items;
      final selectedList = _selected.toList()..sort();
      final products   = <Map<String, dynamic>>[];

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

      await FirebaseFirestore.instance.collection('Orders').doc(orderId).set({
        'order_id':           orderId,
        'customer_uid':       user.uid,
        'customer_name':      customerName,
        'customer_email':     customerEmail,
        'status':             'pending',
        'products':           products,
        'shipping':           'pickup',
        'total_price':        _subtotal,
        'turnaround':         '2-3 days',
        'has_review':         false,
        'created_at':         FieldValue.serverTimestamp(),
      });

      // Ensure single chat thread exists for this customer
      await FirebaseFirestore.instance
          .collection('Messages')
          .doc('chat_${user.uid}')
          .set({
        'customer_uid':    user.uid,
        'customer_name':   customerName,
        'last_message':    'New order placed: $orderId',
        'last_updated':    FieldValue.serverTimestamp(),
        'unread_customer': 0,
        'unread_employee': FieldValue.increment(1),
      }, SetOptions(merge: true));

      CartManager.removeIndices(selectedList);

      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text('$orderId placed! We\'ll start processing soon.'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 4),
        ));
        widget.onOrderPlaced?.call();
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Checkout failed: $e'),
        backgroundColor: Colors.red.shade700,
      ));
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.gold.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                        '${items.length} item${items.length != 1 ? 's' : ''}',
                        style: const TextStyle(
                            color: AppTheme.gold, fontSize: 11)),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _selected.length == items.length &&
                            items.isNotEmpty,
                        tristate: _selected.isNotEmpty &&
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
                      ),
                      const Text('All',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 12)),
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
                      if (s < i)     newSelected.add(s);
                      else if (s > i) newSelected.add(s - 1);
                    }
                    _selected
                      ..clear()
                      ..addAll(newSelected);
                    CartManager.removeAt(i);
                  }),
                ),
              ),
            ),

            // ── Summary + checkout ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                border: Border(
                    top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1))),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                            '${_selected.length} of ${items.length} selected',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
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
                            : _checkout,
                        style: AppTheme.primaryButton(),
                        child: _checkingOut
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.black))
                            : const Text('Place Order',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
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
        Icon(Icons.shopping_cart_outlined,
            size: 56, color: Colors.white24),
        SizedBox(height: 16),
        Text('Your cart is empty',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        SizedBox(height: 6),
        Text('Browse products and add items to your cart',
            style: TextStyle(color: Colors.white38, fontSize: 13),
            textAlign: TextAlign.center),
      ],
    ),
  );
}

// ── Cart item tile ────────────────────────────────────────────────────────────

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final int index;
  final bool isSelected;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  const _CartItemTile({
    required this.item,
    required this.index,
    required this.isSelected,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.glassCard(
          opacity: isSelected ? 0.18 : 0.09, radius: 14),
      child: Row(
        children: [
          Checkbox(
            value: isSelected,
            onChanged: (v) => onToggle(v ?? false),
            activeColor: AppTheme.gold,
            checkColor: Colors.black,
            side: const BorderSide(color: Colors.white38),
          ),
          // Thumbnail
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white.withValues(alpha: 0.08),
            ),
            clipBehavior: Clip.antiAlias,
            child: item.imageUrl.isNotEmpty
                ? Image.network(item.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.image_outlined,
                        color: Colors.white24, size: 22))
                : const Icon(Icons.image_outlined,
                    color: Colors.white24, size: 22),
          ),
          const SizedBox(width: 10),
          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
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
                  if (item.files.isNotEmpty)
                    Text(
                        '${item.files.length} file${item.files.length != 1 ? 's' : ''} attached',
                        style: const TextStyle(
                            color: AppTheme.gold, fontSize: 10)),
                ],
              ),
            ),
          ),
          // Price + delete
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('₱${item.subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: AppTheme.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.delete_outline,
                      color: Colors.redAccent, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
