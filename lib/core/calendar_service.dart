import 'package:googleapis/calendar/v3.dart';
import 'auth_manager.dart';

class CalendarService {
  final AuthManager _authManager;
  CalendarApi? _calendarApi;

  CalendarService(this._authManager);

  /// Initializes the Calendar API client if not already done.
  Future<void> _ensureInitialized() async {
    if (_calendarApi != null) return;
    _calendarApi = await _authManager.getCalendarApi();
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

  /// Adds a new event to the primary calendar.
  /// [recurrence] should be a list of RRULE strings, e.g. ["RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR"]
  Future<Event> addEvent(Event event, {List<String>? recurrence}) async {
    await _ensureInitialized();
    
    if (recurrence != null) {
      event.recurrence = recurrence;
    }
    
    return await _calendarApi!.events.insert(event, 'primary');
  }

  /// Deletes an event by its ID.
  Future<void> deleteEvent(String eventId) async {
    await _ensureInitialized();
    await _calendarApi!.events.delete('primary', eventId);
  }
}
