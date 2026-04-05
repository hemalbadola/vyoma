import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'models/timetable.dart';
import 'calendar_service.dart';

class TimetableService extends ChangeNotifier {
  static const String _kTimetablePrefsKey = 'vyoma_timetable_data';
  static const String _kSyncedEventIdsPrefsKey = 'vyoma_timetable_event_ids';
  List<TimetableSlot> _slots = [];
  final CalendarService _calendarService;

  List<TimetableSlot> get slots => List.unmodifiable(_slots);

  TimetableService(this._calendarService) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final dataString = prefs.getString(_kTimetablePrefsKey);

    if (dataString != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(dataString);
        _slots = jsonList.map((e) => TimetableSlot.fromJson(e)).toList();
        notifyListeners();
      } catch (e) {
        debugPrint("Failed to load timetable: $e");
        await _seedInitialData();
      }
    } else {
      await _seedInitialData();
    }
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList = _slots.map((s) => s.toJson()).toList();
    await prefs.setString(_kTimetablePrefsKey, jsonEncode(jsonList));
    notifyListeners();
  }

  Future<List<String>> _loadSyncedEventIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kSyncedEventIdsPrefsKey) ?? const [];
  }

  Future<void> _saveSyncedEventIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kSyncedEventIdsPrefsKey, ids);
  }

  /// Replaces the entire timetable. Used by AI sync.
  Future<void> updateTimetable(List<TimetableSlot> newSlots) async {
    _slots = newSlots;
    await _saveToStorage();
    await syncToGoogleCalendar();
  }

  /// Adds a single manual slot.
  Future<void> addSlot(TimetableSlot slot) async {
    _slots.add(slot);
    await _saveToStorage();
    await syncToGoogleCalendar();
  }

  /// Removes a manual slot.
  Future<void> removeSlot(TimetableSlot slot) async {
    _slots.removeWhere((s) => 
      s.dayOfWeek == slot.dayOfWeek && 
      s.startTime == slot.startTime && 
      s.subject == slot.subject
    );
    await _saveToStorage();
    await syncToGoogleCalendar();
  }

  // --- GOOGLE CALENDAR SYNC (ROBUST NATIVE OVERRIDE) ---
  
  /// Wipes all Vyoma-generated timetable events from Google Calendar and rebuilds them.
  /// Uses RRULE to make them repeat weekly until the end of the semester.
  Future<void> syncToGoogleCalendar() async {
    debugPrint("Syncing Timetable to Google Calendar natively...");
    try {
      // 0. Delete previously synced event IDs first for deterministic cleanup.
      final previouslySyncedIds = await _loadSyncedEventIds();
      for (final eventId in previouslySyncedIds) {
        try {
          await _calendarService.deleteEvent(eventId);
        } catch (e) {
          debugPrint("Failed to delete previously synced timetable event $eventId: $e");
        }
      }

      // 1. Wipe previous sync
      await _calendarService.deleteTimetableEvents();

      if (_slots.isEmpty) {
        await _saveSyncedEventIds(const []);
        debugPrint("Timetable Sync Complete. Calendar timetable entries cleared.");
        return;
      }
      
      // 2. Reference datetimes. We need a "base week" to attach the start times to.
      // We'll use the upcoming week.
      final now = DateTime.now();
      final createdIds = <String>[];
      
      for (var slot in _slots) {
        // Find the next occurrence of this day of the week
        final targetWeekday = _dayOfWeekToInt(slot.dayOfWeek);
        if (targetWeekday == -1) {
          debugPrint("SYNC SKIP: Invalid day '${slot.dayOfWeek}' for slot ${slot.subject}");
          continue;
        }
        
        DateTime baseDate = now;
        while (baseDate.weekday != targetWeekday) {
          baseDate = baseDate.add(const Duration(days: 1));
        }

        // Parse "HH:mm"
        final startTimeParts = slot.startTime.split(':');
        final endTimeParts = slot.endTime.split(':');
        
        final startDateTime = DateTime(
          baseDate.year, baseDate.month, baseDate.day, 
          int.parse(startTimeParts[0]), int.parse(startTimeParts[1])
        );
        
        final endDateTime = DateTime(
          baseDate.year, baseDate.month, baseDate.day, 
          int.parse(endTimeParts[0]), int.parse(endTimeParts[1])
        );

        debugPrint("SYNC: ${slot.dayOfWeek} ${slot.subject} ${slot.startTime}-${slot.endTime} @ ${slot.venue} → $startDateTime to $endDateTime");

        final event = gcal.Event()
          ..summary = slot.subject
          ..location = slot.venue
          ..description = "Auto-synced via Vyoma AI. Do not edit description.\n\n[Vyoma-Timetable]" // Magic tag for deletion
          ..start = gcal.EventDateTime(
            dateTime: startDateTime,
            timeZone: "Asia/Kolkata", // Use localized constant or user timezone later
          )
          ..end = gcal.EventDateTime(
            dateTime: endDateTime,
            timeZone: "Asia/Kolkata",
          );

        // Map day string to Google RRULE format (MO, TU, WE, TH, FR)
        final rruleDay = _dayOfWeekToRRule(slot.dayOfWeek);
        final rrule = ["RRULE:FREQ=WEEKLY;BYDAY=$rruleDay;COUNT=20"]; // Roughly next 5 months
        
        final created = await _calendarService.addEvent(event, recurrence: rrule);
        final createdId = created.id;
        if (createdId != null && createdId.isNotEmpty) {
          createdIds.add(createdId);
        }
      }

      await _saveSyncedEventIds(createdIds);
      debugPrint("Timetable Sync Complete. Google Calendar Updated.");
    } catch (e) {
      debugPrint("Timetable Sync Failed: $e");
    }
  }

  int _dayOfWeekToInt(String day) {
    switch (day.toLowerCase()) {
      case 'monday': return DateTime.monday;
      case 'tuesday': return DateTime.tuesday;
      case 'wednesday': return DateTime.wednesday;
      case 'thursday': return DateTime.thursday;
      case 'friday': return DateTime.friday;
      case 'saturday': return DateTime.saturday;
      case 'sunday': return DateTime.sunday;
      default: return -1;
    }
  }

  String _dayOfWeekToRRule(String day) {
    switch (day.toLowerCase()) {
      case 'monday': return 'MO';
      case 'tuesday': return 'TU';
      case 'wednesday': return 'WE';
      case 'thursday': return 'TH';
      case 'friday': return 'FR';
      case 'saturday': return 'SA';
      case 'sunday': return 'SU';
      default: return 'MO';
    }
  }

  // --- SEEDING FROM IMAGE DATA ---
  Future<void> _seedInitialData() async {
    _slots = [
      // MONDAY
      TimetableSlot(dayOfWeek: "Monday", startTime: "11:05", endTime: "12:00", subject: "TCS 666", venue: "CR 206"),
      TimetableSlot(dayOfWeek: "Monday", startTime: "12:55", endTime: "13:50", subject: "XCS 601 (SV)", venue: "CR 202"),
      TimetableSlot(dayOfWeek: "Monday", startTime: "14:10", endTime: "16:00", subject: "PCS 601", venue: "UBUNTU LAB 2"),
      TimetableSlot(dayOfWeek: "Monday", startTime: "16:00", endTime: "17:50", subject: "PLACEMENTS", venue: "TBD"),

      // TUESDAY
      TimetableSlot(dayOfWeek: "Tuesday", startTime: "08:00", endTime: "08:55", subject: "TCS 601", venue: "LT 302"),
      TimetableSlot(dayOfWeek: "Tuesday", startTime: "08:55", endTime: "09:50", subject: "TCS 611", venue: "ILEARN"),
      TimetableSlot(dayOfWeek: "Tuesday", startTime: "10:10", endTime: "12:00", subject: "TCS 692", venue: "LT 202"),
      TimetableSlot(dayOfWeek: "Tuesday", startTime: "12:00", endTime: "12:55", subject: "TCS 666", venue: "CR 206"),
      TimetableSlot(dayOfWeek: "Tuesday", startTime: "14:10", endTime: "16:00", subject: "TCS 693", venue: "CR 202"),
      TimetableSlot(dayOfWeek: "Tuesday", startTime: "16:00", endTime: "17:50", subject: "PLACEMENTS", venue: "TBD"),

      // WEDNESDAY
      TimetableSlot(dayOfWeek: "Wednesday", startTime: "08:00", endTime: "09:50", subject: "PCS 666", venue: "TCL 4"),
      TimetableSlot(dayOfWeek: "Wednesday", startTime: "10:10", endTime: "12:00", subject: "TCS 692", venue: "LT 202"),
      TimetableSlot(dayOfWeek: "Wednesday", startTime: "12:55", endTime: "13:50", subject: "TCS 601", venue: "LT 301"),
      TimetableSlot(dayOfWeek: "Wednesday", startTime: "14:10", endTime: "16:00", subject: "PCS 601", venue: "LAB 3"),
      TimetableSlot(dayOfWeek: "Wednesday", startTime: "16:00", endTime: "17:50", subject: "PLACEMENTS", venue: "TBD"),

      // THURSDAY
      TimetableSlot(dayOfWeek: "Thursday", startTime: "08:00", endTime: "08:55", subject: "TCS 611", venue: "ILEARN"),
      TimetableSlot(dayOfWeek: "Thursday", startTime: "10:10", endTime: "12:00", subject: "TCS 692", venue: "LT 202"),
      TimetableSlot(dayOfWeek: "Thursday", startTime: "11:05", endTime: "12:55", subject: "XCS 601 (VC)", venue: "CR 206"), // Note: Slight overlap here based on image grid
      TimetableSlot(dayOfWeek: "Thursday", startTime: "14:10", endTime: "15:05", subject: "TCS 693", venue: "CR 104"),
      TimetableSlot(dayOfWeek: "Thursday", startTime: "15:05", endTime: "16:00", subject: "PESE 600", venue: "VENUE 2"),
      TimetableSlot(dayOfWeek: "Thursday", startTime: "16:00", endTime: "17:50", subject: "PLACEMENTS", venue: "TBD"),

      // FRIDAY
      TimetableSlot(dayOfWeek: "Friday", startTime: "08:00", endTime: "08:55", subject: "PCS 693", venue: "TCL 4"),
      TimetableSlot(dayOfWeek: "Friday", startTime: "08:55", endTime: "09:50", subject: "TCS 611", venue: "ILEARN"),
      TimetableSlot(dayOfWeek: "Friday", startTime: "10:10", endTime: "11:05", subject: "TCS 601", venue: "LT 202"),
      TimetableSlot(dayOfWeek: "Friday", startTime: "11:05", endTime: "12:00", subject: "TCS 693", venue: "CR 206"),
      TimetableSlot(dayOfWeek: "Friday", startTime: "12:00", endTime: "12:55", subject: "TCS 666", venue: "CR 206"),
      TimetableSlot(dayOfWeek: "Friday", startTime: "16:00", endTime: "17:50", subject: "PLACEMENTS", venue: "TBD"),

      // SATURDAY/SUNDAY empty
    ];
    await _saveToStorage();
  }
}
