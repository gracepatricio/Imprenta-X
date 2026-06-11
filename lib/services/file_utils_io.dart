import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';

// Mobile stubs — same-tab navigation and localStorage are web-only.
void navigateCurrentPage(String url) {}
String getPaymentReturnStatus() => '';
void clearPaymentReturnParam() {}
void savePendingPayment(String json) {}
String? loadPendingPayment() => null;
void clearPendingPayment() {}
// On mobile the PDF is shared via Printing.sharePdf — no-op here.
Future<void> downloadBytes(Uint8List bytes, String mimeType, String filename) async {}

void openUrlSync(String url) {
  final uri = Uri.parse(url);
  // inAppBrowserView = Chrome Custom Tabs (Android) / SFSafariViewController (iOS).
  // Keeps the payment page visually inside the app while still supporting
  // GCash/Maya deep-links (unlike a WebView, which PayMongo blocks).
  launchUrl(uri, mode: LaunchMode.inAppBrowserView).catchError((_) {
    launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) {
      launchUrl(uri, mode: LaunchMode.platformDefault).catchError((_) {});
      return false;
    });
    return false;
  });
}

Future<void> openFileInNewTab(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Future<void> downloadFile(String url, String filename) async {
  await openFileInNewTab(url);
}
