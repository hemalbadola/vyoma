import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

import 'ai_service.dart';
import 'notification_service.dart';
import 'telemetry_service.dart';
import 'chronos_service.dart';
import 'calendar_service.dart';
import 'memory_service.dart';
import 'auth_manager.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint("Background Agent: Waking up via Workmanager...");
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await BackgroundAgentEngine.executeBackgroundNudge();
      return Future.value(true);
    } catch (e) {
      debugPrint("Background Agent Execution Error: $e");
      return Future.value(false);
    }
  });
}

class BackgroundAgentEngine {
  static Future<void> initialize() async {
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      debugPrint("BackgroundAgentEngine: Initializing Workmanager for OS-level background execution.");
      Workmanager().initialize(
        callbackDispatcher,
      );
      
      Workmanager().registerPeriodicTask(
        "vyoma-autonomous-nudge",
        "nudge-task",
        frequency: const Duration(hours: 1),
      );
    } else {
      debugPrint("BackgroundAgentEngine: Workmanager not supported on this platform.");
    }
  }

  static Future<void> executeBackgroundNudge() async {
    // Initialize core background services needed for autonomous execution
    final memory = MemoryService();
    await memory.init();
    final chronos = ChronosService(memory);
    final telemetry = TelemetryService();
    final authManager = AuthManager();
    final calendar = CalendarService(authManager);
    final notifications = NotificationService();
    
    // Ensure notifications can punch through locally
    await notifications.ensureInitialized();

    try {
      final timeContext = chronos.getTemporalContext();
      final deviceStatusMatrix = await telemetry.getCrossDeviceMatrix();
      
      final now = DateTime.now();
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final upcomingEvents = await calendar.syncEventsInRange(timeMin: now, timeMax: endOfDay, maxResults: 5);

      final silentPrompt = """
SYSTEM INSTRUCTION: You are Vyoma's Autonomous Nudge Engine. 
You must evaluate if the user needs a proactive notification based on their time, schedule, and current telemetry.
- If they are on track, or no critical deadline is approaching, RETURN EMPTY STRING (do not disturb).
- If they are distracted and have an upcoming study block, return a 1-sentence push notification text.
- If they are drastically over schedule, return a strict warning.
DO NOT use XML or JSON. Return plain text.

TIME STATE: $timeContext
TELEMETRY: $deviceStatusMatrix
EVENTS: ${upcomingEvents.map((e) => e.summary).join(', ')}
""";

      final responseText = await AIService.executeSilentBackgroundPrompt(silentPrompt);
      
      if (responseText != null && responseText.trim().isNotEmpty && responseText.trim().toLowerCase() != 'null') {
        await notifications.notifyNow(
          title: "Vyoma (Omniscient)",
          body: responseText.trim(),
        );
        debugPrint("Background Agent: Fired proactive nudge: '$responseText'");
      } else {
        debugPrint("Background Agent: Evaluation returned empty. No nudge needed.");
      }
    } catch (e) {
      debugPrint("Background Agent Subtask Error: $e");
      rethrow;
    }
  }

  static void dispose() {
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      Workmanager().cancelAll();
    }
  }
}
