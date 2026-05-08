import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartFile {
  final String name;
  final Uint8List bytes;
  const CartFile({required this.name, required this.bytes});
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
  String get sizeLabel  => hasSizeInput ? '${widthFt}ft × ${heightFt}ft' : '';

  double get subtotal {
    if (hasSizeInput) return unitPrice * widthFt! * heightFt! * quantity;
    return unitPrice * quantity;
  }

  // ── Turnaround ─────────────────────────────────────────────────────────────

  // Returns turnaround in fractional days (0.5 = same day / half-day).
  double get estimatedDaysExact {
    final cat = category.toLowerCase();
    double d;

    if (cat.contains('calling card')) {
      // Batch cards — very fast
      if (quantity <= 100) d = 0.5;
      else if (quantity <= 500) d = 1.0;
      else d = (quantity / 500).ceilToDouble().clamp(2.0, 7.0);
    } else if (cat.contains('sticker') || cat.contains('photo')) {
      if (quantity <= 50)  d = 0.5;
      else if (quantity <= 200) d = 1.0;
      else d = (quantity / 200).ceilToDouble().clamp(2.0, 5.0);
    } else if (cat.contains('large format')) {
      final area = hasSizeInput ? widthFt! * heightFt! : 4.0;
      if (area <= 6)       d = 0.5;   // e.g. 2×3 ft — same day
      else if (area <= 15) d = 1.0;   // medium banner
      else if (area <= 30) d = 1.5;   // large banner
      else                 d = 2.0;   // very large / multiple panels
      // Scale for quantity — each additional piece adds proportional time
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

  // Integer days for Firestore / queue scheduling (minimum 1).
  int get estimatedDays => estimatedDaysExact.ceil().clamp(1, 21);

  // Human-readable label, allows sub-day display.
  String get estimatedDaysLabel {
    final d = estimatedDaysExact;
    if (d <= 0.5) return 'Same day';
    if (d <  1.0) return '< 1 day';
    if (d == 1.0) return '~1 day';
    if (d <= 1.5) return '~1–2 days';
    if (d <= 2.0) return '~2 days';
    return '~${d.ceil()} days';
  }

  // ── JSON (no files — files can't be persisted in local storage) ───────────

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
    files:       [], // files are not persisted; user must re-attach
    notes:       j['notes'] as String,
  );
}

// ── CartManager ───────────────────────────────────────────────────────────────

class CartManager {
  static const _kKey = 'imprenta_cart_v1';

  static final List<CartItem> _items = [];
  static final ValueNotifier<int> count = ValueNotifier(0);

  // Cached after loadSaved() — avoids async getInstance() on every write.
  // On Flutter web, SharedPreferences.setString() writes to window.localStorage
  // synchronously once the instance is cached, so the write survives a page
  // refresh even if the returned Future is never awaited.
  static SharedPreferences? _prefs;

  static List<CartItem> get items => List.unmodifiable(_items);

  static void add(CartItem item) {
    _items.add(item);
    count.value = _items.length;
    _persistNow();
  }

  static void removeAt(int index) {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    count.value = _items.length;
    _persistNow();
  }

  static void updateAt(int index, CartItem item) {
    if (index < 0 || index >= _items.length) return;
    _items[index] = item;
    count.value = _items.length;
    _persistNow();
  }

  static void removeIndices(List<int> indices) {
    final sorted = [...indices]..sort((a, b) => b.compareTo(a));
    for (final i in sorted) {
      if (i >= 0 && i < _items.length) _items.removeAt(i);
    }
    count.value = _items.length;
    _persistNow();
  }

  static void clear() {
    _items.clear();
    count.value = 0;
    _persistNow();
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  static void _persistNow() {
    final encoded = jsonEncode(_items.map((i) => i.toJson()).toList());
    final p = _prefs;
    if (p != null) {
      // Fast path: cached instance → on web this writes to localStorage
      // synchronously before the returned Future even resolves.
      p.setString(_kKey, encoded);
    } else {
      // Prefs not ready yet (add called before loadSaved completed).
      SharedPreferences.getInstance().then((prefs) {
        _prefs = prefs;
        prefs.setString(_kKey, encoded);
      });
    }
  }

  /// Call once at app startup (after Firebase init) to restore saved cart.
  static Future<void> loadSaved() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs!.getString(_kKey);
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();
      _items.clear();
      _items.addAll(list.map(CartItem.fromJson));
      count.value = _items.length;
    } catch (e) {
      debugPrint('CartManager.loadSaved: $e');
    }
  }
}
