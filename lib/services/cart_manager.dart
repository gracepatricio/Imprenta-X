import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CartFile {
  final String name;
  final Uint8List? bytes; // null when loaded from Firestore (only url/path available)
  final String? url;
  final String? path;
  const CartFile({required this.name, this.bytes, this.url, this.path});
}

class CartItem {
  final String productId;
  final String productName;
  final String category;
  final String imageUrl;
  final double unitPrice;
  final String pricingUnit;
  final int quantity;
  final double? widthFt;
  final double? heightFt;
  final String? material;
  final List<CartFile> files;
  final String notes;

  const CartItem({
    required this.productId,
    required this.productName,
    required this.category,
    required this.imageUrl,
    required this.unitPrice,
    required this.pricingUnit,
    required this.quantity,
    this.widthFt,
    this.heightFt,
    this.material,
    required this.files,
    required this.notes,
  });

  bool get hasSizeInput => widthFt != null && heightFt != null;
  String get sizeLabel  => hasSizeInput ? '${widthFt}ft x ${heightFt}ft' : '';

  double get subtotal {
    if (hasSizeInput) return unitPrice * widthFt! * heightFt! * quantity;
    return unitPrice * quantity;
  }

  double get estimatedDaysExact {
    final cat = category.toLowerCase();
    double d;
    if (cat.contains('calling card')) {
      if (quantity <= 100) d = 0.5;
      else if (quantity <= 500) d = 1.0;
      else d = (quantity / 500).ceilToDouble().clamp(2.0, 7.0);
    } else if (cat.contains('sticker') || cat.contains('photo')) {
      if (quantity <= 50)  d = 0.5;
      else if (quantity <= 200) d = 1.0;
      else d = (quantity / 200).ceilToDouble().clamp(2.0, 5.0);
    } else if (cat.contains('large format')) {
      final area = hasSizeInput ? widthFt! * heightFt! : 4.0;
      if (area <= 6)       d = 0.5;
      else if (area <= 15) d = 1.0;
      else if (area <= 30) d = 1.5;
      else                 d = 2.0;
      if (quantity > 1) d = (d * quantity).clamp(d, 14.0);
    } else if (cat.contains('invitation')) {
      if (quantity <= 50)  d = 1.0;
      else if (quantity <= 200) d = 2.0;
      else d = 3.0;
    } else if (cat.contains('menu') || cat.contains('board')) {
      d = quantity.toDouble().clamp(1.0, 3.0);
    } else {
      d = 1.0;
    }
    return d.clamp(0.5, 21.0);
  }

  int get estimatedDays => estimatedDaysExact.ceil().clamp(1, 21);

  String get estimatedDaysLabel {
    final d = estimatedDaysExact;
    if (d <= 0.5) return 'Same day';
    if (d <  1.0) return '< 1 day';
    if (d == 1.0) return '~1 day';
    if (d <= 1.5) return '~1-2 days';
    if (d <= 2.0) return '~2 days';
    return '~${d.ceil()} days';
  }

  Map<String, dynamic> toJson() => {
    'productId':   productId,
    'productName': productName,
    'category':    category,
    'imageUrl':    imageUrl,
    'unitPrice':   unitPrice,
    'pricingUnit': pricingUnit,
    'quantity':    quantity,
    if (widthFt  != null) 'widthFt':  widthFt,
    if (heightFt != null) 'heightFt': heightFt,
    if (material != null) 'material': material,
    'notes': notes,
    'fileData': files.map((f) => {
      'name': f.name,
      if (f.url  != null) 'url':  f.url,
      if (f.path != null) 'path': f.path,
    }).toList(),
  };

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
    productId:   j['productId']   as String,
    productName: j['productName'] as String,
    category:    j['category']    as String,
    imageUrl:    j['imageUrl']    as String,
    unitPrice:   (j['unitPrice']  as num).toDouble(),
    pricingUnit: j['pricingUnit'] as String,
    quantity:    j['quantity']    as int,
    widthFt:     j['widthFt']  != null ? (j['widthFt']  as num).toDouble() : null,
    heightFt:    j['heightFt'] != null ? (j['heightFt'] as num).toDouble() : null,
    material:    j['material'] as String?,
    files: (() {
      final raw = j['fileData'] as List?;
      if (raw == null) return <CartFile>[];
      return raw.whereType<Map>().map((fd) => CartFile(
        name: fd['name'] as String? ?? '',
        url:  fd['url']  as String?,
        path: fd['path'] as String?,
      )).toList();
    })(),
    notes:       j['notes'] as String,
  );
}

// ── CartManager ───────────────────────────────────────────────────────────────
//
// Uses Firestore (Carts/{uid}) instead of SharedPreferences.
// Survives app reinstalls, cache clears, and device switches.

class CartManager {
  static final List<CartItem> _items = [];
  static final ValueNotifier<int> count = ValueNotifier(0);
  static String? _uid;

  static List<CartItem> get items => List.unmodifiable(_items);

  static void add(CartItem item) {
    _items.add(item);
    count.value = _items.length;
    _scheduleSave();
  }

  static void removeAt(int index) {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    count.value = _items.length;
    _scheduleSave();
  }

  static void updateAt(int index, CartItem item) {
    if (index < 0 || index >= _items.length) return;
    _items[index] = item;
    count.value = _items.length;
    _scheduleSave();
  }

  static void removeIndices(List<int> indices) {
    final sorted = [...indices]..sort((a, b) => b.compareTo(a));
    for (final i in sorted) {
      if (i >= 0 && i < _items.length) _items.removeAt(i);
    }
    count.value = _items.length;
    _scheduleSave();
  }

  static void clear() {
    _items.clear();
    count.value = 0;
    _scheduleSave();
  }

  /// Call after successful login to restore the user's cart from Firestore.
  static Future<void> loadForUser(String uid) async {
    _uid = uid;
    _items.clear();
    count.value = 0;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Carts')
          .doc(uid)
          .get();
      if (!doc.exists) return;
      final raw = doc.data()?['items'];
      if (raw == null || raw is! List) return;
      _items.addAll(
        (raw as List)
            .whereType<Map<String, dynamic>>()
            .map(CartItem.fromJson),
      );
      count.value = _items.length;
    } catch (e) {
      debugPrint('CartManager.loadForUser: $e');
    }
  }

  /// Call on sign-out to wipe in-memory state.
  static void unloadUser() {
    _uid = null;
    _items.clear();
    count.value = 0;
    _saveScheduled = false;
  }

  // ── Debounced Firestore write ──────────────────────────────────────────────

  static bool _saveScheduled = false;

  static void _scheduleSave() {
    if (_uid == null) return;
    if (_saveScheduled) return;
    _saveScheduled = true;
    Future.delayed(const Duration(milliseconds: 300), _flushSave);
  }

  static Future<void> _flushSave() async {
    _saveScheduled = false;
    final uid = _uid;
    if (uid == null) return;
    final payload = _items.map((i) => i.toJson()).toList();
    try {
      await FirebaseFirestore.instance
          .collection('Carts')
          .doc(uid)
          .set({'items': payload});
    } catch (e) {
      debugPrint('CartManager._flushSave: $e');
    }
  }

  // Kept so main.dart compiles without changes — does nothing now.
  @Deprecated('Use loadForUser(uid) after login.')
  static Future<void> loadSaved() async {}
}