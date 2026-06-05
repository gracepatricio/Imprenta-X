// platform_utils.dart
// ---------------------------------------------------------------------------
// Single source of truth for platform detection across the app.
//
// Usage:
//   if (PlatformUtils.isMobileDevice) { ... }
//   if (PlatformUtils.effectiveMobile) { ... }
// ---------------------------------------------------------------------------

import 'package:flutter/foundation.dart';
import 'browser_utils_io.dart' if (dart.library.html) 'browser_utils_web.dart';

class PlatformUtils {
  PlatformUtils._();

  /// Returns true when running on a physical/emulated Android or iOS device.
  /// Returns false on Web, Windows, macOS, and Linux — even when the browser
  /// window is narrow — because feature restrictions are tied to the *platform*
  /// (device capability / trust level), not the viewport width.
  static bool get isMobileDevice {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Returns true on native Android/iOS AND on a web browser running on a
  /// mobile device. Use this instead of isMobileDevice when you want mobile
  /// browsers to receive the same features, restrictions, and layout as the
  /// native mobile app.
  static bool get effectiveMobile =>
      isMobileDevice || (kIsWeb && isMobileBrowser());

  /// Convenience inverse.
  static bool get isWebOrDesktop => !isMobileDevice;
}