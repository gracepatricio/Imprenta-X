import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

/// Returns (filename, bytes), or null if cancelled.
Future<(String, Uint8List)?> pickSalesFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['xlsx', 'xls', 'csv'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;
  final f = result.files.first;
  if (f.bytes == null) return null;
  return (f.name, f.bytes!);
}
