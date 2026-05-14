import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

import 'memory_service.dart';
import 'notification_service.dart';
import 'sentinel_service.dart';
import 'watchtower_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('BackgroundAgent: workmanager tick ($task)');
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await BackgroundAgentEngine.executeBackgroundNudge();
      return Future.value(true);
    } catch (e) {
      debugPrint('BackgroundAgent error: $e');
      return Future.value(false);
    }
  });
}

class BackgroundAgentEngine {
  static Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint('BackgroundAgent: web — skipped.');
      return;
    }
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      debugPrint('BackgroundAgent: desktop — skipped.');
      return;
    }

    Workmanager().initialize(callbackDispatcher);

    // Android minimum periodic interval is ~15 minutes; use the tightest allowed.
    await Workmanager().registerPeriodicTask(
      'vyoma-ambient-tick',
      'vyomaAmbientTick',
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }

  static Future<void> executeBackgroundNudge() async {
    final memory = MemoryService();
    await memory.init();

    final notifications = NotificationService();
    await notifications.ensureInitialized();

    final sentinel = SentinelService(
      memory: memory,
      notifications: notifications,
    );
    final watchtower = WatchtowerService(
      memory: memory,
      notifications: notifications,
    );

    await sentinel.fireIfNeeded();
    await watchtower.tick();

    // Refresh ongoing ambient from last foreground snapshot (no calendar in isolate).
    await notifications.refreshAmbientFromPrefs();
  }

  static Future<void> cancelAll() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    await Workmanager().cancelAll();
  }

  static void dispose() {
    unawaited(cancelAll());
  }
}
