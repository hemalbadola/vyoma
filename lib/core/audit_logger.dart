// ============================================================
// audit_logger.dart
// Structured, immutable event log for every action outcome.
// Zero side-effects from the rest of the system's perspective.
// ============================================================

import 'package:vyoma/core/models/ai_action_proposal.dart';

// ─────────────────────────────────────────────
// Event model
// ─────────────────────────────────────────────

enum AuditEventType { success, failure, skipped, policyDeny, userConfirmed, userCancelled }

class AuditEvent {
  const AuditEvent({
    required this.type,
    required this.action,
    required this.timestamp,
    this.reason,
    this.artifactId,
    this.error,
  });

  final AuditEventType type;
  final AIAction action;
  final DateTime timestamp;
  final String? reason;
  final String? artifactId;
  final Object? error;

  // ── Factories ──────────────────────────────────────────────

  factory AuditEvent.success({required AIAction action, String? artifactId}) =>
      AuditEvent(
        type: AuditEventType.success,
        action: action,
        timestamp: DateTime.now(),
        artifactId: artifactId,
      );

  factory AuditEvent.failure({required AIAction action, required Object? error}) =>
      AuditEvent(
        type: AuditEventType.failure,
        action: action,
        timestamp: DateTime.now(),
        error: error,
      );

  factory AuditEvent.skipped({required AIAction action, required String reason}) =>
      AuditEvent(
        type: AuditEventType.skipped,
        action: action,
        timestamp: DateTime.now(),
        reason: reason,
      );

  factory AuditEvent.policyDeny({required AIAction action, required String reason}) =>
      AuditEvent(
        type: AuditEventType.policyDeny,
        action: action,
        timestamp: DateTime.now(),
        reason: reason,
      );

  factory AuditEvent.userConfirmed({required AIAction action}) =>
      AuditEvent(
        type: AuditEventType.userConfirmed,
        action: action,
        timestamp: DateTime.now(),
      );

  factory AuditEvent.userCancelled({required AIAction action}) =>
      AuditEvent(
        type: AuditEventType.userCancelled,
        action: action,
        timestamp: DateTime.now(),
      );

  // ── Serialisation ──────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'action_type': action.type.value,
        'idempotency_key': action.idempotencyKey,
        'title': action.title,
        'timestamp': timestamp.toIso8601String(),
        if (reason != null) 'reason': reason,
        if (artifactId != null) 'artifact_id': artifactId,
        if (error != null) 'error': error.toString(),
      };

  @override
  String toString() =>
      '[AUDIT] ${type.name.toUpperCase()} '
      '${action.type.value} '
      '${action.idempotencyKey} '
      '@ ${timestamp.toIso8601String()}';
}

// ─────────────────────────────────────────────
// Logger interface
// ─────────────────────────────────────────────

/// Records every action outcome. Implementations decide where events go:
/// in-memory (tests), local file (dev), remote analytics (production).
abstract interface class AuditLogger {
  Future<void> record(AuditEvent event);

  /// Returns all events in chronological order.
  /// Used by the in-app "History" view.
  List<AuditEvent> get history;

  /// Clear old events. Called with a retention window on app startup.
  void prune({required DateTime keepAfter});
}

// ─────────────────────────────────────────────
// In-memory logger (default / test)
// ─────────────────────────────────────────────

final class InMemoryAuditLogger implements AuditLogger {
  InMemoryAuditLogger({this.onEvent});

  final List<AuditEvent> _events = [];

  /// Optional sink — in production, wire this to Firebase Analytics or Crashlytics.
  final void Function(AuditEvent)? onEvent;

  @override
  Future<void> record(AuditEvent event) async {
    _events.add(event);
    // Always print in debug — structured, greppable format.
    assert(() {
      // ignore: avoid_print
      print(event.toString());
      return true;
    }());
    onEvent?.call(event);
  }

  @override
  List<AuditEvent> get history => List.unmodifiable(_events);

  @override
  void prune({required DateTime keepAfter}) {
    _events.removeWhere((e) => e.timestamp.isBefore(keepAfter));
  }

  /// Convenience: return only events of a specific type.
  List<AuditEvent> where(AuditEventType type) =>
      _events.where((e) => e.type == type).toList();

  /// Convenience: count failures in a rolling window.
  int failureCount({Duration window = const Duration(hours: 1)}) {
    final since = DateTime.now().subtract(window);
    return _events
        .where((e) =>
            e.type == AuditEventType.failure &&
            e.timestamp.isAfter(since))
        .length;
  }
}
