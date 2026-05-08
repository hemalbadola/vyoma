// ============================================================
// executor_adapters.dart
// Thin adapters that plug real Vyoma services into the
// ExecutionEngine's abstract interfaces.
// Each adapter is pure delegation. No logic.
// ============================================================

import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:vyoma/core/calendar_service.dart';
import 'package:vyoma/core/timetable_service.dart';
import 'package:vyoma/core/notification_service.dart';
import 'package:vyoma/core/execution_engine.dart';
import 'package:vyoma/core/models/timetable.dart';

// ─────────────────────────────────────────────
// CalendarExecutorImpl
// ─────────────────────────────────────────────

final class CalendarExecutorImpl implements CalendarExecutor {
  const CalendarExecutorImpl(this._calendar);
  final CalendarService _calendar;

  @override
  Future<String> createEvent({
    required String title,
    required DateTime start,
    required DateTime end,
    String? notes,
  }) async {
    final event = gcal.Event(
      summary: title,
      description: notes,
      start: gcal.EventDateTime(dateTime: start),
      end: gcal.EventDateTime(dateTime: end),
    );
    final created = await _calendar.addEvent(event);
    return created.id ?? 'no-id';
  }

  @override
  Future<void> moveEvent({
    required String eventId,
    required DateTime newStart,
    required DateTime newEnd,
  }) async {
    final patch = gcal.Event(
      start: gcal.EventDateTime(dateTime: newStart),
      end: gcal.EventDateTime(dateTime: newEnd),
    );
    await _calendar.updateEvent(eventId, patch);
  }

  @override
  Future<void> deleteEvent({required String eventId}) async {
    await _calendar.deleteEvent(eventId);
  }
}

// ─────────────────────────────────────────────
// TimetableExecutorImpl
// ─────────────────────────────────────────────

final class TimetableExecutorImpl implements TimetableExecutor {
  const TimetableExecutorImpl(this._timetable);
  final TimetableService _timetable;

  @override
  Future<void> replaceDay({
    required String weekday,
    required List<Map<String, dynamic>> slots,
  }) async {
    final existing = _timetable.slots
        .where((s) => s.dayOfWeek.toLowerCase() != weekday.toLowerCase())
        .toList();
    final newSlots = slots.map((raw) => TimetableSlot.fromJson(raw)).toList();
    await _timetable.updateTimetable([...existing, ...newSlots]);
  }

  @override
  Future<void> clearDay({required String weekday}) async {
    final remaining = _timetable.slots
        .where((s) => s.dayOfWeek.toLowerCase() != weekday.toLowerCase())
        .toList();
    await _timetable.updateTimetable(remaining);
  }
}

// ─────────────────────────────────────────────
// ReminderExecutorImpl
// ─────────────────────────────────────────────

final class ReminderExecutorImpl implements ReminderExecutor {
  const ReminderExecutorImpl(this._notifications);
  final NotificationService _notifications;

  @override
  Future<String> createReminder({
    required String title,
    required DateTime scheduledTime,
    String? notes,
  }) async {
    await _notifications.scheduleInApp(
      title: '⏰ $title',
      body: notes ?? 'Vyoma reminder',
      when: scheduledTime,
      onDispatch: () {},
    );
    return 'reminder_${scheduledTime.millisecondsSinceEpoch}';
  }
}

// ─────────────────────────────────────────────
// MetricsExecutorImpl
//
// Wraps a callback because metrics live in the ViewModel,
// not in a standalone service. The ViewModel passes a closure.
// ─────────────────────────────────────────────

final class MetricsExecutorImpl implements MetricsExecutor {
  const MetricsExecutorImpl(this._onIncrement);

  /// Signature: (String key, int delta) → void
  final Future<void> Function(String key, int delta) _onIncrement;

  @override
  Future<void> incrementMetric({required String key, int delta = 1}) async {
    await _onIncrement(key, delta);
  }
}
