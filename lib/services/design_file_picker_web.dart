// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

/// Returns list of (filename, bytes) pairs, or null if cancelled.
/// Uses a native browser <input type="file"> so it works correctly
/// with Flutter's CanvasKit renderer (which breaks file_picker's approach).
Future<List<(String, Uint8List)>?> pickDesignFiles({
  bool multiple = true,
}) {
  final completer = Completer<List<(String, Uint8List)>?>();

  final input = html.FileUploadInputElement()
    ..accept = '.pdf,.jpg,.jpeg,.png,.psd,.ai'
    ..multiple = multiple
    ..style.display = 'none';
  html.document.body!.append(input);

  input.onChange.listen((_) => _onChanged(input, completer));
  input.click();
  return completer.future;
}

Future<void> _onChanged(
  html.FileUploadInputElement input,
  Completer<List<(String, Uint8List)>?> completer,
) async {
  if (completer.isCompleted) return;
  final files = input.files;
  if (files == null || files.isEmpty) {
    input.remove();
    completer.complete(null);
    return;
  }
  try {
    final results = <(String, Uint8List)>[];
    for (final file in files) {
      final bytes = await _readBytes(file);
      results.add((file.name, bytes));
    }
    input.remove();
    completer.complete(results);
  } catch (e) {
    input.remove();
    if (!completer.isCompleted) completer.completeError(e);
  }
}

Future<Uint8List> _readBytes(html.File file) {
  final c = Completer<Uint8List>();
  final reader = html.FileReader();
  reader.onLoad.listen((_) {
    try {
      // readAsDataUrl gives "data:<type>;base64,<data>" — reliable in all
      // dart2js build modes, avoids ArrayBuffer/ByteBuffer type ambiguity.
      final dataUrl = reader.result as String;
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
