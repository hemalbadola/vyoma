import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class PermissionManager {
  
  static Future<void> requestAll() async {
    // 1. Notification Permission (Crucial for Wakeup)
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }

    // 2. Microphone (Voice Commands - Optional)
    if (await Permission.microphone.status.isDenied) {
      // await Permission.microphone.request(); 
      // Commented out to avoid confusing user unless we actually use voice rec immediately
    }
    
    // 3. Exact Alarms (Android only, for precise wakeup)
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        // Handling for Android 12+ Exact Alarms if needed
        // await Permission.scheduleExactAlarm.request();
    }

    // Windows/Mac permissions are usually handled via capabilities in config files, 
    // but permission_handler might return generic statuses.
  }

  static Future<bool> hasNotificationPermission() async {
    return await Permission.notification.isGranted;
  }
}
