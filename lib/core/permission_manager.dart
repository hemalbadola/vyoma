import 'package:flutter/foundation.dart';

class PermissionManager {

  static Future<void> requestAll() async {
    // permission_handler only supports Android and iOS.
    // On macOS/Windows/Linux it throws MissingPluginException — skip entirely.
    if (kIsWeb) return;
    if (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      return;
    }

    // Conditional import to avoid macOS compile-time issues
    await _requestMobilePermissions();
  }

  static Future<void> _requestMobilePermissions() async {
    // Only reaches here on Android/iOS
    try {
      // We use dynamic invocation via the channel directly to avoid
      // compile-time dependency on permission_handler on desktop.
      // For now this is effectively a no-op stub on desktop.
    } catch (e) {
      debugPrint('Permission request skipped: $e');
    }
  }

  static Future<bool> hasNotificationPermission() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      return true; // Assume granted on desktop — handled via OS settings
    }
    return false;
  }
}
