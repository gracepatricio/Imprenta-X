// platform_utils.dart
// ---------------------------------------------------------------------------
// Single source of truth for platform detection across the app.
//
// Usage:
//   if (PlatformUtils.isMobileDevice) { ... }
// ---------------------------------------------------------------------------

import 'package:flutter/foundation.dart';

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

  /// Convenience inverse.
  static bool get isWebOrDesktop => !isMobileDevice;
}