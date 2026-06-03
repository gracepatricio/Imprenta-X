// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

/// Returns (filename, bytes), or null if cancelled.
/// Uses a native browser <input type="file"> so it works with Flutter Web's
/// CanvasKit renderer (file_picker's approach breaks on hosted web).
Future<(String, Uint8List)?> pickSalesFile() {
  final completer = Completer<(String, Uint8List)?>();

  final input = html.FileUploadInputElement()
    ..accept = '.xlsx,.xls,.csv'
    ..multiple = false
    ..style.display = 'none';
  html.document.body!.append(input);

  input.onChange.listen((_) async {
    final files = input.files;
    if (files == null || files.isEmpty) {
      input.remove();
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    try {
      final file  = files.first;
      final bytes = await _readBytes(file);
      input.remove();
      if (!completer.isCompleted) completer.complete((file.name, bytes));
    } catch (e) {
      input.remove();
      if (!completer.isCompleted) completer.completeError(e);
    }
  });

  input.click();
  return completer.future;
}

Future<Uint8List> _readBytes(html.File file) {
  final c = Completer<Uint8List>();
  final reader = html.FileReader();
  reader.onLoad.listen((_) {
    try {
      final dataUrl   = reader.result as String;
      final base64Data = dataUrl.split(',').last;
      c.complete(base64Decode(base64Data));
    } catch (e) {
      c.completeError(e);
    }
  });
  reader.onError.listen((_) => c.completeError('Failed to read ${file.name}'));
  reader.readAsDataUrl(file);
  return c.future;
}
