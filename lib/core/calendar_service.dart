import 'package:googleapis/calendar/v3.dart';
import 'package:flutter/foundation.dart';
import 'auth_manager.dart';

class CalendarService {
  final AuthManager _authManager;
  CalendarApi? _calendarApi;
  String? _calendarTimeZone;

  CalendarService(this._authManager);

  /// Initializes the Calendar API client if not already done.
  Future<void> _ensureInitialized() async {
    if (_calendarApi != null) return;
    _calendarApi = await _authManager.getCalendarApi();
  }

  Future<String?> _getCalendarTimeZone() async {
    await _ensureInitialized();
    if (_calendarTimeZone != null) return _calendarTimeZone;

    try {
      final setting = await _calendarApi!.settings.get('timezone');
      final value = setting.value;
      _calendarTimeZone = (value == null || value.isEmpty) ? null : value;
    } catch (_) {
      _calendarTimeZone = null;
    }

    _calendarTimeZone ??= _guessLocalIanaTimeZone();
    return _calendarTimeZone;
  }

  String _guessLocalIanaTimeZone() {
    final offset = DateTime.now().timeZoneOffset;
    final minutes = offset.inMinutes;

    // Targeted fallback map for common offsets; includes IST.
    if (minutes == 330) return 'Asia/Kolkata';
    if (minutes == 0) return 'UTC';
    if (minutes == 60) return 'Europe/Berlin';
    if (minutes == 120) return 'Europe/Athens';
    if (minutes == 240) return 'Asia/Dubai';
    if (minutes == 480) return 'Asia/Singapore';
    if (minutes == 540) return 'Asia/Tokyo';
    if (minutes == -300) return 'America/New_York';
    if (minutes == -360) return 'America/Chicago';
    if (minutes == -420) return 'America/Denver';
    if (minutes == -480) return 'America/Los_Angeles';

    return 'UTC';
  }

  /// Fetches the list of upcoming events from the user's primary calendar.
  /// 
  /// [maxResults] defaults to 10.
  Future<List<Event>> syncEvents({int maxResults = 10}) async {
    await _ensureInitialized();
    try {
      final now = DateTime.now().toUtc();
      final events = await _calendarApi!.events.list(
        'primary',
        timeMin: now,
        maxResults: maxResults,
        singleEvents: true,
        orderBy: 'startTime',
      );
      // Filter out all-day events (where dateTime is null)
      return (events.items ?? [])
          .where((e) => e.start?.dateTime != null)
          .toList();
    } catch (e) {
      // Allow the error to propagate so the UI can handle it (e.g., trigger auth flow recovery)
      rethrow;
    }
  }

  /// Fetches events in a specific time window.
  Future<List<Event>> syncEventsInRange({
    required DateTime timeMin,
    required DateTime timeMax,
    int maxResults = 250,
  }) async {
    await _ensureInitialized();
    try {
      final events = await _calendarApi!.events.list(
        'primary',
        timeMin: timeMin.toUtc(),
        timeMax: timeMax.toUtc(),
        maxResults: maxResults,
        singleEvents: true,
        orderBy: 'startTime',
      );

      return (events.items ?? [])
          .where((e) => e.start?.dateTime != null)
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Adds a new event to the primary calendar.
  /// [recurrence] should be a list of RRULE strings, e.g. ["RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR"]
  Future<Event> addEvent(Event event, {List<String>? recurrence}) async {
    await _ensureInitialized();

    if (recurrence != null) {
      event.recurrence = recurrence;
    }

    await _normalizeEventDateTimes(event);
    return await _calendarApi!.events.insert(event, 'primary');
  }

  /// Deletes an event by its ID.
  Future<void> deleteEvent(String eventId) async {
    await _ensureInitialized();
    await _calendarApi!.events.delete('primary', eventId);
  }

  /// Updates an existing event.
  Future<Event> updateEvent(String eventId, Event event) async {
    await _ensureInitialized();
    await _normalizeEventDateTimes(event);
    return await _calendarApi!.events.patch(event, 'primary', eventId);
  }

  /// Preserve local wall-clock times when writing to Calendar.
  /// This avoids hour-offset drift on refresh in timezone-aware regions.
  Future<void> _normalizeEventDateTimes(Event event) async {
    final tz = await _getCalendarTimeZone();

    if (event.start?.dateTime != null) {
      final start = event.start!.dateTime!;
      event.start = EventDateTime(
        dateTime: _wallClockToInstant(start, tz),
        timeZone: tz,
      );
    }
    if (event.end?.dateTime != null) {
      final end = event.end!.dateTime!;
      event.end = EventDateTime(
        dateTime: _wallClockToInstant(end, tz),
        timeZone: tz,
      );
    }
  }

  DateTime _wallClockToInstant(DateTime wallClock, String? timeZone) {
    final local = wallClock.isUtc ? wallClock.toLocal() : wallClock;
    final offsetMinutes = _offsetMinutesForTimeZone(timeZone);

    // Build wall-clock timestamp then translate into the target timezone instant.
    return DateTime.utc(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
      local.microsecond,
    ).subtract(Duration(minutes: offsetMinutes));
  }

  int _offsetMinutesForTimeZone(String? timeZone) {
    switch (timeZone) {
      case 'UTC':
        return 0;
      case 'Asia/Kolkata':
        return 330;
      case 'Europe/Berlin':
        return 60;
      case 'Europe/Athens':
        return 120;
      case 'Asia/Dubai':
        return 240;
      case 'Asia/Singapore':
        return 480;
      case 'Asia/Tokyo':
        return 540;
      case 'America/New_York':
        return -300;
      case 'America/Chicago':
        return -360;
      case 'America/Denver':
        return -420;
      case 'America/Los_Angeles':
        return -480;
      default:
        return DateTime.now().timeZoneOffset.inMinutes;
    }
  }

  /// Finds and deletes all Vyoma-generated timetable events.
  Future<void> deleteTimetableEvents() async {
    await _ensureInitialized();
    try {
      final now = DateTime.now().toUtc();
      final events = await _calendarApi!.events.list(
        'primary',
        timeMin: now,
        maxResults: 100, // Reasonable max for clearing a semester's timetable events
      );

      final timetableEvents = (events.items ?? []).where((e) {
        return e.description != null && e.description!.contains('[Vyoma-Timetable]');
      }).toList();

      for (var event in timetableEvents) {
        if (event.id != null) {
          try {
            await _calendarApi!.events.delete('primary', event.id!);
          } catch (e) {
            debugPrint("Failed to delete old timetable event ${event.id}: $e");
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching timetable events to delete: $e");
      rethrow;
    }
  }
}
