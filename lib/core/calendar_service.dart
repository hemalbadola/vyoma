import 'dart:async';
import 'package:vyoma/agent_debug_log.dart';
import 'package:googleapis/calendar/v3.dart';
import 'package:flutter/foundation.dart';
import 'auth_manager.dart';

class CalendarAuthCooldownException implements Exception {
  final Duration retryAfter;

  const CalendarAuthCooldownException(this.retryAfter);

  @override
  String toString() {
    final mins = retryAfter.inMinutes;
    final secs = retryAfter.inSeconds % 60;
    if (mins > 0) {
      return secs > 0
          ? 'Calendar auth is cooling down. Retry in ${mins}m ${secs}s.'
          : 'Calendar auth is cooling down. Retry in ${mins}m.';
    }
    return 'Calendar auth is cooling down. Retry in a few seconds.';
  }
}

class CalendarService {
  final AuthManager _authManager;
  CalendarApi? _calendarApi;
  String? _calendarTimeZone;

  // Prevent concurrent initialization (race condition guard).
  Completer<void>? _initInFlight;

  // Cooldown: don't retry init if it recently failed (prevents popup spam).
  DateTime? _lastInitFailure;
  static const _initCooldown = Duration(minutes: 5);
  bool _allowInteractiveInit = false;

  Duration? get initCooldownRemaining {
    final failedAt = _lastInitFailure;
    if (failedAt == null) return null;

    final elapsed = DateTime.now().difference(failedAt);
    if (elapsed >= _initCooldown) return null;
    return _initCooldown - elapsed;
  }

  bool get _isInCooldown => initCooldownRemaining != null;

  CalendarService(this._authManager);

  Future<void> _debugLog({
    required String hypothesisId,
    required String location,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    // #region agent log
    await agentDebugNdjsonLog(
      runId: 'pre-fix-1',
      hypothesisId: hypothesisId,
      location: location,
      message: message,
      data: data,
    );
    // #endregion
  }

  /// Whether Google Calendar OAuth is currently active.
  /// True if the calendar API client has been initialized successfully.
  bool get isCalendarAuthed => _calendarApi != null;

  /// Initializes the Calendar API client if not already done.
  /// Has cooldown + concurrency guard to prevent sign-in popup spam.
  Future<void> _ensureInitialized() async {
    if (_calendarApi != null) return;

    // Don't retry if we recently failed.
    if (_isInCooldown) {
      throw CalendarAuthCooldownException(
        initCooldownRemaining ?? _initCooldown,
      );
    }

    // If init is already in flight, wait for it instead of starting another.
    if (_initInFlight != null) {
      return _initInFlight!.future;
    }

    final completer = Completer<void>();
    _initInFlight = completer;

    try {
      final allowInteractive = _allowInteractiveInit;
      _allowInteractiveInit = false;
      _calendarApi = await _authManager.getCalendarApi(
        allowInteractive: allowInteractive,
      );
      _lastInitFailure = null; // Clear cooldown on success.
      completer.complete();
    } on AuthConfigurationException catch (e) {
      await _debugLog(
        hypothesisId: 'H5',
        location: 'calendar_service.dart:_ensureInitialized',
        message: 'Auth config exception during init',
        data: {'error': e.toString()},
      );
      completer.completeError(e);
      rethrow;
    } on AuthCooldownException catch (e) {
      final cooldown = CalendarAuthCooldownException(e.retryAfter);
      completer.completeError(cooldown);
      throw cooldown;
    } catch (e) {
      _lastInitFailure = DateTime.now();
      debugPrint('CalendarService: init failed, cooldown active for 5 min: $e');
      completer.completeError(e);
      rethrow;
    } finally {
      _initInFlight = null;
    }
  }

  /// Invalidate cached client so next call re-authenticates.
  void _invalidateClient() {
    _calendarApi = null;
  }

  Future<void> _handleAuthRuntimeFailure(String reason) async {
    _lastInitFailure = DateTime.now();
    debugPrint(
      'CalendarService: auth runtime failure -> cooldown set: $reason',
    );
    _invalidateClient();
    try {
      await _authManager.signOut();
    } catch (e) {
      debugPrint('CalendarService: signOut during auth failure failed: $e');
    }
  }

  /// Allows an explicit user action (Retry button) to attempt auth immediately.
  void clearInitCooldown() {
    _lastInitFailure = null;
    _allowInteractiveInit = true;
    _authManager.clearAuthCooldown();
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
      return (events.items ?? [])
          .where((e) => e.start?.dateTime != null)
          .toList();
    } on DetailedApiRequestError catch (e) {
      if (e.status == 401 || e.status == 403) {
        debugPrint(
          'CalendarService: 401/403 — invalidating client for re-auth',
        );
        await _handleAuthRuntimeFailure('http_${e.status}');
      }
      rethrow;
    } catch (e) {
      final str = e.toString().toLowerCase();
      if (str.contains('unauthorized') ||
          str.contains('invalid_grant') ||
          str.contains('refresh') ||
          str.contains('invalid_client')) {
        debugPrint(
          'CalendarService: Auth token refresh failed. Forcing re-auth.',
        );
        await _handleAuthRuntimeFailure('token_refresh_failure');
      }
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
    } on DetailedApiRequestError catch (e) {
      if (e.status == 401 || e.status == 403) {
        debugPrint(
          'CalendarService: 401/403 — invalidating client for re-auth',
        );
        await _handleAuthRuntimeFailure('http_${e.status}');
      }
      rethrow;
    } catch (e) {
      final str = e.toString().toLowerCase();
      if (str.contains('unauthorized') ||
          str.contains('invalid_grant') ||
          str.contains('refresh') ||
          str.contains('invalid_client')) {
        debugPrint(
          'CalendarService: Auth token refresh failed. Forcing re-auth.',
        );
        await _handleAuthRuntimeFailure('token_refresh_failure');
      }
      rethrow;
    }
  }

  /// Adds a new event to the primary calendar.
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
  Future<void> _normalizeEventDateTimes(Event event) async {
    final tz = await _getCalendarTimeZone();

    if (event.start?.dateTime != null) {
      final start = event.start!.dateTime!;
      event.start = EventDateTime(
        dateTime: _preserveWallClockTime(start),
        timeZone: tz,
      );
    }
    if (event.end?.dateTime != null) {
      final end = event.end!.dateTime!;
      event.end = EventDateTime(
        dateTime: _preserveWallClockTime(end),
        timeZone: tz,
      );
    }
  }

  DateTime _preserveWallClockTime(DateTime value) {
    final local = value.isUtc ? value.toLocal() : value;
    return DateTime(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
      local.microsecond,
    );
  }

  /// Finds and deletes all Vyoma-generated timetable events.
  Future<void> deleteTimetableEvents() async {
    await _ensureInitialized();
    try {
      final now = DateTime.now().toUtc();
      final events = await _calendarApi!.events.list(
        'primary',
        timeMin: now,
        maxResults: 100,
      );

      final timetableEvents = (events.items ?? []).where((e) {
        return e.description != null &&
            e.description!.contains('[Vyoma-Timetable]');
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
