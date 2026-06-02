// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:http/http.dart' as http;

/// Opens [url] in a new browser tab.
Future<void> openFileInNewTab(String url) async {
  html.window.open(url, '_blank');
}

/// Downloads the file at [url] with [filename] using a fetch → blob approach
/// so it works cross-origin (bypasses the browser download-attribute restriction).
Future<void> downloadFile(String url, String filename) async {
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final blob = html.Blob([response.bodyBytes]);
      final objectUrl = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: objectUrl)
        ..setAttribute('download', filename)
        ..style.display = 'none';
      html.document.body!.append(anchor);
      anchor.click();
      anchor.remove();
      Future.delayed(
        const Duration(seconds: 2),
        () => html.Url.revokeObjectUrl(objectUrl),
      );
    } else {
      // fallback: open in new tab
      html.window.open(url, '_blank');
    }
  } catch (_) {
    html.window.open(url, '_blank');
  }
}
