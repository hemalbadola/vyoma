// ============================================================
// execution_engine.dart
// THE ONLY LAYER THAT MUTATES EXTERNAL STATE.
// Nothing else writes to calendar, timetable, or notifications.
// ============================================================

import 'dart:convert';
import 'package:vyoma/core/models/ai_action_proposal.dart';
import 'package:vyoma/core/policy_engine.dart';
import 'package:vyoma/core/audit_logger.dart';

// ─────────────────────────────────────────────
// Execution result
// ─────────────────────────────────────────────

enum ExecutionStatus { success, skipped, failed }

class ActionResult {
  const ActionResult({
    required this.action,
    required this.status,
    this.error,
    this.artifactId,
  });

  final AIAction action;
  final ExecutionStatus status;

  /// Non-null on failure.
  final Object? error;

  /// Non-null on success: the ID of the created/modified resource (e.g., Google Calendar event ID).
  final String? artifactId;

  bool get isSuccess => status == ExecutionStatus.success;
  bool get isFailure => status == ExecutionStatus.failed;

  @override
  String toString() =>
      'ActionResult(${action.type.value}: ${status.name}, artifactId=$artifactId)';
}

/// Summary of one full proposal execution pass.
class ExecutionSummary {
  const ExecutionSummary({
    required this.proposalIntent,
    required this.results,
    required this.executedAt,
  });

  final AIIntent proposalIntent;
  final List<ActionResult> results;
  final DateTime executedAt;

  bool get allSucceeded => results.every((r) => r.isSuccess);
  bool get anyFailed => results.any((r) => r.isFailure);
  int get successCount => results.where((r) => r.isSuccess).length;
  int get failureCount => results.where((r) => r.isFailure).length;
}

// ─────────────────────────────────────────────
// Abstract interfaces for each executor
//
// These are the seams where real services plug in.
// Tests inject fakes. Production injects the real implementations.
// ─────────────────────────────────────────────

abstract interface class CalendarExecutor {
  Future<String> createEvent({
    required String title,
    required DateTime start,
    required DateTime end,
    String? notes,
  });

  Future<void> moveEvent({
    required String eventId,
    required DateTime newStart,
    required DateTime newEnd,
  });

  Future<void> deleteEvent({required String eventId});
}

abstract interface class TimetableExecutor {
  Future<void> replaceDay({
    required String weekday,
    required List<Map<String, dynamic>> slots,
  });

  Future<void> clearDay({required String weekday});
}

abstract interface class ReminderExecutor {
  Future<String> createReminder({
    required String title,
    required DateTime scheduledTime,
    String? notes,
  });
}

abstract interface class MetricsExecutor {
  Future<void> incrementMetric({required String key, int delta = 1});
}

// ─────────────────────────────────────────────
// The engine
// ─────────────────────────────────────────────

/// Accepts a ProposalDecision from PolicyEngine, executes all allowed
/// actions, and records every outcome via AuditLogger.
///
/// Design constraints:
///   - Each action is executed independently. One failure does not abort others.
///   - Duplicate actions (idempotency check already done by PolicyEngine) are
///     recorded as skipped, not re-executed.
///   - On success, the idempotency key is passed back so the caller can persist it.
abstract interface class ExecutionEngine {
  Future<ExecutionSummary> execute(ProposalDecision decision);
}

final class VyomaExecutionEngine implements ExecutionEngine {
  const VyomaExecutionEngine({
    required this.calendar,
    required this.timetable,
    required this.reminders,
    required this.metrics,
    required this.audit,
  });

  final CalendarExecutor calendar;
  final TimetableExecutor timetable;
  final ReminderExecutor reminders;
  final MetricsExecutor metrics;
  final AuditLogger audit;

  @override
  Future<ExecutionSummary> execute(ProposalDecision decision) async {
    final results = <ActionResult>[];

    for (final actionDecision in decision.actionDecisions) {
      if (actionDecision.isDuplicate) {
        results.add(ActionResult(
          action: actionDecision.action,
          status: ExecutionStatus.skipped,
        ));
        await audit.record(AuditEvent.skipped(
          action: actionDecision.action,
          reason: actionDecision.reason ?? 'Duplicate',
        ));
        continue;
      }

      if (!actionDecision.isExecutable) {
        // Pending or denied actions are not executed here.
        // Pending actions are executed by a second pass after user confirms.
        continue;
      }

      final result = await _executeOne(actionDecision.action);
      results.add(result);

      await audit.record(
        result.isSuccess
            ? AuditEvent.success(
                action: actionDecision.action,
                artifactId: result.artifactId,
              )
            : AuditEvent.failure(
                action: actionDecision.action,
                error: result.error,
              ),
      );
    }

    return ExecutionSummary(
      proposalIntent: decision.proposal.intent,
      results: results,
      executedAt: DateTime.now(),
    );
  }

  Future<ActionResult> _executeOne(AIAction action) async {
    try {
      final artifactId = await _dispatch(action);
      return ActionResult(
        action: action,
        status: ExecutionStatus.success,
        artifactId: artifactId,
      );
    } catch (e) {
      return ActionResult(
        action: action,
        status: ExecutionStatus.failed,
        error: e,
      );
    }
  }

  Future<String?> _dispatch(AIAction action) async {
    switch (action.type) {
      // ── Calendar ──────────────────────────────────────────────
      case AIActionType.calendarCreate:
        return await calendar.createEvent(
          title: action.title!,
          start: action.startTime!,
          end: action.endTime!,
          notes: action.notes,
        );

      case AIActionType.calendarMove:
        await calendar.moveEvent(
          eventId: action.targetEventId!,
          newStart: action.startTime!,
          newEnd: action.endTime ?? action.startTime!.add(const Duration(hours: 1)),
        );
        return action.targetEventId;

      case AIActionType.calendarDelete:
        await calendar.deleteEvent(eventId: action.targetEventId!);
        return action.targetEventId;

      // ── Timetable ─────────────────────────────────────────────
      case AIActionType.timetableReplaceDay:
        List<Map<String, dynamic>> parsedSlots = const [];
        if (action.notes != null && action.notes!.isNotEmpty) {
          try {
            final decoded = jsonDecode(action.notes!) as List<dynamic>;
            parsedSlots = decoded
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          } catch (_) {
            // notes is not valid JSON — fall through with empty slots
          }
        }
        await timetable.replaceDay(
          weekday: action.weekday!,
          slots: parsedSlots,
        );
        return null;

      case AIActionType.timetableClearDay:
        await timetable.clearDay(weekday: action.weekday!);
        return null;

      // ── Reminders ─────────────────────────────────────────────
      case AIActionType.reminderCreate:
        return await reminders.createReminder(
          title: action.title!,
          scheduledTime: action.startTime!,
          notes: action.notes,
        );

      // ── Metrics ───────────────────────────────────────────────
      case AIActionType.metricsIncrement:
        await metrics.incrementMetric(
          key: action.scope ?? 'focus_minutes',
          delta: 1,
        );
        return null;
    }
  }
}
