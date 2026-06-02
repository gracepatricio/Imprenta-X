import 'package:url_launcher/url_launcher.dart';

/// Opens [url] in the platform's external application (browser, viewer, etc.).
Future<void> openFileInNewTab(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// On non-web platforms, downloading and viewing are the same — open externally.
Future<void> downloadFile(String url, String filename) async {
  await openFileInNewTab(url);
}
