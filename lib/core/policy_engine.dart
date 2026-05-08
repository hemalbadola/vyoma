// ============================================================
// policy_engine.dart
// Stateless rule evaluator.
// Takes a proposal + context → returns a decision.
// Zero side-effects. Zero network calls. 100% unit-testable.
// ============================================================

import 'package:vyoma/core/models/ai_action_proposal.dart';

// ─────────────────────────────────────────────
// Context passed to every evaluation
// ─────────────────────────────────────────────

/// Snapshot of world-state at the moment of evaluation.
/// Immutable. Built by ChatOrchestrator before calling PolicyEngine.
class PolicyContext {
  const PolicyContext({
    required this.now,
    required this.userId,
    this.existingEventIds = const {},
    this.existingTimetableDays = const {},
    this.recentIdempotencyKeys = const {},
    this.userHasCalendarAccess = false,
  });

  final DateTime now;
  final String userId;

  /// IDs of calendar events the user currently owns. Used to validate
  /// move/delete targets so the AI can't reference phantom events.
  final Set<String> existingEventIds;

  /// Days that have timetable slots (e.g., {'Monday', 'Wednesday'}).
  final Set<String> existingTimetableDays;

  /// Idempotency keys of actions already executed this session.
  /// Any key appearing here is a duplicate → silently skip.
  final Set<String> recentIdempotencyKeys;

  /// Whether Google Calendar OAuth is currently valid.
  final bool userHasCalendarAccess;
}

// ─────────────────────────────────────────────
// Decision
// ─────────────────────────────────────────────

enum PolicyVerdict {
  /// Action is safe to execute immediately.
  allow,

  /// Action is structurally valid but needs explicit UX confirmation before execution.
  requiresConfirmation,

  /// Action is a duplicate — skip silently.
  duplicate,

  /// Action violates a hard rule and must not execute.
  deny,
}

class ActionDecision {
  const ActionDecision({
    required this.action,
    required this.verdict,
    this.reason,
  });

  final AIAction action;
  final PolicyVerdict verdict;

  /// Human-readable rationale. Non-null when verdict is deny or requiresConfirmation.
  final String? reason;

  bool get isExecutable => verdict == PolicyVerdict.allow;
  bool get needsConfirmation => verdict == PolicyVerdict.requiresConfirmation;
  bool get isDuplicate => verdict == PolicyVerdict.duplicate;
  bool get isDenied => verdict == PolicyVerdict.deny;

  @override
  String toString() =>
      'ActionDecision(${action.type.value} → ${verdict.name}: $reason)';
}

class ProposalDecision {
  const ProposalDecision({
    required this.proposal,
    required this.actionDecisions,
    required this.overallVerdict,
  });

  final AIActionProposal proposal;
  final List<ActionDecision> actionDecisions;
  final PolicyVerdict overallVerdict;

  /// Actions cleared for immediate execution (no confirmation needed).
  List<AIAction> get executableActions => actionDecisions
      .where((d) => d.isExecutable)
      .map((d) => d.action)
      .toList();

  /// Actions that need a UX confirmation card before execution.
  List<ActionDecision> get pendingConfirmations =>
      actionDecisions.where((d) => d.needsConfirmation).toList();

  /// Actions that were hard-denied with a reason.
  List<ActionDecision> get deniedActions =>
      actionDecisions.where((d) => d.isDenied).toList();

  bool get hasAnythingToExecute => executableActions.isNotEmpty;
  bool get hasAnythingPending => pendingConfirmations.isNotEmpty;
  bool get hasAnyDenials => deniedActions.isNotEmpty;
}

// ─────────────────────────────────────────────
// The engine
// ─────────────────────────────────────────────

/// Evaluates every action in a proposal against a rule set.
/// Stateless: safe to call from any isolate or test.
abstract interface class PolicyEngine {
  ProposalDecision evaluate(AIActionProposal proposal, PolicyContext context);
}

/// Production implementation with Vyoma's security rules.
///
/// Rule priority (highest first):
///   1. Duplicate guard       — idempotency key already seen → skip
///   2. Schema completeness   — required fields for this action type present
///   3. Temporal sanity       — events not in the past, not >180 days out
///   4. Scope guard           — action targets only user-owned resources
///   5. Destructive escalation — destructive types always require confirmation
///   6. Confidence downgrade   — low-confidence proposals → require confirmation
final class VyomaPolicyEngine implements PolicyEngine {
  const VyomaPolicyEngine();

  @override
  ProposalDecision evaluate(
      AIActionProposal proposal, PolicyContext context) {
    final decisions = <ActionDecision>[];

    for (final action in proposal.actions) {
      decisions.add(_evaluateAction(action, proposal, context));
    }

    // Overall verdict is the most restrictive verdict across all actions.
    final overallVerdict = _reduceVerdicts(
      decisions.map((d) => d.verdict).toList(),
    );

    return ProposalDecision(
      proposal: proposal,
      actionDecisions: decisions,
      overallVerdict: overallVerdict,
    );
  }

  ActionDecision _evaluateAction(
    AIAction action,
    AIActionProposal proposal,
    PolicyContext context,
  ) {
    // ── Rule 1: Duplicate guard ────────────────────────────────
    if (context.recentIdempotencyKeys.contains(action.idempotencyKey)) {
      return ActionDecision(
        action: action,
        verdict: PolicyVerdict.duplicate,
        reason: 'Idempotency key already executed: ${action.idempotencyKey}',
      );
    }

    // ── Rule 2: Schema completeness ───────────────────────────
    final schemaError = _checkSchemaCompleteness(action);
    if (schemaError != null) {
      return ActionDecision(
        action: action,
        verdict: PolicyVerdict.deny,
        reason: schemaError,
      );
    }

    // ── Rule 3: Temporal sanity ───────────────────────────────
    final temporalError = _checkTemporalSanity(action, context.now);
    if (temporalError != null) {
      return ActionDecision(
        action: action,
        verdict: PolicyVerdict.deny,
        reason: temporalError,
      );
    }

    // ── Rule 4: Scope guard ───────────────────────────────────
    final scopeError = _checkScope(action, context);
    if (scopeError != null) {
      return ActionDecision(
        action: action,
        verdict: PolicyVerdict.deny,
        reason: scopeError,
      );
    }

    // ── Rule 5: Destructive escalation ───────────────────────
    if (action.type.isDestructive || proposal.meta.requiresConfirmation) {
      return ActionDecision(
        action: action,
        verdict: PolicyVerdict.requiresConfirmation,
        reason:
            'Destructive action requires explicit user confirmation.',
      );
    }

    // ── Rule 6: Low-confidence downgrade ─────────────────────
    if (proposal.meta.confidence < kAutoExecuteConfidenceThreshold) {
      return ActionDecision(
        action: action,
        verdict: PolicyVerdict.requiresConfirmation,
        reason:
            'AI confidence ${proposal.meta.confidence.toStringAsFixed(2)} '
            'is below auto-execute threshold $kAutoExecuteConfidenceThreshold.',
      );
    }

    return ActionDecision(
      action: action,
      verdict: PolicyVerdict.allow,
    );
  }

  // ── Schema completeness rules ──────────────────────────────

  String? _checkSchemaCompleteness(AIAction action) {
    switch (action.type) {
      case AIActionType.calendarCreate:
        if (action.title == null || action.title!.isEmpty) {
          return 'calendar.create requires a non-empty title.';
        }
        if (action.startTime == null) {
          return 'calendar.create requires a start time.';
        }
        if (action.endTime == null) {
          return 'calendar.create requires an end time.';
        }
        if (!action.endTime!.isAfter(action.startTime!)) {
          return 'end time must be after start time.';
        }

      case AIActionType.calendarMove:
        if (action.targetEventId == null || action.targetEventId!.isEmpty) {
          return 'calendar.move requires target_event_id.';
        }
        if (action.startTime == null) {
          return 'calendar.move requires a new start time.';
        }

      case AIActionType.calendarDelete:
        if (action.targetEventId == null || action.targetEventId!.isEmpty) {
          return 'calendar.delete requires target_event_id.';
        }

      case AIActionType.timetableReplaceDay:
        if (action.weekday == null || action.weekday!.isEmpty) {
          return 'timetable.replace_day requires a weekday.';
        }

      case AIActionType.timetableClearDay:
        if (action.weekday == null || action.weekday!.isEmpty) {
          return 'timetable.clear_day requires a weekday.';
        }

      case AIActionType.reminderCreate:
        if (action.title == null || action.title!.isEmpty) {
          return 'reminder.create requires a title.';
        }
        if (action.startTime == null) {
          return 'reminder.create requires a time.';
        }

      case AIActionType.metricsIncrement:
        // No required fields beyond idempotency_key.
        break;
    }
    return null;
  }

  // ── Temporal sanity rules ──────────────────────────────────

  static const _maxFutureDays = 180;

  String? _checkTemporalSanity(AIAction action, DateTime now) {
    final start = action.startTime;
    if (start == null) return null;

    // Block events scheduled in the past (with 5-minute grace window).
    if (start.isBefore(now.subtract(const Duration(minutes: 5)))) {
      return 'Cannot schedule an event in the past: $start';
    }

    // Block events scheduled more than 180 days out.
    final horizon = now.add(const Duration(days: _maxFutureDays));
    if (start.isAfter(horizon)) {
      return 'Cannot schedule an event more than $_maxFutureDays days out: $start';
    }

    return null;
  }

  // ── Scope guard rules ──────────────────────────────────────

  String? _checkScope(AIAction action, PolicyContext context) {
    // For calendar actions, we check calendar access is available.
    final calendarActions = {
      AIActionType.calendarCreate,
      AIActionType.calendarMove,
      AIActionType.calendarDelete,
    };
    if (calendarActions.contains(action.type) &&
        !context.userHasCalendarAccess) {
      return 'Calendar access is not authorised. Cannot perform ${action.type.value}.';
    }

    // For move/delete: the target event must exist and belong to this user.
    if ((action.type == AIActionType.calendarMove ||
            action.type == AIActionType.calendarDelete) &&
        action.targetEventId != null &&
        !context.existingEventIds.contains(action.targetEventId)) {
      return 'Target event "${action.targetEventId}" not found in user calendar.';
    }

    return null;
  }

  // ── Verdict aggregation ────────────────────────────────────

  PolicyVerdict _reduceVerdicts(List<PolicyVerdict> verdicts) {
    if (verdicts.isEmpty) return PolicyVerdict.allow;
    if (verdicts.contains(PolicyVerdict.deny)) return PolicyVerdict.deny;
    if (verdicts.contains(PolicyVerdict.requiresConfirmation)) {
      return PolicyVerdict.requiresConfirmation;
    }
    if (verdicts.every((v) => v == PolicyVerdict.duplicate)) {
      return PolicyVerdict.duplicate;
    }
    return PolicyVerdict.allow;
  }
}
