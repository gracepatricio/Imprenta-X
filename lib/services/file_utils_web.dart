// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Synchronous URL opener — MUST be called without any await in the call chain
/// so the browser's user-gesture context is preserved. Browsers (especially
/// Firefox with bounce-tracker protection) block navigations that originate
/// from async microtasks because they are not considered user-initiated.
/// Navigates the CURRENT browser tab to [url].
/// This is the reliable way to open payment pages — no popup, no blocker,
/// no bounce-tracker restriction because it is a direct same-tab navigation.
void navigateCurrentPage(String url) {
  html.window.location.href = url;
}

/// Returns the value of the `pm` query parameter if present (e.g. 'paid').
String getPaymentReturnStatus() {
  final uri = Uri.tryParse(html.window.location.href) ?? Uri();
  return uri.queryParameters['pm'] ?? '';
}

/// Removes the `?pm=…` query string from the browser URL bar without reload.
void clearPaymentReturnParam() {
  final href = html.window.location.href;
  if (href.contains('?pm=')) {
    html.window.history.replaceState(null, '', '/#/customer');
  }
}

/// Downloads in-memory bytes directly as a file — used for generated PDFs.
Future<void> downloadBytes(Uint8List bytes, String mimeType, String filename) async {
  final blob      = html.Blob([bytes], mimeType);
  final objectUrl = html.Url.createObjectUrlFromBlob(blob);
  final anchor    = html.AnchorElement(href: objectUrl)
    ..setAttribute('download', filename)
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  Future.delayed(const Duration(seconds: 2), () => html.Url.revokeObjectUrl(objectUrl));
}

// ── Pending payment localStorage helpers (no plugin, guaranteed on web) ──────

void savePendingPayment(String json) {
  html.window.localStorage['pm_pending'] = json;
}

String? loadPendingPayment() {
  return html.window.localStorage['pm_pending'];
}

void clearPendingPayment() {
  html.window.localStorage.remove('pm_pending');
}

void openUrlSync(String url) {
  final anchor = html.AnchorElement(href: url)
    ..target = '_blank'
    ..rel = 'noopener'   // keep noopener but drop noreferrer (some payment
                         // providers use the Referer header for session init)
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
}

/// Async wrapper for non-payment contexts (file viewer, chat links, etc.)
/// where gesture context is not critical.
Future<void> openFileInNewTab(String url) async {
  openUrlSync(url);
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
