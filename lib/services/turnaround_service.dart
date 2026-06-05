class TurnaroundService {
  static double perItemDays({
    required String category,
    required int qty,
    double? widthFt,
    double? heightFt,
    String? productName,
    bool isOutsourced = false,
  }) {
    final cat = category.toLowerCase().trim();
    final name = (productName ?? '').toLowerCase().trim();
    double d;

    // ── Large Format & Signage ─────────────────────────────────────────────
    if (cat.contains('large format') || cat.contains('signage')) {
      // Fixed-size standalones: qty is the main driver
      if (name.contains('x-banner') ||
          name.contains('x banner') ||
          name.contains('roll-up') ||
          name.contains('roll up')) {
        if (qty <= 2)
          d = 0.5;
        else if (qty <= 10)
          d = 1.0;
        else if (qty <= 30)
          d = 1.5;
        else
          d = 2.0;
        return d.clamp(0.5, 21.0);
      }

      // Area-based: tarpaulin, panaflex, etc.
      final area = (widthFt != null && heightFt != null)
          ? widthFt * heightFt
          : 9.0; // default 3×3 ft

      if (area <= 6)
        d = 0.5;
      else if (area <= 15)
        d = 1.0;
      else if (area <= 30)
        d = 1.5;
      else
        d = 2.0;

      if (qty > 1) d = (d * qty).clamp(d, 14.0);
    }
    // ── Photo & Card Prints ────────────────────────────────────────────────
    else if (cat.contains('photo') || cat.contains('card')) {
      // Invitations need a proof approval buffer
      if (name.contains('invitation') || name.contains('invite')) {
        if (qty <= 30)
          d = 1.5;
        else if (qty <= 200)
          d = 2.5;
        else
          d = 3.5;
      }
      // ID packages / PVC IDs
      else if (name.contains('id') || name.contains('pvc')) {
        d = qty <= 20 ? 1.0 : 2.0;
      }
      // Calling cards
      else if (name.contains('calling card')) {
        if (isOutsourced) {
          d = 4.0;
        } else {
          final boxes = (qty / 100).ceilToDouble();
          if (boxes <= 1)
            d = 1.0;
          else if (boxes <= 10)
            d = 2.0;
          else
            d = (2.0 + (boxes - 10) * 0.25).clamp(2.0, 7.0);
        }
      }
      // Standard photo prints
      else {
        if (qty <= 50)
          d = 0.5;
        else if (qty <= 200)
          d = 1.0;
        else
          d = 2.0;
      }
    }
    // ── Stickers & Labels ──────────────────────────────────────────────────
    else if (cat.contains('sticker') || cat.contains('label')) {
      final hasSintra = name.contains('sintra');
      if (hasSintra) {
        if (qty <= 20)
          d = 1.0;
        else if (qty <= 100)
          d = 2.0;
        else
          d = 3.0;
      } else {
        if (qty <= 50)
          d = 0.5;
        else if (qty <= 200)
          d = 1.0;
        else
          d = (qty / 200).ceilToDouble().clamp(2.0, 5.0);
      }
    }
    // ── Fallback ───────────────────────────────────────────────────────────
    else {
      d = 1.0;
    }

    return d.clamp(0.5, 21.0);
  }

  static int computeOrderDays(List<Map<String, dynamic>> products) {
    if (products.isEmpty) return 1;

    final groupCounts = <String, int>{};
    double totalItemDays = 0.0;

    for (final p in products) {
      final category = p['category']?.toString() ?? '';
      final name = p['name']?.toString() ?? '';
      final qty = (p['qty'] as num?)?.toInt() ?? 1;
      final widthFt = (p['width_ft'] as num?)?.toDouble();
      final heightFt = (p['height_ft'] as num?)?.toDouble();
      final outsourced = (p['is_outsourced'] as bool?) ?? false;

      totalItemDays += perItemDays(
        category: category,
        productName: name, // ← now passed through
        qty: qty,
        widthFt: widthFt,
        heightFt: heightFt,
        isOutsourced: outsourced,
      );

      final g = _group(category.toLowerCase().trim());
      groupCounts[g] = (groupCounts[g] ?? 0) + 1;
    }

    final setupOverhead = (groupCounts.length - 1) * 0.5;
    final coordOverhead = (products.length - 1) * 0.25;

    var batchDiscount = 0.0;
    for (final count in groupCounts.values) {
      if (count > 1) batchDiscount += (count - 1) * 0.15;
    }

    final raw = totalItemDays + setupOverhead + coordOverhead - batchDiscount;
    return raw.ceil().clamp(1, 30);
  }

  static String _group(String cat) {
    if (cat.contains('large format') || cat.contains('signage'))
      return 'large_format';
    if (cat.contains('photo') || cat.contains('card')) return 'photo_card';
    if (cat.contains('sticker') || cat.contains('label')) return 'sticker';
    return 'general';
  }
}
