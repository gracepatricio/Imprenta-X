// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

bool isMobileBrowser() {
  final ua = html.window.navigator.userAgent.toLowerCase();
  return RegExp(
    r'android|webos|iphone|ipad|ipod|blackberry|iemobile|opera mini',
  ).hasMatch(ua);
}
