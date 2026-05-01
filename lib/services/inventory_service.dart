import 'package:cloud_firestore/cloud_firestore.dart';

/// Handles all inventory stock changes that are triggered programmatically
/// (as opposed to manual employee replenishment or admin edits).
///
/// ## How to use when processing a customer order
///
/// When an order moves to "In Production" (or whatever status triggers
/// material consumption), call [deductForOrder]:
///
/// ```dart
/// await InventoryService.deductForOrder(
///   orderId: orderId,
///   productId: product['product_id'],
///   productName: product['product_name'],
///   orderQuantity: customerOrderQty,   // e.g. 50 sqft
///   processedByUid: adminUid,
///   processedByName: adminName,
/// );
/// ```
///
/// The service will:
/// 1. Read the product's Bill of Materials from Firestore
/// 2. Calculate material needed = bom_quantity_per_unit × orderQuantity
/// 3. Deduct from each material's current_stock (floor at 0)
/// 4. Write InventoryLog entries (method: 'order_deduction')
/// 5. Refresh product availability based on updated stock
///
/// ## BOM quantity_per_unit convention
///
/// quantity_per_unit means: "how much of this raw material is consumed
/// per 1 unit of the order quantity."
///
/// Examples:
///   - Tarpaulin (ordered in sqft): {material_id: 'RM-021', quantity_per_unit: 0.01}
///     → customer orders 100 sqft → deduct 0.01 × 100 = 1 roll
///   - Calling Card (ordered in pcs): {material_id: 'RM-019', quantity_per_unit: 0.02}
///     → customer orders 50 pcs → deduct 0.02 × 50 = 1 sintra sheet
class InventoryService {
  InventoryService._();

  static final _db = FirebaseFirestore.instance;

  // ── Order deduction ─────────────────────────────────────────────────────────

  /// Deducts raw materials from stock based on a customer order.
  ///
  /// Throws if the product does not exist.
  /// Silently skips materials with empty IDs or that don't exist in Firestore.
  static Future<void> deductForOrder({
    required String orderId,
    required String productId,
    required String productName,
    required double orderQuantity,
    required String processedByUid,
    required String processedByName,
  }) async {
    // 1. Fetch product BOM
    final productDoc =
        await _db.collection('Products').doc(productId).get();
    if (!productDoc.exists) {
      throw Exception('Product not found: $productId');
    }

    final bom = List<Map<String, dynamic>>.from(
      ((productDoc.data()?['bill_of_materials'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map)),
    );

    if (bom.isEmpty) return; // No BOM → nothing to deduct

    // 2. Run a single Firestore transaction (all reads before all writes)
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

        final qtyPerUnit =
            (item['quantity_per_unit'] as num?)?.toDouble() ?? 1.0;
        final totalDeduction = qtyPerUnit * orderQuantity;

        final prevStock =
            ((snap.data() as Map?)?['current_stock'] as num?)
                    ?.toDouble() ??
                0.0;
        final newStock =
            (prevStock - totalDeduction).clamp(0.0, double.maxFinite);

        // Update raw material stock
        tx.update(ref, {
          'current_stock': newStock,
          'last_updated': FieldValue.serverTimestamp(),
          'last_updated_by': processedByName,
          'last_updated_by_uid': processedByUid,
        });

        // Write inventory log entry
        final logRef = _db.collection('InventoryLogs').doc();
        tx.set(logRef, {
          'material_id': matId,
          'material_name': item['material_name']?.toString() ?? '',
          'quantity_added': -totalDeduction, // negative = deduction
          'previous_stock': prevStock,
          'new_stock': newStock,
          'updated_by_uid': processedByUid,
          'updated_by_name': processedByName,
          'timestamp': FieldValue.serverTimestamp(),
          'update_method': 'order_deduction',
          'order_id': orderId,
          'product_name': productName,
        });
      }
    });

    // 3. Refresh product availability (non-critical, runs after transaction)
    await _refreshAvailability(productId, bom);
  }

  // ── Manual replenish (mirrors employee screen — call if needed elsewhere) ──

  /// Adds stock to a single raw material and writes a log entry.
  ///
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
      final ref =
          _db.collection('RawMaterials').doc(materialDocId);
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
        if (orderId != null) 'order_id': orderId,
      });
    });
  }

  // ── Availability refresh ────────────────────────────────────────────────────

  /// Recomputes [is_available] for a product based on its BOM and current stock.
  /// Only updates if no manual override is set.
  static Future<void> _refreshAvailability(
      String productId, List<Map<String, dynamic>> bom) async {
    try {
      final productDoc =
          await _db.collection('Products').doc(productId).get();
      if (!productDoc.exists) return;

      // Respect manual override
      if (productDoc.data()?['availability_override'] != null) return;

      bool available = true;
      for (final item in bom) {
        final matId = item['material_id']?.toString() ?? '';
        if (matId.isEmpty) continue;
        final matDoc =
            await _db.collection('RawMaterials').doc(matId).get();
        final stock =
            (matDoc.data()?['current_stock'] as num?)?.toDouble() ?? 0.0;
        if (stock <= 0) {
          available = false;
          break;
        }
      }

      await _db
          .collection('Products')
          .doc(productId)
          .update({'is_available': available});
    } catch (_) {
      // Non-critical — availability refresh failure does not break the order
    }
  }

  // ── Batch availability refresh (call after seeding or bulk stock changes) ──

  /// Recalculates [is_available] for ALL products based on current stock.
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
        final stock =
            (matDoc.data()?['current_stock'] as num?)?.toDouble() ?? 0.0;
        if (stock <= 0) {
          available = false;
          break;
        }
      }

      await doc.reference.update({'is_available': available});
    }
  }
}
