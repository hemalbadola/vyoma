import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'calendar_service.dart';
import 'window_spy.dart';

class ActivityLog {
  final DateTime timestamp;
  final String appName;
  final String? windowTitle;
  final String? browserUrl;
  final String scheduledTask;
  final bool isCompliant;

  ActivityLog({
    required this.timestamp,
    required this.appName,
    this.windowTitle,
    this.browserUrl,
    required this.scheduledTask,
    required this.isCompliant,
  });

  Map<String, dynamic> toJson() => {
    'time': timestamp.toIso8601String(),
    'app': appName,
    'title': windowTitle,
    'url': browserUrl,
    'task': scheduledTask,
    'status': isCompliant ? "COMPLIANT" : "VIOLATION"
  };
}

class WatchtowerService {
  final CalendarService _calendarService;
  final WindowSpy _windowSpy = WindowSpy();
  
  Timer? _patrolTimer;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  bool _isPatrolling = false;
  
  // Storage
  final List<ActivityLog> _activityLog = [];
  
  // Public API for Intelligence
  List<Map<String, dynamic>> getRecentLogs({Duration duration = const Duration(hours: 3)}) {
    final cutoff = DateTime.now().subtract(duration);
    return _activityLog
      .where((log) => log.timestamp.isAfter(cutoff))
      .map((log) => log.toJson())
      .toList();
  }
  
  // Heuristic Lists
  final List<String> _productiveApps = ["Code", "Android Studio", "Xcode", "Terminal", "iTerm2", "Notes", "Obsidian", "Cursor"];
  final List<String> _distractionApps = ["Netflix", "YouTube", "Twitter", "Steam", "Discord", "Twitch"];

  WatchtowerService(this._calendarService) {
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings, macOS: iosSettings);
    
    await _notifications.initialize(settings);
  }

  void startWatch({Duration interval = const Duration(minutes: 5)}) {
    if (_isPatrolling) return;
    print("WATCHTOWER: Surveillance Grid Activated.");
    _isPatrolling = true;
    _patrol(); // Immediate check
    _patrolTimer = Timer.periodic(interval, (_) => _patrol());
  }

  void stopWatch() {
    _patrolTimer?.cancel();
    _isPatrolling = false;
    print("WATCHTOWER: Surveillance Grid Offline.");
  }

  Future<void> _patrol() async {
    if (kDebugMode) print("WATCHTOWER: Patrol Sweep Initiated...");

    // 1. Get Intel
    final windowData = await _windowSpy.spyOnUser();
    final activeApp = windowData['active_app'] as String?;
    final windowTitle = windowData['window_title'] as String?;
    
    // 2. Get Orders
    final events = await _calendarService.syncEvents(); 
    final now = DateTime.now();
    
    // Find event happening RIGHT NOW
    final currentEvent = events.firstWhere(
      (e) {
        if (e.start?.dateTime == null || e.end?.dateTime == null) return false;
        return e.start!.dateTime!.isBefore(now) && e.end!.dateTime!.isAfter(now);
      },
      orElse: () => calendar.Event(summary: "Free Time"), // Dummy
    );

    if (activeApp == null) return;
    if (kDebugMode) print("WATCHTOWER: App: $activeApp | Title: $windowTitle | Objective: ${currentEvent.summary}");

    // 3. Analyze Compliance
    // Scenario A: "Free Time" -> No restrictions.
    // However, we still log it.
    bool compliant = true;
    
    // Scenario B: "Deep Work" / "Code" / "Study"
    bool isWorkEvent = _isWorkObjective(currentEvent.summary ?? "Free Time");
    
    String? browserUrl = windowData['browser_url'] as String?;

    if (isWorkEvent && currentEvent.summary != "Free Time") {
       // Check for Deserters
       if (_isDistraction(activeApp, windowTitle, browserUrl)) {
          compliant = false;
          _triggerIntervention(
             title: "DESERTION DETECTED", 
             body: "You are ordered to [${currentEvent.summary}]. Close [$activeApp] immediately."
          );
       }
    }
    
    // 4. Record Evidence
    _activityLog.add(ActivityLog(
      timestamp: now,
      appName: activeApp,
      windowTitle: windowTitle,
      browserUrl: browserUrl,
      scheduledTask: currentEvent.summary ?? "Unknown",
      isCompliant: compliant
    ));
    
    // Keep log size manageable
    if (_activityLog.length > 100) {
      _activityLog.removeAt(0);
    }
  }

  bool _isWorkObjective(String summary) {
    final s = summary.toLowerCase();
    return s.contains("code") || s.contains("study") || s.contains("work") || s.contains("project") || s.contains("exam");
  }

  bool _isDistraction(String appName, String? windowTitle, String? browserUrl) {
    // Check strict list (App Names)
    if (_distractionApps.any((d) => appName.contains(d))) return true;
    
    // Check Window Titles (Browser Tabs)
    if (windowTitle != null) {
       if (_distractionApps.any((d) => windowTitle.toLowerCase().contains(d.toLowerCase()))) return true;
    }
    
    // Check Browser URL (Deep Inspection)
    if (browserUrl != null) {
       if (_distractionApps.any((d) => browserUrl.toLowerCase().contains(d.toLowerCase()))) return true;
    }
    
    return false; 
  }

  Future<void> _triggerIntervention({required String title, required String body}) async {
    const details = NotificationDetails(
      macOS: DarwinNotificationDetails(
        presentSound: true,
        presentAlert: true,
        subtitle: "Vyoma",
        interruptionLevel: InterruptionLevel.critical,
      ),
    );

    await _notifications.show(
      0, 
      title, 
      body, 
      details
    );
  }
}
