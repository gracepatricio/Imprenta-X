import 'package:cloud_firestore/cloud_firestore.dart';

/// Turnaround-time estimation for Imprenta X.
///
/// Priority order for a given product:
///   1. Explicit admin config  (`turnaround_config` map on the product doc)
///   2. Smart default by `pricing_unit`  (works for any future product)
///   3. Legacy category/name heuristic   (backward compat for old products)
///
/// Queue awareness: [fetchActiveJobCount] queries live pending+in-production
/// jobs. [queueBuffer] converts that count into extra days to surface to the
/// customer as a workload buffer.
class TurnaroundService {
  // ── Queue awareness ───────────────────────────────────────────────────────

  /// Fetches count of currently active jobs (pending + in_production).
  static Future<int> fetchActiveJobCount() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('Order_Queue')
          .where('job_status', whereIn: ['pending', 'in_production'])
          .get();
      return snap.docs.length;
    } catch (_) {
      return 0;
    }
  }

  /// Extra buffer days to add based on current shop workload.
  ///   0–3 jobs  → +0 d  (light, no buffer)
  ///   4–8 jobs  → +0.5 d
  ///   9–15 jobs → +1 d
  ///  16–25 jobs → +1.5 d
  ///  25+ jobs   → +2 d
  static double queueBuffer(int activeJobCount) {
    if (activeJobCount <= 3)  return 0.0;
    if (activeJobCount <= 8)  return 0.5;
    if (activeJobCount <= 15) return 1.0;
    if (activeJobCount <= 25) return 1.5;
    return 2.0;
  }

  // ── Per-item estimate ─────────────────────────────────────────────────────

  /// Returns the raw (fractional) production days for a single line item.
  ///
  /// [productConfig] — the `turnaround_config` map from the Firestore product
  ///   doc.  Keys: `base_days` (num), `rate` (num), `max_days` (num).
  ///   When present and non-empty, the explicit formula is used.
  ///
  /// [pricingUnit] — `per_sqft`, `per_sqin`, `per_qty`, or `per_piece`.
  ///   Used by the smart-default path so any newly added product gets a
  ///   reasonable estimate even without an explicit config.
  static double perItemDays({
    required String category,
    required int qty,
    double? widthFt,
    double? heightFt,
    String? productName,
    String? pricingUnit,
    bool isOutsourced = false,
    Map<String, dynamic>? productConfig,
  }) {
    // ── 1. Explicit config ─────────────────────────────────────────────────
    if (productConfig != null) {
      final base = (productConfig['base_days'] as num?)?.toDouble();
      final rate = (productConfig['rate'] as num?)?.toDouble();
      final max  = (productConfig['max_days'] as num?)?.toDouble() ?? 14.0;
      if (base != null) {
        return _formula(
          base: base,
          rate: rate ?? 0.0,
          maxDays: max,
          pricingUnit: pricingUnit ?? '',
          qty: qty,
          widthFt: widthFt,
          heightFt: heightFt,
        );
      }
    }

    // ── 2. Smart default by pricing unit ──────────────────────────────────
    final unit = pricingUnit?.trim() ?? '';
    if (unit == 'per_sqft') {
      return _smartSqft(qty: qty, widthFt: widthFt, heightFt: heightFt);
    }
    if (unit == 'per_sqin') {
      return _smartSqin(qty: qty, widthFt: widthFt, heightFt: heightFt);
    }
    if (unit == 'per_qty') {
      return _smartBatch(qty: qty, isOutsourced: isOutsourced);
    }
    if (unit == 'per_piece') {
      return _smartPiece(
          qty: qty, productName: productName ?? '', category: category);
    }

    // ── 3. Legacy category/name heuristic (full backward compat) ──────────
    return _legacyHeuristic(
      category: category,
      qty: qty,
      widthFt: widthFt,
      heightFt: heightFt,
      productName: productName ?? '',
      isOutsourced: isOutsourced,
    );
  }

  // ── Formula (explicit admin config) ──────────────────────────────────────

  static double _formula({
    required double base,
    required double rate,
    required double maxDays,
    required String pricingUnit,
    required int qty,
    double? widthFt,
    double? heightFt,
  }) {
    if (rate <= 0) return base.clamp(0.5, maxDays);
    double units;
    if (pricingUnit == 'per_sqft') {
      // rate = days per sq ft ordered
      units = (widthFt ?? 1.0) * (heightFt ?? 1.0) * qty;
    } else if (pricingUnit == 'per_sqin') {
      // rate = days per sq in ordered
      units = (widthFt ?? (4 / 12.0)) * (heightFt ?? (4 / 12.0)) * 144 * qty;
    } else {
      // per_piece / per_qty: rate = days per piece ordered
      units = qty.toDouble();
    }
    return (base + units * rate).clamp(base, maxDays);
  }

  // ── Smart defaults by pricing unit ───────────────────────────────────────

  /// Large-format / tarpaulin: area then qty drive days.
  static double _smartSqft(
      {required int qty, double? widthFt, double? heightFt}) {
    final area = (widthFt ?? 3.0) * (heightFt ?? 3.0);
    double base;
    if (area <= 6)        base = 0.5;
    else if (area <= 15)  base = 1.0;
    else if (area <= 30)  base = 1.5;
    else                  base = 2.0;
    if (qty > 1) base = (base * qty).clamp(base, 14.0);
    return base.clamp(0.5, 14.0);
  }

  /// Photo-size / sq-in items (stickers, photo prints).
  static double _smartSqin(
      {required int qty, double? widthFt, double? heightFt}) {
    final areaSqin =
        (widthFt ?? (4 / 12.0)) * (heightFt ?? (4 / 12.0)) * 144;
    double base;
    if (areaSqin <= 24)   base = 0.5; // ≤ ~4×6 in
    else if (areaSqin <= 80) base = 1.0; // up to ~8×10 in
    else                  base = 1.5;
    if (qty > 10) base = (base + (qty / 50) * 0.5).clamp(base, 5.0);
    return base.clamp(0.5, 7.0);
  }

  /// Batch-priced items (calling cards, tickets, etc. — qty = # of batches).
  static double _smartBatch({required int qty, required bool isOutsourced}) {
    if (isOutsourced) return 4.0;
    if (qty <= 1)  return 1.0;
    if (qty <= 10) return 2.0;
    return (2.0 + (qty - 10) * 0.25).clamp(2.0, 7.0);
  }

  /// Per-piece items (invitations, IDs, menus, etc.).
  static double _smartPiece(
      {required int qty,
      required String productName,
      required String category}) {
    final name = productName.toLowerCase();
    final cat  = category.toLowerCase();
    if (name.contains('invitation') ||
        name.contains('invite') ||
        cat.contains('invitation')) {
      if (qty <= 30)  return 1.5;
      if (qty <= 200) return 2.5;
      return 3.5;
    }
    if (name.contains('id') || name.contains('pvc')) {
      return qty <= 20 ? 1.0 : 2.0;
    }
    // Generic per-piece: ~0.5 day per 50 pieces, capped at 7 days.
    return (0.5 + (qty / 50).ceilToDouble() * 0.5).clamp(0.5, 7.0);
  }

  // ── Legacy heuristic (unchanged, backward compat) ─────────────────────────

  static double _legacyHeuristic({
    required String category,
    required int qty,
    required String productName,
    double? widthFt,
    double? heightFt,
    bool isOutsourced = false,
  }) {
    final cat  = category.toLowerCase().trim();
    final name = productName.toLowerCase().trim();
    double d;

    if (cat.contains('large format') || cat.contains('signage')) {
      if (name.contains('x-banner') ||
          name.contains('x banner') ||
          name.contains('roll-up') ||
          name.contains('roll up')) {
        if (qty <= 2)        d = 0.5;
        else if (qty <= 10)  d = 1.0;
        else if (qty <= 30)  d = 1.5;
        else                 d = 2.0;
        return d.clamp(0.5, 21.0);
      }
      final area = (widthFt != null && heightFt != null)
          ? widthFt * heightFt
          : 9.0;
      if (area <= 6)        d = 0.5;
      else if (area <= 15)  d = 1.0;
      else if (area <= 30)  d = 1.5;
      else                  d = 2.0;
      if (qty > 1) d = (d * qty).clamp(d, 14.0);
    } else if (cat.contains('photo') || cat.contains('card')) {
      if (name.contains('invitation') || name.contains('invite')) {
        if (qty <= 30)  d = 1.5;
        else if (qty <= 200) d = 2.5;
        else            d = 3.5;
      } else if (name.contains('id') || name.contains('pvc')) {
        d = qty <= 20 ? 1.0 : 2.0;
      } else if (name.contains('calling card')) {
        if (isOutsourced) {
          d = 4.0;
        } else {
          final boxes = (qty / 100).ceilToDouble();
          if (boxes <= 1)        d = 1.0;
          else if (boxes <= 10)  d = 2.0;
          else d = (2.0 + (boxes - 10) * 0.25).clamp(2.0, 7.0);
        }
      } else {
        if (qty <= 50)  d = 0.5;
        else if (qty <= 200) d = 1.0;
        else            d = 2.0;
      }
    } else if (cat.contains('sticker') || cat.contains('label')) {
      if (name.contains('sintra')) {
        if (qty <= 20)  d = 1.0;
        else if (qty <= 100) d = 2.0;
        else            d = 3.0;
      } else {
        if (qty <= 50)  d = 0.5;
        else if (qty <= 200) d = 1.0;
        else d = (qty / 200).ceilToDouble().clamp(2.0, 5.0);
      }
    } else {
      d = 1.0;
    }

    return d.clamp(0.5, 21.0);
  }

  // ── Order total ───────────────────────────────────────────────────────────

  /// Computes the integer days for a whole order (multiple line items).
  ///
  /// [products] — each map should have: `category`, `name`, `qty`,
  ///   optionally `width_ft`, `height_ft`, `is_outsourced`, `pricing_unit`,
  ///   `turnaround_config`.
  ///
  /// [extraBufferDays] — queue buffer from [queueBuffer]; callers are
  ///   responsible for fetching this asynchronously via [fetchActiveJobCount].
  static int computeOrderDays(
    List<Map<String, dynamic>> products, {
    double extraBufferDays = 0,
  }) {
    if (products.isEmpty) return 1;

    final groupCounts = <String, int>{};
    double totalItemDays = 0.0;

    for (final p in products) {
      final category    = p['category']?.toString() ?? '';
      final name        = p['name']?.toString() ?? '';
      final qty         = (p['qty'] as num?)?.toInt() ?? 1;
      final widthFt     = (p['width_ft'] as num?)?.toDouble();
      final heightFt    = (p['height_ft'] as num?)?.toDouble();
      final outsourced  = (p['is_outsourced'] as bool?) ?? false;
      final pricingUnit = p['pricing_unit']?.toString();
      final config      = p['turnaround_config'] as Map<String, dynamic>?;

      totalItemDays += perItemDays(
        category:      category,
        productName:   name,
        qty:           qty,
        widthFt:       widthFt,
        heightFt:      heightFt,
        isOutsourced:  outsourced,
        pricingUnit:   pricingUnit,
        productConfig: config,
      );

      final g = _group(category.toLowerCase().trim());
      groupCounts[g] = (groupCounts[g] ?? 0) + 1;
    }

    // Cross-category setup overhead.
    final setupOverhead = (groupCounts.length - 1) * 0.5;
    // Coordination overhead for multi-item orders.
    final coordOverhead = (products.length - 1) * 0.25;
    // Batch discount when multiple items share the same print type.
    var batchDiscount = 0.0;
    for (final count in groupCounts.values) {
      if (count > 1) batchDiscount += (count - 1) * 0.15;
    }

    final raw = totalItemDays +
        setupOverhead +
        coordOverhead -
        batchDiscount +
        extraBufferDays;
    return raw.ceil().clamp(1, 30);
  }

  static String _group(String cat) {
    if (cat.contains('large format') || cat.contains('signage'))
      return 'large_format';
    if (cat.contains('photo') || cat.contains('card')) return 'photo_card';
    if (cat.contains('sticker') || cat.contains('label')) return 'sticker';
    return 'general';
  }

  // ── Human-readable label ──────────────────────────────────────────────────

  static String label(double days) {
    if (days <= 0.5) return 'Same day';
    if (days < 1.0)  return '< 1 day';
    if (days == 1.0) return '~1 day';
    if (days <= 1.5) return '~1–2 days';
    if (days <= 2.0) return '~2 days';
    return '~${days.ceil()} days';
  }

  /// Range label when there is a workload buffer on top of the base estimate.
  static String rangeLabel(double baseDays, double bufferDays) {
    if (bufferDays <= 0) return label(baseDays);
    final maxDays = baseDays + bufferDays;
    if (label(baseDays) == label(maxDays)) return label(baseDays);
    return '${label(baseDays)} – ${label(maxDays)}';
  }
}
