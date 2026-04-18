import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

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
      // Import is not needed if we use the channel but we have 'permission_handler' in pubspec.
      // We will request core permissions: Notifications and Alarms.
      final statuses = await [
        Permission.notification,
        Permission.scheduleExactAlarm,
      ].request();

      debugPrint('Mobile Permission Statuses: $statuses');
    } catch (e) {
      debugPrint('Permission request failed or skipped: $e');
    }
  }

  static Future<bool> hasNotificationPermission() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      return true; // Assume granted on desktop — handled via OS settings
    }
    
    final status = await Permission.notification.status;
    return status.isGranted;
  }
}
