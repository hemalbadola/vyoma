import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'memory_service.dart';
import 'models/static_context.dart';
import 'temporal_behavior_store.dart';
import 'temporal_context_builder.dart';
import 'models/ai_action_proposal.dart';
import 'secrets.dart';
import 'supermemory_service.dart';
import 'models/timetable.dart';

// --- DATA MODELS ---

// --- DATA MODELS ---

class ProductivityMetrics {
  final int focusMinutes;
  final int distractionCount;
  final int tasksCompleted;

  ProductivityMetrics({
    required this.focusMinutes,
    required this.distractionCount,
    required this.tasksCompleted,
  });

  factory ProductivityMetrics.initial() => ProductivityMetrics(
    focusMinutes: 0,
    distractionCount: 0,
    tasksCompleted: 0,
  );

  factory ProductivityMetrics.fromJson(Map<String, dynamic> json) {
    return ProductivityMetrics(
      focusMinutes: json['focus_minutes'] ?? 0,
      distractionCount: json['distraction_count'] ?? 0,
      tasksCompleted: json['tasks_completed'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'focus_minutes': focusMinutes,
    'distraction_count': distractionCount,
    'tasks_completed': tasksCompleted,
  };

  @override
  String toString() =>
      '{ "focus": $focusMinutes, "distractions": $distractionCount, "tasks": $tasksCompleted }';
}

class MetricDelta {
  final int focusChange;
  final int distractionChange;
  final int taskChange;
  final String note;

  MetricDelta({
    required this.focusChange,
    this.distractionChange = 0,
    this.taskChange = 0,
    required this.note,
  });

  factory MetricDelta.fromJson(Map<String, dynamic> json) {
    return MetricDelta(
      focusChange: json['focus_change'] ?? 0,
      distractionChange: json['distraction_change'] ?? 0,
      taskChange: json['task_change'] ?? 0,
      note: json['note'] ?? '',
    );
  }
}

class AIResponseAction {
  final String type; // create, move, delete, update_timetable, notify, none
  final String? summary;
  final String? startTime;
  final int? durationMinutes;
  final String? recurrence;
  final String? message;
  final String? notifyAt;
  final List<TimetableSlot>? slots;

  AIResponseAction({
    required this.type,
    this.summary,
    this.startTime,
    this.durationMinutes,
    this.recurrence,
    this.message,
    this.notifyAt,
    this.slots,
  });

  static String _normalizeActionType(String raw) {
    final t = raw.trim().toLowerCase();
    switch (t) {
      case 'schedule':
      case 'add_event':
      case 'addevent':
      case 'create_event':
        return 'create';
      case 'reminder':
        return 'notify';
      case 'update-timetable':
        return 'update_timetable';
      default:
        return t.isEmpty ? 'none' : t;
    }
  }

  static String _inferActionType(Map<String, dynamic> json) {
    final normalized = _normalizeActionType(
      (json['type'] ?? json['action'] ?? '').toString(),
    );
    if (normalized != 'none') return normalized;

    if (json['slots'] is List) return 'update_timetable';
    if (json['notifyAt'] != null ||
        json['notify_at'] != null ||
        json['message'] != null) {
      return 'notify';
    }
    if (json['new_time'] != null || json['time'] != null) return 'move';

    final desc = (json['description'] ?? '').toString().toLowerCase();
    if (RegExp(r'\b(reschedule|move|shift)\b').hasMatch(desc)) return 'move';
    if (RegExp(r'\b(schedule|create|add)\b').hasMatch(desc)) return 'create';
    if (RegExp(r'\b(delete|remove|cancel)\b').hasMatch(desc)) return 'delete';

    return 'none';
  }

  factory AIResponseAction.fromJson(Map<String, dynamic> json) {
    List<TimetableSlot>? parsedSlots;
    if (json['slots'] != null && json['slots'] is List) {
      parsedSlots = (json['slots'] as List)
          .map((e) => TimetableSlot.fromJson(e))
          .toList();
    }

    return AIResponseAction(
      type: _inferActionType(json),
      summary:
          (json['summary'] ??
                  json['subject'] ??
                  json['title'] ??
                  json['name'] ??
                  json['event'])
              ?.toString(),
      startTime:
          (json['startTime'] ??
                  json['start_time'] ??
                  json['start'] ??
                  json['new_time'] ??
                  json['time'])
              ?.toString(),
      durationMinutes: json['durationMinutes'] is int
          ? json['durationMinutes'] as int
          : int.tryParse(
              (json['durationMinutes'] ?? json['duration_minutes'] ?? '')
                  .toString(),
            ),
      recurrence: (json['recurrence'] ?? json['rrule'])?.toString(),
      message: (json['message'] ?? json['body'])?.toString(),
      notifyAt: (json['notifyAt'] ?? json['notify_at'])?.toString(),
      slots: parsedSlots,
    );
  }
}

class MemoryUpdate {
  final String action; // "learn", "forget"
  final String key;
  final String? value;

  MemoryUpdate({required this.action, required this.key, this.value});

  factory MemoryUpdate.fromJson(Map<String, dynamic> json) {
    return MemoryUpdate(
      action: json['action'],
      key: json['key'],
      value: json['value'],
    );
  }
}

class AIResponse {
  final String response;
  final String? thoughtProcess;
  final List<AIResponseAction> actions;
  final MetricDelta? metricDelta;
  final MemoryUpdate? memoryUpdate;

  AIResponse({
    required this.response,
    this.thoughtProcess,
    this.actions = const [],
    this.metricDelta,
    this.memoryUpdate,
  });

  factory AIResponse.error(String message) {
    return AIResponse(response: message, actions: []);
  }

  factory AIResponse.fromJson(Map<String, dynamic> json) {
    var actionsList = <AIResponseAction>[];
    if (json['actions'] != null) {
      actionsList = (json['actions'] as List)
          .map((e) => AIResponseAction.fromJson(e))
          .toList();
    } else if (json['action'] != null) {
      actionsList.add(AIResponseAction.fromJson(json['action']));
    }

    return AIResponse(
      response: json['verbal_response'] ?? json['response'] ?? '...',
      thoughtProcess: json['thought_process'],
      actions: actionsList,
      metricDelta: json['metric_delta'] != null
          ? MetricDelta.fromJson(json['metric_delta'])
          : null,
      memoryUpdate: json['memory_update'] != null
          ? MemoryUpdate.fromJson(json['memory_update'])
          : null,
    );
  }
}

// --- SERVICE ---

class AIService with ChangeNotifier {
  static const int _maxCalendarEventsInPrompt = 8;
  static const int _maxRecentHistoryLogs = 8;
  static const int _maxFactEntries = 16;
  static const int _maxDeferredTasksInPrompt = 5;
  static const int _maxTimelineEntriesInPrompt = 6;
  static const int _maxTimelineTextLen = 90;
  static const int _maxTemporalEventsInPrompt = 10;
  static const String _supermemoryMetaKey = 'supermemory_meta';

  final MemoryService _memory;
  MemoryService get memory => _memory;

  final List<String> _logHistory = [];

  // Getters for UI
  List<String> get logs => List.unmodifiable(_logHistory);
  int get currentGeminiIndex => 0;
  Map<int, String> get keyStates {
    final out = <int, String>{};
    for (var i = 0; i < Secrets.geminiApiKeys.length; i++) {
      out[i] = 'OK';
    }
    return out;
  }

  void setManualGeminiKey(int index) {
    _logDebug('Manual Gemini key switch requested: $index');
  }

  // Time tracking for gap detection
  DateTime? _lastInteractionTime;
  DateTime? get lastInteractionTime => _lastInteractionTime;

  // Supermemory - Long-term Vector Memory
  final SupermemoryService _supermemory = SupermemoryService(
    apiKey: Secrets.supermemoryApiKey,
    projectTag: 'vyoma',
  );
  SupermemoryService get supermemory => _supermemory;

  Map<String, dynamic> get supermemoryDiagnostics {
    final d = _supermemory.diagnostics;
    final meta =
        _memory.getSegment(_supermemoryMetaKey) as Map<String, dynamic>? ?? {};
    return {
      'lastHealthCheckAt': d.lastHealthCheckAt?.toIso8601String(),
      'lastHealthStatusCode': d.lastHealthStatusCode,
      'lastSaveAt': d.lastSaveAt?.toIso8601String(),
      'lastSaveStatusCode': d.lastSaveStatusCode,
      'lastSaveOk': d.lastSaveOk,
      'lastRecallAt': d.lastRecallAt?.toIso8601String(),
      'lastRecallStatusCode': d.lastRecallStatusCode,
      'lastRecallResultCount': d.lastRecallResultCount,
      'lastRecallTopScore': d.lastRecallTopScore,
      'lastProfileAt': d.lastProfileAt?.toIso8601String(),
      'lastProfileStatusCode': d.lastProfileStatusCode,
      'saveSuccessCount': d.saveSuccessCount,
      'saveFailureCount': d.saveFailureCount,
      'recallSuccessCount': d.recallSuccessCount,
      'recallFailureCount': d.recallFailureCount,
      'lastError': d.lastError,
      'lastBehaviorSyncAt': meta['last_behavior_sync_at']?.toString(),
      'lastBehaviorSummaryHash': meta['last_behavior_summary_hash']?.toString(),
    };
  }

  // Debug Stream for UI
  final StreamController<String> _debugStatusController =
      StreamController<String>.broadcast();
  Stream<String> get debugStatusStream => _debugStatusController.stream;

  void _logDebug(String message) {
    debugPrint("AIService: $message");
    _logHistory.add("${DateTime.now().toString().substring(11, 19)} $message");
    if (_logHistory.length > 50) _logHistory.removeAt(0); // Keep last 50
    _debugStatusController.add(message);

    notifyListeners(); // Notify UI of log update
  }

  AIService(this._memory);

  @visibleForTesting
  AIResponse parseXmlForTest(String responseText) {
    return _parseXmlResponse(responseText);
  }

  bool _isMetricManipulationAttempt(String text) {
    final lower = text.toLowerCase();
    final hasMetricWord =
        lower.contains('focus') ||
        lower.contains('distraction') ||
        lower.contains('task') ||
        lower.contains('score') ||
        lower.contains('metrics');

    final hasManipulationVerb =
        lower.contains('set ') ||
        lower.contains('reset') ||
        lower.contains('increase') ||
        lower.contains('decrease') ||
        lower.contains('make it') ||
        lower.contains('change ');

    return hasMetricWord && hasManipulationVerb;
  }

  // ─────────────────────────────────────────────
  // TOOLKIT RESOLUTION
  // Returns the minimal set of AIActionTypes needed for this turn.
  // Only these types will be described in the system prompt schema block.
  // ─────────────────────────────────────────────

  /// Inspects the user's message and the last VYOMA turn to decide which
  /// action types to surface. Returns an empty set for pure-chat turns so
  /// the model isn't tempted to emit actions it doesn't need.
  Set<AIActionType> _resolveActiveToolkit(
    String userText,
    List<Map<String, dynamic>> compactTimeline,
  ) {
    final lower = userText.toLowerCase();
    final toolkit = <AIActionType>{};

    // ── calendar create ──────────────────────────────────────────────────
    if (RegExp(
      r'\b(schedule|plan|add|create|set up|block out|book)\b',
    ).hasMatch(lower)) {
      toolkit.add(AIActionType.calendarCreate);
    }

    // ── calendar move ────────────────────────────────────────────────────
    if (RegExp(
      r'\b(reschedule|move|shift|postpone|push|delay)\b',
    ).hasMatch(lower)) {
      toolkit.add(AIActionType.calendarMove);
    }

    // ── calendar delete ──────────────────────────────────────────────────
    if (RegExp(
      r'\b(delete|remove|cancel|clear)\b',
    ).hasMatch(lower)) {
      toolkit.add(AIActionType.calendarDelete);
    }

    // ── timetable ────────────────────────────────────────────────────────
    if (RegExp(
      r'\b(timetable|class|classes|lecture|lectures|slot|semester|weekly)\b',
    ).hasMatch(lower)) {
      toolkit
        ..add(AIActionType.timetableReplaceDay)
        ..add(AIActionType.timetableClearDay);
    }

    // ── reminder ─────────────────────────────────────────────────────────
    if (RegExp(
      r'\b(remind|reminder|notify|alert|notification|ping)\b',
    ).hasMatch(lower)) {
      toolkit.add(AIActionType.reminderCreate);
    }

    // ── metrics ──────────────────────────────────────────────────────────
    if (RegExp(
      r'\b(focus|distraction|metrics|effort|log|track|record)\b',
    ).hasMatch(lower)) {
      toolkit.add(AIActionType.metricsIncrement);
    }

    // ── confirmation carry-over ───────────────────────────────────────────
    // "do it", "go ahead", "yes" — inherit the toolkit from the last VYOMA
    // message so a one-word confirmation still works correctly.
    final isConfirmation = RegExp(
      r'^\s*(do it|go ahead|yes|yep|yeah|sure|ok|okay|schedule them|add them|do that|please do)\s*[.!]?\s*$',
    ).hasMatch(lower);

    if (isConfirmation && toolkit.isEmpty) {
      for (final item in compactTimeline.reversed) {
        final sender = (item['sender'] ?? '').toString().toUpperCase();
        if (sender != 'VYOMA') continue;
        final text = (item['text'] ?? '').toString().toLowerCase();

        if (RegExp(r'\b(schedule|calendar|event|add)\b').hasMatch(text)) {
          toolkit.add(AIActionType.calendarCreate);
        }
        if (RegExp(r'\b(reschedule|move)\b').hasMatch(text)) {
          toolkit.add(AIActionType.calendarMove);
        }
        if (RegExp(r'\b(delete|cancel|remove)\b').hasMatch(text)) {
          toolkit.add(AIActionType.calendarDelete);
        }
        if (RegExp(r'\b(timetable|class|classes)\b').hasMatch(text)) {
          toolkit
            ..add(AIActionType.timetableReplaceDay)
            ..add(AIActionType.timetableClearDay);
        }
        if (RegExp(r'\b(remind|reminder|notify)\b').hasMatch(text)) {
          toolkit.add(AIActionType.reminderCreate);
        }
        if (toolkit.isNotEmpty) break; // stop at first matching VYOMA turn
      }
    }

    return toolkit;
  }

  // ─────────────────────────────────────────────
  // SCHEMA BLOCK BUILDER
  // Produces only the schema lines for the active toolkit.
  // ─────────────────────────────────────────────

  /// Builds the ACTION TYPES block injected into the system prompt.
  /// Only emits schema lines for [toolkit]. When [toolkit] is empty the
  /// block collapses to a one-liner so the model knows actions are off.
  String _buildActionSchemaBlock(
    Set<AIActionType> toolkit,
    String isoDateExample,
  ) {
    if (toolkit.isEmpty) {
      return 'ACTION TYPES: None available for this turn. Emit actions: [].\n';
    }

    final buf = StringBuffer();
    buf.writeln('ACTION TYPES (inside "actions" array):');
    buf.writeln(
      'Each action MUST have "type" and "idempotency_key" (unique string).',
    );

    if (toolkit.contains(AIActionType.calendarCreate)) {
      buf.writeln(
        '- "calendar.create" — requires: title, start (ISO 8601), end (ISO 8601)',
      );
    }
    if (toolkit.contains(AIActionType.calendarMove)) {
      buf.writeln(
        '- "calendar.move" — requires: target_event_id, start (new ISO 8601), end (new ISO 8601)',
      );
    }
    if (toolkit.contains(AIActionType.calendarDelete)) {
      buf.writeln(
        '- "calendar.delete" — requires: target_event_id',
      );
    }
    if (toolkit.contains(AIActionType.timetableReplaceDay)) {
      buf.writeln(
        '- "timetable.replace_day" — requires: weekday; put slot JSON in notes: '
        '[{"dayOfWeek":"Monday","startTime":"08:00","endTime":"09:00","subject":"Math","venue":"Room"}]',
      );
    }
    if (toolkit.contains(AIActionType.timetableClearDay)) {
      buf.writeln(
        '- "timetable.clear_day" — requires: weekday',
      );
    }
    if (toolkit.contains(AIActionType.reminderCreate)) {
      buf.writeln(
        '- "reminder.create" — requires: title, start (ISO 8601)',
      );
    }
    if (toolkit.contains(AIActionType.metricsIncrement)) {
      buf.writeln(
        '- "metrics.increment" — optional: scope (metric key)',
      );
    }

    buf.writeln(
      '\nAll datetime values MUST be full ISO 8601 (e.g., ${isoDateExample}T14:00:00).',
    );
    return buf.toString();
  }

  String _truncateText(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen)}...';
  }

  String _buildBehaviorPatternSummary() {
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 14));

    final logs = _memory
        .getAllLogs()
        .where((l) => l.timestamp.isAfter(from))
        .toList();

    final journal = _memory
        .getJournalEntries(limit: 40)
        .where((e) => e.timestamp.isAfter(from))
        .toList();

    final deferred = _memory.getDeferredTasks(
      includeCompleted: true,
      limit: 30,
    );

    if (logs.isEmpty && journal.isEmpty && deferred.isEmpty) {
      return 'Insufficient longitudinal data yet.';
    }

    int success = 0;
    int failure = 0;
    final actionTypeCounts = <String, int>{};
    for (final log in logs) {
      if (log.outcome.toLowerCase() == 'success') {
        success++;
      } else {
        failure++;
      }
      final key = log.actionType.trim().isEmpty
          ? 'unknown'
          : log.actionType.trim().toLowerCase();
      actionTypeCounts[key] = (actionTypeCounts[key] ?? 0) + 1;
    }

    final sortedActions = actionTypeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topActions = sortedActions
        .take(3)
        .map((e) => '${e.key}:${e.value}')
        .join(', ');

    final moodCounts = <String, int>{};
    for (final entry in journal) {
      final mood = entry.mood.trim().isEmpty
          ? 'neutral'
          : entry.mood.trim().toLowerCase();
      moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
    }
    final sortedMoods = moodCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topMood = sortedMoods.isNotEmpty ? sortedMoods.first.key : 'unknown';

    int openDeferred = 0;
    int startedDeferred = 0;
    int completedDeferred = 0;
    for (final task in deferred) {
      switch (task.status) {
        case DeferredTaskStatus.open:
          openDeferred++;
          break;
        case DeferredTaskStatus.started:
          startedDeferred++;
          break;
        case DeferredTaskStatus.completed:
          completedDeferred++;
          break;
      }
    }

    final totalOutcomes = success + failure;
    final successRate = totalOutcomes == 0
        ? 0
        : ((success * 100) / totalOutcomes).round();

    return [
      'Window: last 14 days',
      'Execution: success=$success failure=$failure success_rate=$successRate%',
      if (topActions.isNotEmpty) 'Frequent action types: $topActions',
      if (journal.isNotEmpty)
        'Journal trend: dominant_mood=$topMood entries=${journal.length}',
      'Deferred tasks: open=$openDeferred started=$startedDeferred completed=$completedDeferred',
    ].join(' | ');
  }

  Future<void> _syncBehaviorPatternToSupermemory(String summary) async {
    if (summary.trim().isEmpty ||
        summary == 'Insufficient longitudinal data yet.') {
      return;
    }

    final meta =
        _memory.getSegment(_supermemoryMetaKey) as Map<String, dynamic>? ?? {};
    final lastSyncRaw = meta['last_behavior_sync_at']?.toString();
    final lastHash = meta['last_behavior_summary_hash']?.toString();
    final currentHash = summary.hashCode.toString();

    if (lastHash == currentHash) {
      return;
    }

    if (lastSyncRaw != null) {
      final lastSync = DateTime.tryParse(lastSyncRaw);
      if (lastSync != null) {
        final elapsed = DateTime.now().difference(lastSync);
        if (elapsed < const Duration(hours: 24)) {
          return;
        }
      }
    }

    final ok = await _supermemory.saveMemory(
      'Behavior pattern snapshot: $summary',
      tags: ['behavior_pattern', 'weekly_context'],
    );

    if (!ok) return;

    await _memory.updateSegment(_supermemoryMetaKey, {
      ...meta,
      'last_behavior_sync_at': DateTime.now().toIso8601String(),
      'last_behavior_summary_hash': currentHash,
    });
  }

  List<Map<String, dynamic>> _compactTimeline(
    List<Map<String, dynamic>>? timeline,
  ) {
    if (timeline == null || timeline.isEmpty) return const [];

    final start = timeline.length > _maxTimelineEntriesInPrompt
        ? timeline.length - _maxTimelineEntriesInPrompt
        : 0;

    return timeline
        .sublist(start)
        .map(
          (item) => {
            'sender': (item['sender'] ?? '').toString(),
            'text': _truncateText(
              (item['text'] ?? '').toString().replaceAll('\n', ' ').trim(),
              _maxTimelineTextLen,
            ),
            'timestamp': (item['timestamp'] ?? '').toString(),
          },
        )
        .toList();
  }

  Map<String, dynamic> _compactFacts(Map<String, dynamic> facts) {
    if (facts.isEmpty) return const {};
    final compact = <String, dynamic>{};
    int count = 0;
    for (final entry in facts.entries) {
      if (count >= _maxFactEntries) break;
      compact[entry.key] = entry.value;
      count++;
    }
    return compact;
  }

  Map<String, dynamic> _compactTelemetry(Map<String, dynamic> telemetry) {
    if (telemetry.isEmpty) return const {};
    final compact = <String, dynamic>{};
    int count = 0;
    for (final entry in telemetry.entries) {
      if (count >= 16) break;
      final value = entry.value;
      if (value is num || value is bool || value is String) {
        compact[entry.key] = value is String
            ? _truncateText(value, 120)
            : value;
        count++;
      }
    }
    return compact;
  }

  /// Returns the last [limit] temporal behavior events (focus_start, focus_end,
  /// nudge_sent, chat_turn) as plain maps for inclusion in the prompt.
  /// Each entry: { eventType, timestamp, durationSeconds?, taskTitle? }
  List<Map<String, dynamic>> _compactTemporalEvents(
    TemporalBehaviorStore store,
  ) {
    final events = store.recentEvents(_maxTemporalEventsInPrompt);
    return events
        .map(
          (e) => {
            'eventType': e.eventType,
            'timestamp': e.timestamp.toIso8601String(),
            if (e.durationSeconds != null) 'durationSeconds': e.durationSeconds,
            if (e.taskTitle != null && e.taskTitle!.isNotEmpty)
              'taskTitle': _truncateText(e.taskTitle!, 80),
          },
        )
        .toList();
  }

  String _getSystemPrompt(
    ProductivityMetrics metrics, {
    required Set<AIActionType> activeToolkit,
    required String isoDateExample,
  }) {
    final actionSchemaBlock = _buildActionSchemaBlock(activeToolkit, isoDateExample);

    return """
{{VYOMA_PERSONA}}

You are VYOMA, an AI Operator inside a focus and scheduling app for students and young professionals.
Your job is to:
1. Understand what the user is trying to do in the real world.
2. Propose specific, safe actions that the app can execute (calendar events, reminders, timetable updates).
3. Obey the VYOMA_PERSONA voice for user_visible_response (short, true, no filler) while still emitting valid JSON below.

You NEVER directly execute actions. Instead, you emit a JSON object that describes your intent, the actions you suggest, and a natural-language reply to display.
The client validates and executes your proposal only after user approval.

TIME GROUNDING
CURRENT TIMESTAMP: {{CURRENT_TIME}}
DAY OF WEEK: {{DAY_OF_WEEK}}
DATE: {{DATE_FORMATTED}}
ISO DATE: {{DATE_FORMATTED_ISO}}
TIME: {{TIME_FORMATTED}} ({{TIME_PERIOD}})
LAST INTERACTION: {{LAST_INTERACTION}}
TIME GAP: {{TIME_GAP}}
RECENT MESSAGE TIMES: {{RECENT_MESSAGE_TIMES}}

CONTEXT
RHYTHM: Focus {{FOCUS}}m | Diversions {{DISTRACTIONS}}
GOAL: {{GOAL}}
OBSTACLE: {{BLOCKER}}
HOURS: {{WAKE}} -> {{SLEEP}}
ACTIVITY: {{EVIDENCE}}

OUTPUT FORMAT (MANDATORY — respond with ONLY this JSON, no markdown fences, no extra text)
{
  "version": "vyoma-action-v1",
  "intent": "chat.only",
  "user_visible_response": "Your reply to the user here.",
  "actions": [],
  "meta": {
    "confidence": 0.9,
    "requires_confirmation": false
  }
}

ALLOWED INTENTS:
chat.only | schedule.create | schedule.modify | schedule.delete | timetable.update | reminder.set | accountability.pact | metrics.note

$actionSchemaBlock
SAFETY RULES:
1. Be conservative. Fewer precise actions > many fuzzy ones. Max 5 actions.
2. For destructive actions (delete, clear_day), ALWAYS set requires_confirmation: true.
3. If ambiguous, ask a clarifying question and set actions to [].
4. NEVER claim "I have scheduled X" — say "I can schedule X" or "I've prepared a change".
5. Use only provided time fields; never invent prior-day claims.

TONE: Follow VYOMA_PERSONA for user_visible_response. JSON structure is still mandatory.

IMAGE/TIMETABLE EXTRACTION:
- When processing a timetable image, extract ALL slots and place them as timetable.replace_day actions.
- Each slot in notes: [{"dayOfWeek": "Monday", "startTime": "08:00", "endTime": "09:00", "subject": "Math", "venue": "Room"}]
- ALL TIMES MUST BE 24-HOUR FORMAT.

MEMORY: If user says "remember this", include a metrics.increment action with scope="memory" and put the fact in notes.
"""
        .replaceAll("{{FOCUS}}", metrics.focusMinutes.toString())
        .replaceAll("{{DISTRACTIONS}}", metrics.distractionCount.toString());
  }

  List<String> _sanitizeInsightLines(String rawText) {
    final lines = rawText
        .split('\n')
        .map((line) => line.trim())
        .map((line) {
          if (line.startsWith('-') || line.startsWith('*')) {
            return line.substring(1).trim();
          }
          return line;
        })
        .where((line) => line.isNotEmpty)
        .toList();

    final seen = <String>{};
    final cleaned = <String>[];
    for (final line in lines) {
      final normalized = line.toLowerCase();
      if (!seen.contains(normalized)) {
        seen.add(normalized);
        cleaned.add(line);
      }
    }
    return cleaned.take(8).toList();
  }

  /// Extracts deep context insights from a free-form journal entry.
  /// Returns insights without persisting, so UI can support accept/edit/reject review.
  Future<List<String>> extractDeepContextInsights(String journalText) async {
    if (journalText.trim().isEmpty) return [];

    final prompt =
        """
You are an expert psychological profiler and context engine.
Analyze the following journal entry written by the user.

ENTRY:
"$journalText"

Extract only the most critical, enduring insights about the user. Ignore daily noise.
Focus on:
1. Core Beliefs or Identity statements
2. Primary Stressors or Fears
3. Long-Term Aspirations

Output as a clean bulleted list containing only the insights. Do not include introductory text.
""";

    try {
      final responseText = await _callGeminiDirect("", [
        TextPart(prompt),
      ], null);
      final insights = responseText?.trim() ?? "";
      if (insights.isEmpty || insights.length <= 10) return [];
      return _sanitizeInsightLines(insights);
    } catch (e) {
      debugPrint("AIService: Journal Extraction Failed - $e");
      return [];
    }
  }

  /// Parses a free-form journal entry, extracts deep context, and commits to Supermemory.
  Future<List<String>> extractDeepContext(String journalText) async {
    final insights = await extractDeepContextInsights(journalText);
    if (insights.isEmpty) return const [];

    for (final line in insights) {
      await _supermemory.saveMemory(
        "User core context: $line",
        tags: ['journal_insight', 'psychology'],
      );
      _logDebug("Extracted Insight: $line");
    }

    return insights;
  }

  Future<AIResponse> sendMessage(
    String userText,
    List<String> currentEvents,
    ProductivityMetrics metrics,
    StaticContext context,
    Map<String, dynamic> deviceContext, {
    Uint8List? imageBytes,
    List<Map<String, dynamic>>? activityLog,
    List<Map<String, dynamic>>? conversationTimeline,
    String? friendActivitySummary,
  }) async {
    // Compress image once up-front so neither Gemini (HTTPS body cap on the
    // backend gateway) nor NIM (Heroku 30MB / proxy 413) reject it.
    if (imageBytes != null) {
      imageBytes = await _downscaleImageForUpload(imageBytes);
    }

    // Get enabled/disabled segments from memory toggles
    final segToggles = _memory.getSegmentToggles();

    // === SUPERMEMORY: Recall relevant long-term memories (latency-bounded) ===
    List<String> longTermMemories = [];
    String? userProfile;
    final shouldUseSupermemory =
        segToggles['supermemory'] == true &&
        userText.trim().isNotEmpty &&
        userText.trim().length >= 12;

    if (shouldUseSupermemory) {
      try {
        final recallFuture = _supermemory
            .recall(userText, limit: 3)
            .timeout(const Duration(milliseconds: 1400));
        final profileFuture = _supermemory.getUserProfile().timeout(
          const Duration(milliseconds: 900),
        );

        final results = await Future.wait<dynamic>([
          recallFuture,
          profileFuture,
        ], eagerError: false);

        final recalled = (results[0] as List)
            .map((m) => (m as dynamic).content.toString())
            .toList();
        longTermMemories = recalled;
        userProfile = results[1] as String?;
      } catch (e) {
        debugPrint("SUPERMEMORY RECALL ERROR: $e");
      }
    }

    // Retrieve Deep Context
    final protocol =
        _memory.getSegment('protocol') as Map<String, dynamic>? ?? {};
    final prefs =
        _memory.getSegment('preferences') as Map<String, dynamic>? ?? {};

    final goal = protocol['main_goal'] ?? "Unknown";
    final blocker = protocol['main_blocker'] ?? "Distractions";
    final wake = prefs['wake_time'] ?? "07:00";
    final sleep = prefs['sleep_time'] ?? "23:00";

    // Context Content
    final compactTimeline = _compactTimeline(conversationTimeline);
    final compactCurrentEvents = currentEvents
        .take(_maxCalendarEventsI