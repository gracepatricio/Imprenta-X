import 'dart:typed_data';
import 'package:flutter/foundation.dart';

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
}

class CartManager {
  static final List<CartItem> _items = [];
  static final ValueNotifier<int> count = ValueNotifier(0);

  static List<CartItem> get items => List.unmodifiable(_items);

  static void add(CartItem item) {
    _items.add(item);
    count.value = _items.length;
  }

  static void removeAt(int index) {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    count.value = _items.length;
  }

  static void removeIndices(List<int> indices) {
    final sorted = [...indices]..sort((a, b) => b.compareTo(a));
    for (final i in sorted) {
      if (i >= 0 && i < _items.length) _items.removeAt(i);
    }
    count.value = _items.length;
  }

  static void clear() {
    _items.clear();
    count.value = 0;
  }
}
