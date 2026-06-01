import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

/// Returns list of (filename, bytes) pairs, or null if cancelled.
Future<List<(String, Uint8List)>?> pickDesignFiles({
  bool multiple = true,
}) async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: multiple,
    type: FileType.custom,
    allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'psd', 'ai'],
    withData: true,
  );
  if (result == null) return null;
  return result.files
      .where((f) => f.bytes != null)
      .map((f) => (f.name, f.bytes!))
      .toList();
}
