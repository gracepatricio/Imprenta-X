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
  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
