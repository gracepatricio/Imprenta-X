/// Turnaround time calculation — single source of truth for the whole app.
///
/// Two public APIs:
///   perItemDays(...)       — per-item contribution (for individual line display)
///   computeOrderDays([])   — full order (adds multi-product complexity factors)
class TurnaroundService {

  // ── Per-item base days ────────────────────────────────────────────────────
  // category, qty, and optional size for large-format items.
  static double perItemDays({
    required String category,
    required int    qty,
    double? widthFt,
    double? heightFt,
  }) {
    final cat = category.toLowerCase();
    double d;

    if (cat.contains('calling card')) {
      if (qty <= 100)      d = 0.5;
      else if (qty <= 500) d = 1.0;
      else                 d = (qty / 500).ceilToDouble().clamp(2.0, 7.0);
    } else if (cat.contains('sticker') || cat.contains('photo')) {
      if (qty <= 50)       d = 0.5;
      else if (qty <= 200) d = 1.0;
      else                 d = (qty / 200).ceilToDouble().clamp(2.0, 5.0);
    } else if (cat.contains('large format')) {
      final area = (widthFt != null && heightFt != null) ? widthFt * heightFt : 4.0;
      if (area <= 6)       d = 0.5;
      else if (area <= 15) d = 1.0;
      else if (area <= 30) d = 1.5;
      else                 d = 2.0;
      if (qty > 1)         d = (d * qty).clamp(d, 14.0);
    } else if (cat.contains('invitation')) {
      d = qty <= 50 ? 1.0 : (qty <= 200 ? 2.0 : 3.0);
    } else if (cat.contains('menu') || cat.contains('board')) {
      d = qty.toDouble().clamp(1.0, 3.0);
    } else {
      d = 1.0;
    }

    return d.clamp(0.5, 21.0);
  }

  // ── Full-order computation ────────────────────────────────────────────────
  // [products] is the Firestore products array — each entry needs:
  //   'category' (String), 'qty' (num), optionally 'width_ft'/'height_ft' (num).
  //
  // Beyond raw per-item time, the following real-world overhead is added:
  //   • Machine-setup overhead — each additional unique category requires
  //     a separate press/printer setup and file preparation (+0.5 day each).
  //   • Coordination overhead — each additional line item means separate
  //     file proofing, client sign-off, and order splitting (+0.25 day each).
  //   • Batching discount — items sharing the same machine/process can be
  //     queued together, saving some time (−0.15 day per extra same-cat item).
  static int computeOrderDays(List<Map<String, dynamic>> products) {
    if (products.isEmpty) return 1;

    final categoryGroups = <String, int>{}; // group → item count
    double totalItemDays = 0.0;

    for (final p in products) {
      final category = p['category']?.toString() ?? '';
      final qty      = (p['qty'] as num?)?.toInt() ?? 1;
      final widthFt  = (p['width_ft']  as num?)?.toDouble();
      final heightFt = (p['height_ft'] as num?)?.toDouble();

      totalItemDays += perItemDays(
        category: category, qty: qty, widthFt: widthFt, heightFt: heightFt,
      );

      final g = _group(category.toLowerCase());
      categoryGroups[g] = (categoryGroups[g] ?? 0) + 1;
    }

    // Each additional unique machine/process type = +0.5 day setup
    final setupOverhead = (categoryGroups.length - 1) * 0.5;

    // Each additional line item = +0.25 day coordination
    final coordOverhead = (products.length - 1) * 0.25;

    // Batching saves time when multiple items share the same process
    var batchDiscount = 0.0;
    for (final count in categoryGroups.values) {
      if (count > 1) batchDiscount += (count - 1) * 0.15;
    }

    final raw = totalItemDays + setupOverhead + coordOverhead - batchDiscount;
    return raw.ceil().clamp(1, 30);
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  static String _group(String cat) {
    if (cat.contains('calling card'))                      return 'calling_card';
    if (cat.contains('sticker') || cat.contains('photo')) return 'sticker_photo';
    if (cat.contains('large format'))                     return 'large_format';
    if (cat.contains('invitation'))                        return 'invitation';
    if (cat.contains('menu') || cat.contains('board'))    return 'menu_board';
    return 'general';
  }
}
