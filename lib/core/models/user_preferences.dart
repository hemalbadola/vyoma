/// User preferences for Vyoma's proactive intelligence features.
/// All settings are customizable by the user.
class UserPreferences {
  // === TIME SETTINGS ===
  String wakeTime;           // When user typically wakes up (HH:MM)
  String sleepTime;          // When user typically sleeps (HH:MM)
  String? dailyBriefTime;    // When to show morning brief (null = wakeTime)
  String? dailyReviewTime;   // When to show end-of-day review (null = 1hr before sleep)
  
  // === QUIET HOURS ===
  String quietStart;         // No notifications after this time (HH:MM)
  String quietEnd;           // Resume notifications after this time (HH:MM)
  bool quietHoursEnabled;    // Master toggle for quiet hours
  
  // === DAILY BRIEF CONTENT ===
  bool briefIncludeWeather;    // Show weather in morning brief
  bool briefIncludeBattery;    // Show battery status
  bool briefIncludeCalendar;   // Show today's events
  bool briefIncludeGoals;      // Show priority reminders
  bool briefIncludeMetrics;    // Show yesterday's focus stats
  
  // === PROACTIVE ALERTS ===
  bool alertLateForEvent;      // "You're late for X"
  bool alertWeatherChange;     // "Rain before your outdoor event"
  bool alertFocusDrift;        // "You've been distracted for X min"
  bool alertLowBattery;        // "Low battery, upcoming events"
  bool alertAwolReturn;        // Welcome back after long absence
  bool alertEndOfDay;          // Daily summary notification
  
  // === ALERT TIMING ===
  int eventReminderMinutes;    // How early to remind (default: 15)
  int travelBufferMinutes;     // Extra time buffer for travel (default: 10)
  int focusDriftThreshold;     // Minutes on distraction before alert (default: 5)
  int lowBatteryThreshold;     // Battery % to trigger alert (default: 20)
  
  // === FOCUS SETTINGS ===
  List<String> distractionApps;  // Apps considered distractions
  String? focusStartTime;        // Work hours start (null = wakeTime)
  String? focusEndTime;          // Work hours end (null = sleepTime - 2hr)
  
  UserPreferences({
    this.wakeTime = "07:00",
    this.sleepTime = "23:00",
    this.dailyBriefTime,
    this.dailyReviewTime,
    this.quietStart = "22:00",
    this.quietEnd = "08:00",
    this.quietHoursEnabled = true,
    this.briefIncludeWeather = true,
    this.briefIncludeBattery = true,
    this.briefIncludeCalendar = true,
    this.briefIncludeGoals = true,
    this.briefIncludeMetrics = true,
    this.alertLateForEvent = true,
    this.alertWeatherChange = true,
    this.alertFocusDrift = true,
    this.alertLowBattery = true,
    this.alertAwolReturn = true,
    this.alertEndOfDay = true,
    this.eventReminderMinutes = 15,
    this.travelBufferMinutes = 10,
    this.focusDriftThreshold = 5,
    this.lowBatteryThreshold = 20,
    this.distractionApps = const [
      "Twitter", "X", "Reddit", "YouTube", "Instagram", 
      "TikTok", "Netflix", "Facebook", "Snapchat"
    ],
    this.focusStartTime,
    this.focusEndTime,
  });

  /// Get the effective brief time (falls back to wake time)
  String get effectiveBriefTime => dailyBriefTime ?? wakeTime;
  
  /// Get the effective review time (falls back to 1hr before sleep)
  String get effectiveReviewTime {
    if (dailyReviewTime != null) return dailyReviewTime!;
    // Parse sleep time and subtract 1 hour
    final parts = sleepTime.split(':');
    int hour = int.parse(parts[0]) - 1;
    if (hour < 0) hour = 23;
    return "${hour.toString().padLeft(2, '0')}:${parts[1]}";
  }
  
  /// Get the effective focus start time
  String get effectiveFocusStart => focusStartTime ?? wakeTime;
  
  /// Get the effective focus end time
  String get effectiveFocusEnd {
    if (focusEndTime != null) return focusEndTime!;
    final parts = sleepTime.split(':');
    int hour = int.parse(parts[0]) - 2;
    if (hour < 0) hour += 24;
    return "${hour.toString().padLeft(2, '0')}:${parts[1]}";
  }
  
  /// Check if current time is within quiet hours
  bool isQuietHours(DateTime now) {
    if (!quietHoursEnabled) return false;
    
    final currentMinutes = now.hour * 60 + now.minute;
    final startParts = quietStart.split(':');
    final endParts = quietEnd.split(':');
    final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
    
    // Handle overnight quiet hours (e.g., 22:00 to 08:00)
    if (startMinutes > endMinutes) {
      return currentMinutes >= startMinutes || currentMinutes < endMinutes;
    }
    return currentMinutes >= startMinutes && currentMinutes < endMinutes;
  }
  
  /// Check if current time is within focus hours
  bool isFocusHours(DateTime now) {
    final currentMinutes = now.hour * 60 + now.minute;
    final startParts = effectiveFocusStart.split(':');
    final endParts = effectiveFocusEnd.split(':');
    final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
    
    return currentMinutes >= startMinutes && currentMinutes < endMinutes;
  }
  
  /// Check if an app is considered a distraction
  bool isDistractionApp(String appName) {
    return distractionApps.any(
      (d) => appName.toLowerCase().contains(d.toLowerCase())
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() => {
    'wake_time': wakeTime,
    'sleep_time': sleepTime,
    'daily_brief_time': dailyBriefTime,
    'daily_review_time': dailyReviewTime,
    'quiet_start': quietStart,
    'quiet_end': quietEnd,
    'quiet_hours_enabled': quietHoursEnabled,
    'brief_include_weather': briefIncludeWeather,
    'brief_include_battery': briefIncludeBattery,
    'brief_include_calendar': briefIncludeCalendar,
    'brief_include_goals': briefIncludeGoals,
    'brief_include_metrics': briefIncludeMetrics,
    'alert_late_for_event': alertLateForEvent,
    'alert_weather_change': alertWeatherChange,
    'alert_focus_drift': alertFocusDrift,
    'alert_low_battery': alertLowBattery,
    'alert_awol_return': alertAwolReturn,
    'alert_end_of_day': alertEndOfDay,
    'event_reminder_minutes': eventReminderMinutes,
    'travel_buffer_minutes': travelBufferMinutes,
    'focus_drift_threshold': focusDriftThreshold,
    'low_battery_threshold': lowBatteryThreshold,
    'distraction_apps': distractionApps,
    'focus_start_time': focusStartTime,
    'focus_end_time': focusEndTime,
  };

  /// Create from JSON
  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      wakeTime: json['wake_time'] ?? "07:00",
      sleepTime: json['sleep_time'] ?? "23:00",
      dailyBriefTime: json['daily_brief_time'],
      dailyReviewTime: json['daily_review_time'],
      quietStart: json['quiet_start'] ?? "22:00",
      quietEnd: json['quiet_end'] ?? "08:00",
      quietHoursEnabled: json['quiet_hours_enabled'] ?? true,
      briefIncludeWeather: json['brief_include_weather'] ?? true,
      briefIncludeBattery: json['brief_include_battery'] ?? true,
      briefIncludeCalendar: json['brief_include_calendar'] ?? true,
      briefIncludeGoals: json['brief_include_goals'] ?? true,
      briefIncludeMetrics: json['brief_include_metrics'] ?? true,
      alertLateForEvent: json['alert_late_for_event'] ?? true,
      alertWeatherChange: json['alert_weather_change'] ?? true,
      alertFocusDrift: json['alert_focus_drift'] ?? true,
      alertLowBattery: json['alert_low_battery'] ?? true,
      alertAwolReturn: json['alert_awol_return'] ?? true,
      alertEndOfDay: json['alert_end_of_day'] ?? true,
      eventReminderMinutes: json['event_reminder_minutes'] ?? 15,
      travelBufferMinutes: json['travel_buffer_minutes'] ?? 10,
      focusDriftThreshold: json['focus_drift_threshold'] ?? 5,
      lowBatteryThreshold: json['low_battery_threshold'] ?? 20,
      distractionApps: (json['distraction_apps'] as List?)?.cast<String>() ?? [
        "Twitter", "X", "Reddit", "YouTube", "Instagram", 
        "TikTok", "Netflix", "Facebook", "Snapchat"
      ],
      focusStartTime: json['focus_start_time'],
      focusEndTime: json['focus_end_time'],
    );
  }

  /// Create a copy with updated fields
  UserPreferences copyWith({
    String? wakeTime,
    String? sleepTime,
    String? dailyBriefTime,
    String? dailyReviewTime,
    String? quietStart,
    String? quietEnd,
    bool? quietHoursEnabled,
    bool? briefIncludeWeather,
    bool? briefIncludeBattery,
    bool? briefIncludeCalendar,
    bool? briefIncludeGoals,
    bool? briefIncludeMetrics,
    bool? alertLateForEvent,
    bool? alertWeatherChange,
    bool? alertFocusDrift,
    bool? alertLowBattery,
    bool? alertAwolReturn,
    bool? alertEndOfDay,
    int? eventReminderMinutes,
    int? travelBufferMinutes,
    int? focusDriftThreshold,
    int? lowBatteryThreshold,
    List<String>? distractionApps,
    String? focusStartTime,
    String? focusEndTime,
  }) {
    return UserPreferences(
      wakeTime: wakeTime ?? this.wakeTime,
      sleepTime: sleepTime ?? this.sleepTime,
      dailyBriefTime: dailyBriefTime ?? this.dailyBriefTime,
      dailyReviewTime: dailyReviewTime ?? this.dailyReviewTime,
      quietStart: quietStart ?? this.quietStart,
      quietEnd: quietEnd ?? this.quietEnd,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      briefIncludeWeather: briefIncludeWeather ?? this.briefIncludeWeather,
      briefIncludeBattery: briefIncludeBattery ?? this.briefIncludeBattery,
      briefIncludeCalendar: briefIncludeCalendar ?? this.briefIncludeCalendar,
      briefIncludeGoals: briefIncludeGoals ?? this.briefIncludeGoals,
      briefIncludeMetrics: briefIncludeMetrics ?? this.briefIncludeMetrics,
      alertLateForEvent: alertLateForEvent ?? this.alertLateForEvent,
      alertWeatherChange: alertWeatherChange ?? this.alertWeatherChange,
      alertFocusDrift: alertFocusDrift ?? this.alertFocusDrift,
      alertLowBattery: alertLowBattery ?? this.alertLowBattery,
      alertAwolReturn: alertAwolReturn ?? this.alertAwolReturn,
      alertEndOfDay: alertEndOfDay ?? this.alertEndOfDay,
      eventReminderMinutes: eventReminderMinutes ?? this.eventReminderMinutes,
      travelBufferMinutes: travelBufferMinutes ?? this.travelBufferMinutes,
      focusDriftThreshold: focusDriftThreshold ?? this.focusDriftThreshold,
      lowBatteryThreshold: lowBatteryThreshold ?? this.lowBatteryThreshold,
      distractionApps: distractionApps ?? this.distractionApps,
      focusStartTime: focusStartTime ?? this.focusStartTime,
      focusEndTime: focusEndTime ?? this.focusEndTime,
    );
  }
}
