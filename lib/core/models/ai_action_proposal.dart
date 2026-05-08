// ============================================================
// ai_action_proposal.dart
// Versioned contract between the AI model and the app.
// The model ALWAYS returns this shape. Nothing else is trusted.
// ============================================================

/// Bump this when the protocol changes in a breaking way.
/// The parser rejects any response whose version doesn't match.
const kProtocolVersion = 'vyoma-action-v1';

// ─────────────────────────────────────────────
// Top-level proposal
// ─────────────────────────────────────────────

/// The parsed, typed representation of one AI response.
/// Everything downstream works with this object — never with raw strings.
class AIActionProposal {
  const AIActionProposal({
    required this.version,
    required this.intent,
    required this.userVisibleResponse,
    required this.actions,
    required this.meta,
  });

  final String version;
  final AIIntent intent;

  /// The text Vyoma speaks to the user. Always present, even for pure-action responses.
  final String userVisibleResponse;

  /// Zero or more actions the app MAY execute after PolicyEngine approval.
  final List<AIAction> actions;

  final ProposalMeta meta;

  // ── Deserialisation ─────────────────────────────────────────

  factory AIActionProposal.fromJson(Map<String, dynamic> json) {
    _assertField(json, 'version');
    _assertField(json, 'intent');
    _assertField(json, 'user_visible_response');
    _assertField(json, 'actions');
    _assertField(json, 'meta');

    final version = json['version'] as String;
    if (version != kProtocolVersion) {
      throw ProtocolVersionException(
        expected: kProtocolVersion,
        received: version,
      );
    }

    final rawActions = json['actions'] as List<dynamic>;
    if (rawActions.length > kMaxActionsPerProposal) {
      throw PolicyViolationException(
        'Proposal contains ${rawActions.length} actions; '
        'max allowed is $kMaxActionsPerProposal.',
      );
    }

    return AIActionProposal(
      version: version,
      intent: AIIntent.fromString(json['intent'] as String),
      userVisibleResponse: json['user_visible_response'] as String,
      actions: rawActions
          .map((e) => AIAction.fromJson(e as Map<String, dynamic>))
          .toList(),
      meta: ProposalMeta.fromJson(json['meta'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'intent': intent.value,
        'user_visible_response': userVisibleResponse,
        'actions': actions.map((a) => a.toJson()).toList(),
        'meta': meta.toJson(),
      };

  /// True when the proposal carries no executable actions.
  bool get isChatOnly =>
      intent == AIIntent.chatOnly || actions.isEmpty;

  /// True when at least one action is destructive and needs explicit UX confirmation.
  bool get requiresConfirmation =>
      meta.requiresConfirmation ||
      actions.any((a) => a.type.isDestructive);

  static void _assertField(Map<String, dynamic> json, String key) {
    if (!json.containsKey(key)) {
      throw MalformedProposalException('Missing required field: "$key"');
    }
  }

  @override
  String toString() =>
      'AIActionProposal(intent=${intent.value}, actions=${actions.length}, '
      'requiresConfirmation=$requiresConfirmation)';
}

// ─────────────────────────────────────────────
// Intent enum
// ─────────────────────────────────────────────

/// The semantic category of what the AI wants to do.
/// Adding a new intent here forces you to handle it in PolicyEngine
/// and ExecutionEngine — by design.
enum AIIntent {
  chatOnly('chat.only'),
  scheduleCreate('schedule.create'),
  scheduleModify('schedule.modify'),
  scheduleDelete('schedule.delete'),
  timetableUpdate('timetable.update'),
  reminderSet('reminder.set'),
  accountabilityPact('accountability.pact'),
  metricsNote('metrics.note');

  const AIIntent(this.value);
  final String value;

  static AIIntent fromString(String raw) {
    return AIIntent.values.firstWhere(
      (e) => e.value == raw,
      orElse: () => throw MalformedProposalException(
        'Unknown intent: "$raw". '
        'Allowed values: ${AIIntent.values.map((e) => e.value).join(', ')}',
      ),
    );
  }

  bool get isDestructive =>
      this == AIIntent.scheduleDelete || this == AIIntent.timetableUpdate;
}

// ─────────────────────────────────────────────
// Action type enum
// ─────────────────────────────────────────────

enum AIActionType {
  calendarCreate('calendar.create'),
  calendarMove('calendar.move'),
  calendarDelete('calendar.delete'),
  timetableReplaceDay('timetable.replace_day'),
  timetableClearDay('timetable.clear_day'),
  reminderCreate('reminder.create'),
  metricsIncrement('metrics.increment');

  const AIActionType(this.value);
  final String value;

  static AIActionType fromString(String raw) {
    return AIActionType.values.firstWhere(
      (e) => e.value == raw,
      orElse: () => throw MalformedProposalException(
        'Unknown action type: "$raw". '
        'Allowed types: ${AIActionType.values.map((e) => e.value).join(', ')}',
      ),
    );
  }

  bool get isDestructive =>
      this == AIActionType.calendarDelete ||
      this == AIActionType.timetableClearDay;
}

// ─────────────────────────────────────────────
// Individual action
// ─────────────────────────────────────────────

/// One atomic mutation the app may perform.
/// All fields are validated at parse time — nothing reaches PolicyEngine
/// in an ambiguous state.
class AIAction {
  const AIAction({
    required this.type,
    required this.idempotencyKey,
    this.title,
    this.startTime,
    this.endTime,
    this.weekday,
    this.scope,
    this.notes,
    this.targetEventId,
  });

  final AIActionType type;

  /// UUID-like string generated by the model. Used by ExecutionEngine to
  /// prevent duplicate execution on retry.
  final String idempotencyKey;

  final String? title;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? weekday; // e.g., 'Monday'
  final String? scope;   // e.g., 'user_calendar_only'
  final String? notes;

  /// For move/delete: the ID of the event to modify.
  final String? targetEventId;

  factory AIAction.fromJson(Map<String, dynamic> json) {
    _assertField(json, 'type');
    _assertField(json, 'idempotency_key');

    final key = json['idempotency_key'] as String;
    if (key.isEmpty) {
      throw MalformedProposalException('idempotency_key must not be empty.');
    }

    return AIAction(
      type: AIActionType.fromString(json['type'] as String),
      idempotencyKey: key,
      title: json['title'] as String?,
      startTime: _parseDateTime(json['start']),
      endTime: _parseDateTime(json['end']),
      weekday: json['weekday'] as String?,
      scope: json['scope'] as String?,
      notes: json['notes'] as String?,
      targetEventId: json['target_event_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.value,
        'idempotency_key': idempotencyKey,
        if (title != null) 'title': title,
        if (startTime != null) 'start': startTime!.toIso8601String(),
        if (endTime != null) 'end': endTime!.toIso8601String(),
        if (weekday != null) 'weekday': weekday,
        if (scope != null) 'scope': scope,
        if (notes != null) 'notes': notes,
        if (targetEventId != null) 'target_event_id': targetEventId,
      };

  static void _assertField(Map<String, dynamic> json, String key) {
    if (!json.containsKey(key)) {
      throw MalformedProposalException('Action missing required field: "$key"');
    }
  }

  static DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is! String) {
      throw MalformedProposalException(
          'Expected ISO-8601 string for datetime, got: $raw');
    }
    final dt = DateTime.tryParse(raw);
    if (dt == null) {
      throw MalformedProposalException(
          'Could not parse datetime: "$raw". Expected ISO-8601.');
    }
    return dt;
  }

  @override
  String toString() =>
      'AIAction(type=${type.value}, key=$idempotencyKey, title=$title)';
}

// ─────────────────────────────────────────────
// Proposal metadata
// ─────────────────────────────────────────────

class ProposalMeta {
  const ProposalMeta({
    required this.confidence,
    required this.requiresConfirmation,
  });

  /// Model's self-reported confidence [0.0 – 1.0].
  /// PolicyEngine may downgrade to requires_confirmation when < 0.7.
  final double confidence;
  final bool requiresConfirmation;

  factory ProposalMeta.fromJson(Map<String, dynamic> json) {
    final confidence = (json['confidence'] as num?)?.toDouble() ?? 0.5;
    if (confidence < 0.0 || confidence > 1.0) {
      throw MalformedProposalException(
          'Confidence must be in [0.0, 1.0]; got $confidence');
    }
    return ProposalMeta(
      confidence: confidence,
      requiresConfirmation: (json['requires_confirmation'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'confidence': confidence,
        'requires_confirmation': requiresConfirmation,
      };
}

// ─────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────

/// Hard cap on actions per proposal. Prevents bulk-destroy attacks.
const kMaxActionsPerProposal = 5;

/// Minimum confidence for auto-execution without additional confirmation.
const kAutoExecuteConfidenceThreshold = 0.85;

// ─────────────────────────────────────────────
// Exceptions
// ─────────────────────────────────────────────

/// Base class for all protocol-layer failures.
sealed class VyomaProtocolException implements Exception {
  const VyomaProtocolException(this.message);
  final String message;
  @override
  String toString() => '$runtimeType: $message';
}

/// The model returned a response with the wrong protocol version.
final class ProtocolVersionException extends VyomaProtocolException {
  const ProtocolVersionException({
    required this.expected,
    required this.received,
  }) : super(
            'Protocol version mismatch. Expected "$expected", got "$received". '
            'Update the system prompt or bump kProtocolVersion.');
  final String expected;
  final String received;
}

/// A required field is absent or has an invalid type.
final class MalformedProposalException extends VyomaProtocolException {
  const MalformedProposalException(String message) : super(message);
}

/// A policy rule rejected the proposal before execution.
final class PolicyViolationException extends VyomaProtocolException {
  const PolicyViolationException(String message) : super(message);
}
