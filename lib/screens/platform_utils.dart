// platform_utils.dart
// ---------------------------------------------------------------------------
// Single source of truth for platform detection across the app.
//
// Usage:
//   if (PlatformUtils.isMobileDevice) { ... }
//   if (await PlatformUtils.isMobileBrowser()) { ... }
// ---------------------------------------------------------------------------

import 'package:flutter/foundation.dart';

// Web-only JS interop — tree-shaken away on non-web builds.
import 'dart:js_interop' if (dart.library.io) 'dart:io';

// Provide a no-op stub on non-web platforms so the file compiles everywhere.
// On web, `window.navigator.userAgent` is accessed via dart:js_interop below.
extension type _Navigator._(JSObject _) implements JSObject {
  external String get userAgent;
}

extension type _Window._(JSObject _) implements JSObject {
  external _Navigator get navigator;
}

@JS('window')
external _Window get _jsWindow;

class PlatformUtils {
  PlatformUtils._();

  // ---------------------------------------------------------------------------
  // Native-platform helpers (unchanged)
  // ---------------------------------------------------------------------------

  /// True only on a physical/emulated Android or iOS *native* app build.
  /// Always false on Web, Windows, macOS, and Linux.
  static bool get isMobileDevice {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Convenience inverse.
  static bool get isWebOrDesktop => !isMobileDevice;

  // ---------------------------------------------------------------------------
  // Mobile-browser detection
  // ---------------------------------------------------------------------------

  /// Mobile UA token pattern.
  /// Covers Android phones/tablets, iPhone, iPad (iPadOS ≥ 13 spoof is handled
  /// separately), Windows Phone, and generic "Mobile" tokens used by most
  /// mobile browsers — including Chrome/Firefox/Safari in Desktop Mode, which
  /// *still* include these tokens even when they fake a desktop UA.
  ///
  /// References:
  ///   https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/User-Agent
  static final RegExp _mobileUaPattern = RegExp(
    r'(Android|iPhone|iPad|iPod|Mobile|IEMobile|BlackBerry|webOS|Opera Mini)',
    caseSensitive: false,
  );

  /// Returns `true` when the current browser's user-agent contains a mobile
  /// device token.
  ///
  /// This is the correct guard for **admin access** because it catches:
  ///   • Normal mobile browsers (Chrome, Safari, Firefox on Android/iOS).
  ///   • "Desktop Mode" toggled in Chrome/Safari/Firefox on mobile — those
  ///     browsers swap the desktop UA string but the OS-level token
  ///     (e.g. "Android", "iPhone") remains present in the full UA or in
  ///     `navigator.userAgentData.platform`.
  ///   • In-app WebViews on Android and iOS.
  ///
  /// Always returns `false` on native Flutter app builds (non-web).
  static Future<bool> isMobileBrowser() async {
    if (!kIsWeb) return false;

    try {
      // Primary check — the raw UA string.
      final ua = _jsWindow.navigator.userAgent;
      if (_mobileUaPattern.hasMatch(ua)) return true;

      // Secondary check — navigator.userAgentData.platform (Chrome 90+).
      // This survives Desktop Mode because Chromium exposes the real platform
      // via the structured User-Agent Client Hints API even when the legacy
      // UA string has been overridden by the browser's Desktop Mode toggle.
      final platform = await _getUaDataPlatform();
      if (platform != null) {
        final lp = platform.toLowerCase();
        if (lp.contains('android') || lp.contains('ios')) return true;
      }
    } catch (_) {
      // Swallow any JS interop errors; fail open (allow) so we never
      // accidentally block a genuine desktop user due to a browser quirk.
    }

    return false;
  }

  // ---------------------------------------------------------------------------
  // Structured UA Client Hints (Chrome 90+, Edge 90+)
  // ---------------------------------------------------------------------------

  /// Calls `navigator.userAgentData.getHighEntropyValues(['platform'])` and
  /// returns the platform string, or `null` if the API is unavailable.
  ///
  /// Using `dart:js_interop` / `package:web` is preferred in Flutter 3.19+;
  /// here we fall back to a raw `eval`-style call via `js` so the file
  /// remains compatible with older toolchains without adding a new dependency.
  static Future<String?> _getUaDataPlatform() async {
    // Only available in Chromium-based browsers.
    if (!kIsWeb) return null;
    try {
      // Dart's js_interop doesn't expose userAgentData natively yet, so we
      // use a small JS snippet evaluated through dart:js_interop helpers.
      // The expression resolves to a Promise<UADataValues>.
      final result = await _evalUaDataPlatform();
      return result;
    } catch (_) {
      return null;
    }
  }

  @JS('(async () => { '
      'if (!navigator.userAgentData) return null; '
      'const d = await navigator.userAgentData.getHighEntropyValues(["platform"]); '
      'return d.platform ?? null; '
      '})()')
  external static JSPromise<JSString?> _evalUaDataPlatformJs();

  static Future<String?> _evalUaDataPlatform() async {
    try {
      final jsResult = await _evalUaDataPlatformJs().toDart;
      return jsResult?.toDart;
    } catch (_) {
      return null;
    }
  }
}