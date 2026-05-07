import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Handles deletion of customer-uploaded design files once an order is done.
///
/// Call [deleteFilesForOrder] immediately after setting an order's status
/// to 'completed'. It deletes all files from Firebase Storage and clears
/// the URL/path fields in Firestore so the order record stays intact but
/// no longer consumes storage.
class OrderFileUtils {
  static final _db      = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;

  /// Deletes all uploaded files for [orderId] from Storage, then clears
  /// file_urls and file_paths in the Firestore order document.
  static Future<void> deleteFilesForOrder(String orderId) async {
    try {
      final doc = await _db.collection('Orders').doc(orderId).get();
      if (!doc.exists) return;

      final products = List<Map<String, dynamic>>.from(
        (doc.data()?['products'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map)),
      );

      // Collect all storage paths across all products in the order
      final allPaths = <String>[];
      for (final p in products) {
        final paths = List<String>.from(p['file_paths'] as List? ?? []);
        allPaths.addAll(paths);
      }

      // Delete from Storage (ignore errors for already-deleted files)
      for (final path in allPaths) {
        try {
          await _storage.ref(path).delete();
        } catch (_) {}
      }

      // Clear file fields in Firestore — keeps the order record but removes
      // storage references so nothing dangling points to deleted blobs
      final cleaned = products.map((p) => {
        ...p,
        'file_urls':      [],
        'file_paths':     [],
        'files_deleted':  true,
      }).toList();

      await _db.collection('Orders').doc(orderId).update({
        'products': cleaned,
      });
    } catch (_) {}
  }
}
