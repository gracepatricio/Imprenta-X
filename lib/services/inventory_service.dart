import 'package:cloud_firestore/cloud_firestore.dart';

/// Handles all inventory stock changes triggered programmatically.
///
/// ## Stock lifecycle
///
/// 1. Order placed → [reserveForOrder] adds to [reserved_stock] per material.
///    Product [is_available] is recalculated using effective stock
///    (current_stock − reserved_stock).
/// 2. Job starts ("In Production") → [deductForOrder] subtracts from
///    [current_stock] AND from [reserved_stock] (the reservation is fulfilled).
/// 3. Order cancelled → [releaseReservationForOrder] subtracts from
///    [reserved_stock] (only if not yet deducted).
///
/// ## BOM quantity_per_unit convention
///
/// quantity_per_unit = how much raw material is consumed per 1 unit of
/// the order quantity.
///
///   - Tarpaulin (ordered in sqft): quantity_per_unit: 0.01
///     → 100 sqft ordered → deduct 0.01 × 100 = 1 roll
///   - Calling Card (ordered in pcs): quantity_per_unit: 0.02
///     → 50 pcs ordered → deduct 0.02 × 50 = 1 sintra sheet
class InventoryService {
  InventoryService._();

  static final _db = FirebaseFirestore.instance;

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Computes the effective order quantity for a single product map.
  /// Area products (have width_ft + height_ft) → sqft; piece products → qty.
  static double _effectiveQty(Map<String, dynamic> p) {
    final qty = (p['qty'] as num?)?.toDouble() ?? 1.0;
    final widthFt = (p['width_ft'] as num?)?.toDouble();
    final heightFt = (p['height_ft'] as num?)?.toDouble();
    return (widthFt != null && heightFt != null)
        ? widthFt * heightFt * qty
        : qty;
  }

  /// Resolves filtered BOM items for one product and computes material amounts.
  /// Returns a map of {materialDocId → totalAmount} for this product.
  static Future<Map<String, double>> _bomAmountsForProduct({
    required String productId,
    required double effectiveQty,
    String? selectedMaterial,
  }) async {
    final productDoc = await _db.collection('Products').doc(productId).get();
    if (!productDoc.exists) return {};

    final rawBom = List<Map<String, dynamic>>.from(
      ((productDoc.data()?['bill_of_materials'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map)),
    );

    String effectiveMaterial = selectedMaterial?.trim() ?? '';
    if (effectiveMaterial.isEmpty) {
      final matOpts = productDoc.data()?['material_options'] as List?;
      if (matOpts != null && matOpts.isNotEmpty) {
        effectiveMaterial = matOpts.first.toString().trim();
      }
    }
    final applyVariantFilter = effectiveMaterial.isNotEmpty;

    final bom = rawBom.where((item) {
      final opt = item['for_material_option']?.toString().trim() ?? '';
      if (opt.isEmpty) return true;
      if (!applyVariantFilter) return true;
      return opt == effectiveMaterial;
    }).toList();

    final result = <String, double>{};
    for (final item in bom) {
      final matId = item['material_id']?.toString() ?? '';
      if (matId.isEmpty) continue;
      final qtyPerUnit = (item['quantity_per_unit'] as num?)?.toDouble() ?? 1.0;
      result[matId] = (result[matId] ?? 0) + qtyPerUnit * effectiveQty;
    }
    return result;
  }

  /// Aggregates material amounts across all products in an order.
  /// Returns {materialDocId → totalAmountAcrossAllProducts}.
  static Future<Map<String, double>> _aggregateOrderMaterials(
    List<Map<String, dynamic>> products,
  ) async {
    final totals = <String, double>{};
    for (final p in products) {
      final productId = p['product_id']?.toString() ?? '';
      if (productId.isEmpty) continue;
      final amounts = await _bomAmountsForProduct(
        productId: productId,
        effectiveQty: _effectiveQty(p),
        selectedMaterial: p['material']?.toString(),
      );
      for (final entry in amounts.entries) {
        totals[entry.key] = (totals[entry.key] ?? 0) + entry.value;
      }
    }
    return totals;
  }

  // ── Reservation ──────────────────────────────────────────────────────────────

  /// Soft-reserves raw materials when an order is placed.
  ///
  /// Increments [reserved_stock] on each material in the BOM, then
  /// recalculates [is_available] for affected products using effective stock
  /// (current_stock − reserved_stock).
  ///
  /// Idempotent: skips if the order already has [bom_reserved: true].
  static Future<void> reserveForOrder({
    required String orderId,
    required List<Map<String, dynamic>> products,
  }) async {
    final orderDoc = await _db.collection('Orders').doc(orderId).get();
    if (orderDoc.data()?['bom_reserved'] == true) return;

    final totals = await _aggregateOrderMaterials(products);
    if (totals.isEmpty) return;

    final matIds = totals.keys.toList();

    await _db.runTransaction((tx) async {
      final refs = matIds.map((id) => _db.collection('RawMaterials').doc(id)).toList();
      final snaps = <DocumentSnapshot>[];
      for (final ref in refs) {
        snaps.add(await tx.get(ref));
      }

      for (var i = 0; i < matIds.length; i++) {
        if (!snaps[i].exists) continue;
        final amount = totals[matIds[i]]!;
        final matData = snaps[i].data() as Map<String, dynamic>? ?? {};
        final prev = (matData['reserved_stock'] as num?)?.toDouble() ?? 0.0;
        tx.update(refs[i], {'reserved_stock': prev + amount});
      }
    });

    await _db.collection('Orders').doc(orderId).update({'bom_reserved': true});
    await _refreshProductsUsingMaterials(matIds);
  }

  /// Releases the soft-reservation when an order is cancelled.
  ///
  /// Decrements [reserved_stock] (floored at 0) on each material, then
  /// recalculates [is_available] for affected products.
  ///
  /// No-op if the order was never reserved or was already deducted.
  static Future<void> releaseReservationForOrder({
    required String orderId,
    required List<Map<String, dynamic>> products,
  }) async {
    final orderDoc = await _db.collection('Orders').doc(orderId).get();
    final wasReserved = orderDoc.data()?['bom_reserved'] == true;
    final alreadyDeducted = orderDoc.data()?['bom_deducted'] == true;
    if (!wasReserved || alreadyDeducted) return;

    final totals = await _aggregateOrderMaterials(products);
    if (totals.isEmpty) return;

    final matIds = totals.keys.toList();

    await _db.runTransaction((tx) async {
      final refs = matIds.map((id) => _db.collection('RawMaterials').doc(id)).toList();
      final snaps = <DocumentSnapshot>[];
      for (final ref in refs) {
        snaps.add(await tx.get(ref));
      }

      for (var i = 0; i < matIds.length; i++) {
        if (!snaps[i].exists) continue;
        final amount = totals[matIds[i]]!;
        final matData = snaps[i].data() as Map<String, dynamic>? ?? {};
        final prev = (matData['reserved_stock'] as num?)?.toDouble() ?? 0.0;
        tx.update(refs[i], {
          'reserved_stock': (prev - amount).clamp(0.0, double.infinity),
        });
      }
    });

    await _db.collection('Orders').doc(orderId).update({'bom_reserved': false});
    await _refreshProductsUsingMaterials(matIds);
  }

  // ── Order deduction ──────────────────────────────────────────────────────────

  /// Deducts raw materials from stock when a job moves to "In Production".
  ///
  /// Subtracts from [current_stock] and simultaneously releases the matching
  /// [reserved_stock] (the soft-reservation is fulfilled).
  ///
  /// [orderQuantity] must be in the same unit as the BOM (sqft for area
  /// products, pcs for piece products). [selectedMaterial] filters variant BOM
  /// items. Returns human-readable deduction lines.
  static Future<List<String>> deductForOrder({
    required String orderId,
    required String productId,
    required String productName,
    required double orderQuantity,
    required String processedByUid,
    required String processedByName,
    String? selectedMaterial,
  }) async {
    final productDoc = await _db.collection('Products').doc(productId).get();
    if (!productDoc.exists) {
      throw Exception('Product not found: $productId');
    }

    final rawBom = List<Map<String, dynamic>>.from(
      ((productDoc.data()?['bill_of_materials'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map)),
    );

    String effectiveMaterial = selectedMaterial?.trim() ?? '';
    if (effectiveMaterial.isEmpty) {
      final matOpts = productDoc.data()?['material_options'] as List?;
      if (matOpts != null && matOpts.isNotEmpty) {
        effectiveMaterial = matOpts.first.toString().trim();
      }
    }
    final bool applyVariantFilter = effectiveMaterial.isNotEmpty;

    final bom = rawBom.where((item) {
      final opt = item['for_material_option']?.toString().trim() ?? '';
      if (opt.isEmpty) return true;
      if (!applyVariantFilter) return true;
      return opt == effectiveMaterial;
    }).toList();

    if (bom.isEmpty) return [];

    final summaryLines = <String>[];

    await _db.runTransaction((tx) async {
      // ── reads ──
      final refs = <DocumentReference>[];
      final snaps = <DocumentSnapshot>[];

      for (final item in bom) {
        final matId = item['material_id']?.toString() ?? '';
        if (matId.isEmpty) continue;
        final ref = _db.collection('RawMaterials').doc(matId);
        refs.add(ref);
        snaps.add(await tx.get(ref));
      }

      // ── writes ──
      int refIdx = 0;
      for (final item in bom) {
        final matId = item['material_id']?.toString() ?? '';
        if (matId.isEmpty) continue;

        final snap = snaps[refIdx];
        final ref = refs[refIdx];
        refIdx++;

        if (!snap.exists) continue;

        final matData = snap.data() as Map<String, dynamic>? ?? {};
        final qtyPerUnit =
            (item['quantity_per_unit'] as num?)?.toDouble() ?? 1.0;
        final totalDeduction = qtyPerUnit * orderQuantity;

        final prevStock = (matData['current_stock'] as num?)?.toDouble() ?? 0.0;
        final newStock = prevStock - totalDeduction;

        // Release the matching portion of reserved_stock.
        final prevReserved =
            (matData['reserved_stock'] as num?)?.toDouble() ?? 0.0;
        final newReserved =
            (prevReserved - totalDeduction).clamp(0.0, double.infinity);

        tx.update(ref, {
          'current_stock': newStock,
          'reserved_stock': newReserved,
          'last_updated': FieldValue.serverTimestamp(),
          'last_updated_by': processedByName,
          'last_updated_by_uid': processedByUid,
        });

        final logRef = _db.collection('InventoryLogs').doc();
        tx.set(logRef, {
          'material_id': matId,
          'material_name': item['material_name']?.toString() ?? '',
          'quantity_added': -totalDeduction,
          'previous_stock': prevStock,
          'new_stock': newStock,
          'updated_by_uid': processedByUid,
          'updated_by_name': processedByName,
          'timestamp': FieldValue.serverTimestamp(),
          'update_method': 'order_deduction',
          'order_id': orderId,
          'product_name': productName,
        });

        final matName = item['material_name']?.toString() ??
            matData['material_name']?.toString() ??
            matId;
        final su = matData['unit_description']?.toString() ??
            matData['stocking_unit']?.toString() ??
            '';
        final sqft = (matData['unit_size_sqft'] as num?)?.toDouble() ?? 0.0;
        final isNewStyle = sqft > 0.001 && su.isNotEmpty;
        final deductDisp = isNewStyle ? (totalDeduction / sqft) : totalDeduction;
        final newDisp = isNewStyle ? (newStock / sqft) : newStock;
        final unitLabel = su.isNotEmpty ? ' $su' : '';
        summaryLines.add(
          '$matName: −${_fmt(deductDisp)}$unitLabel (now ${_fmt(newDisp)}$unitLabel)',
        );
      }
    });

    return summaryLines;
  }

  static String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  // ── Availability refresh ─────────────────────────────────────────────────────

  /// Updates [is_available] on products that use any of [materialIds].
  /// Uses effective stock (current_stock − reserved_stock) for the check.
  static Future<void> _refreshProductsUsingMaterials(
      List<String> materialIds) async {
    final matIdSet = materialIds.toSet();
    final products = await _db.collection('Products').get();

    for (final doc in products.docs) {
      final data = doc.data();
      if (data['availability_override'] != null) continue;

      final bom = List<Map<String, dynamic>>.from(
        ((data['bill_of_materials'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map)),
      );

      final usesMaterial = bom.any(
        (item) => matIdSet.contains(item['material_id']?.toString() ?? ''),
      );
      if (!usesMaterial) continue;

      bool available = true;
      for (final item in bom) {
        final matId = item['material_id']?.toString() ?? '';
        if (matId.isEmpty) continue;
        final matDoc =
            await _db.collection('RawMaterials').doc(matId).get();
        final matData = matDoc.data() ?? {};
        final stock = (matData['current_stock'] as num?)?.toDouble() ?? 0.0;
        final reserved =
            (matData['reserved_stock'] as num?)?.toDouble() ?? 0.0;
        if (stock - reserved <= 0) {
          available = false;
          break;
        }
      }

      await doc.reference.update({'is_available': available});
    }
  }

  /// Recalculates [is_available] for ALL products based on effective stock.
  /// Useful after a bulk stock update or initial seed.
  static Future<void> refreshAllProductAvailability() async {
    final products = await _db.collection('Products').get();

    for (final doc in products.docs) {
      final data = doc.data();
      if (data['availability_override'] != null) continue;

      final bom = List<Map<String, dynamic>>.from(
        ((data['bill_of_materials'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map)),
      );

      if (bom.isEmpty) continue;

      bool available = true;
      for (final item in bom) {
        final matId = item['material_id']?.toString() ?? '';
        if (matId.isEmpty) continue;
        final matDoc =
            await _db.collection('RawMaterials').doc(matId).get();
        final matData = matDoc.data() ?? {};
        final stock = (matData['current_stock'] as num?)?.toDouble() ?? 0.0;
        final reserved =
            (matData['reserved_stock'] as num?)?.toDouble() ?? 0.0;
        if (stock - reserved <= 0) {
          available = false;
          break;
        }
      }

      await doc.reference.update({'is_available': available});
    }
  }

  // ── Manual replenish ─────────────────────────────────────────────────────────

  /// Adds stock to a single raw material and writes a log entry.
  /// [method] should be 'manual', 'qr_scan', or 'admin_edit'.
  static Future<void> replenishMaterial({
    required String materialDocId,
    required double quantityToAdd,
    required String updatedByUid,
    required String updatedByName,
    String method = 'manual',
    String? orderId,
  }) async {
    await _db.runTransaction((tx) async {
      final ref = _db.collection('RawMaterials').doc(materialDocId);
      final snap = await tx.get(ref);

      final prevStock =
          ((snap.data()?['current_stock'] as num?)?.toDouble()) ?? 0.0;
      final newStock = prevStock + quantityToAdd;

      tx.update(ref, {
        'current_stock': newStock,
        'last_updated': FieldValue.serverTimestamp(),
        'last_updated_by': updatedByName,
        'last_updated_by_uid': updatedByUid,
      });

      final logRef = _db.collection('InventoryLogs').doc();
      tx.set(logRef, {
        'material_id': snap.data()?['material_id'] ?? materialDocId,
        'material_name': snap.data()?['material_name'] ?? '',
        'quantity_added': quantityToAdd,
        'previous_stock': prevStock,
        'new_stock': newStock,
        'updated_by_uid': updatedByUid,
        'updated_by_name': updatedByName,
        'timestamp': FieldValue.serverTimestamp(),
        'update_method': method,
        'order_id': orderId,
      });
    });
  }
}
