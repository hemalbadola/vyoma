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
  final String type;
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
  final String action;
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

  DateTime? _lastInteractionTime;
  DateTime? get lastInteractionTime => _lastInteractionTime;

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

  final StreamController<String> _debugStatusController =
      StreamController<String>.broadcast();
  Stream<String> get debugStatusStream => _debugStatusController.stream;

  void _logDebug(String message) {
    debugPrint('AIService: $message');
    _logHistory.add('${DateTime.now().toString().substring(11, 19)} $message');
    if (_logHistory.length > 50) _logHistory.removeAt(0);
    _debugStatusController.add(message);
    notifyListeners();
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
  // ─────────────────────────────────────────────

  Set<AIActionType> _resolveActiveToolkit(
    String userText,
    List<Map<String, dynamic>> compactTimeline,
  ) {
    final lower = userText.toLowerCase();
    final toolkit = <AIActionType>{};

    if (RegExp(r'\b(schedule|plan|add|create|set up|block out|book)\b').hasMatch(lower)) {
      toolkit.add(AIActionType.calendarCreate);
    }
    if (RegExp(r'\b(reschedule|move|shift|postpone|push|delay)\b').hasMatch(lower)) {
      toolkit.add(AIActionType.calendarMove);
    }
    if (RegExp(r'\b(delete|remove|cancel|clear)\b').hasMatch(lower)) {
      toolkit.add(AIActionType.calendarDelete);
    }
    if (RegExp(r'\b(timetable|class|classes|lecture|lectures|slot|semester|weekly)\b').hasMatch(lower)) {
      toolkit
        ..add(AIActionType.timetableReplaceDay)
        ..add(AIActionType.timetableClearDay);
    }
    if (RegExp(r'\b(remind|reminder|notify|alert|notification|ping)\b').hasMatch(lower)) {
      toolkit.add(AIActionType.reminderCreate);
    }
    if (RegExp(r'\b(focus|distraction|metrics|effort|log|track|record)\b').hasMatch(lower)) {
      toolkit.add(AIActionType.metricsIncrement);
    }

    final isConfirmation = RegExp(
      r'^\s*(do it|go ahead|yes|yep|yeah|sure|ok|okay|schedule them|add them|do that|please do)\s*[.!]?\s*$',
    ).hasMatch(lower);

    if (isConfirmation && toolkit.isEmpty) {
      for (final item in compactTimeline.reversed) {
        final sender = (item['sender'] ?? '').toString().toUpperCase();
        if (sender != 'VYOMA') continue;
        final text = (item['text'] ?? '').toString().toLowerCase();
        if (RegExp(r'\b(schedule|calendar|event|add)\b').hasMatch(text)) toolkit.add(AIActionType.calendarCreate);
        if (RegExp(r'\b(reschedule|move)\b').hasMatch(text)) toolkit.add(AIActionType.calendarMove);
        if (RegExp(r'\b(delete|cancel|remove)\b').hasMatch(text)) toolkit.add(AIActionType.calendarDelete);
        if (RegExp(r'\b(timetable|class|classes)\b').hasMatch(text)) {
          toolkit
            ..add(AIActionType.timetableReplaceDay)
            ..add(AIActionType.timetableClearDay);
        }
        if (RegExp(r'\b(remind|reminder|notify)\b').hasMatch(text)) toolkit.add(AIActionType.reminderCreate);
        if (toolkit.isNotEmpty) break;
      }
    }

    return toolkit;
  }

  // ─────────────────────────────────────────────
  // SCHEMA BLOCK BUILDER
  // ─────────────────────────────────────────────

  String _buildActionSchemaBlock(Set<AIActionType> toolkit, String isoDateExample) {
    if (toolkit.isEmpty) {
      return 'ACTION TYPES: None available for this turn. Emit actions: [].\n';
    }
    final buf = StringBuffer();
    buf.writeln('ACTION TYPES (inside "actions" array):');
    buf.writeln('Each action MUST have "type" and "idempotency_key" (unique string).');
    if (toolkit.contains(AIActionType.calendarCreate)) {
      buf.writeln('- "calendar.create" — requires: title, start (ISO 8601), end (ISO 8601)');
    }
    if (toolkit.contains(AIActionType.calendarMove)) {
      buf.writeln('- "calendar.move" — requires: target_event_id, start (new ISO 8601), end (new ISO 8601)');
    }
    if (toolkit.contains(AIActionType.calendarDelete)) {
      buf.writeln('- "calendar.delete" — requires: target_event_id');
    }
    if (toolkit.contains(AIActionType.timetableReplaceDay)) {
      buf.writeln('- "timetable.replace_day" — requires: weekday; put slot JSON in notes: [{"dayOfWeek":"Monday","startTime":"08:00","endTime":"09:00","subject":"Math","venue":"Room"}]');
    }
    if (toolkit.contains(AIActionType.timetableClearDay)) {
      buf.writeln('- "timetable.clear_day" — requires: weekday');
    }
    if (toolkit.contains(AIActionType.reminderCreate)) {
      buf.writeln('- "reminder.create" — requires: title, start (ISO 8601)');
    }
    if (toolkit.contains(AIActionType.metricsIncrement)) {
      buf.writeln('- "metrics.increment" — optional: scope (metric key)');
    }
    buf.writeln('\nAll datetime values MUST be full ISO 8601 (e.g., ${isoDateExample}T14:00:00).');
    return buf.toString();
  }

  String _truncateText(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen)}...';
  }

  String _buildBehaviorPatternSummary() {
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 14));
    final logs = _memory.getAllLogs().where((l) => l.timestamp.isAfter(from)).toList();
    final journal = _memory.getJournalEntries(limit: 40).where((e) => e.timestamp.isAfter(from)).toList();
    final deferred = _memory.getDeferredTasks(includeCompleted: true, limit: 30);

    if (logs.isEmpty && journal.isEmpty && deferred.isEmpty) {
      return 'Insufficient longitudinal data yet.';
    }

    int success = 0;
    int failure = 0;
    final actionTypeCounts = <String, int>{};
    for (final log in logs) {
      if (log.outcome.toLowerCase() == 'success') { success++; } else { failure++; }
      final key = log.actionType.trim().isEmpty ? 'unknown' : log.actionType.trim().toLowerCase();
      actionTypeCounts[key] = (actionTypeCounts[key] ?? 0) + 1;
    }
    final sortedActions = actionTypeCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topActions = sortedActions.take(3).map((e) => '${e.key}:${e.value}').join(', ');

    final moodCounts = <String, int>{};
    for (final entry in journal) {
      final mood = entry.mood.trim().isEmpty ? 'neutral' : entry.mood.trim().toLowerCase();
      moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
    }
    final sortedMoods = moodCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topMood = sortedMoods.isNotEmpty ? sortedMoods.first.key : 'unknown';

    int openDeferred = 0, startedDeferred = 0, completedDeferred = 0;
    for (final task in deferred) {
      switch (task.status) {
        case DeferredTaskStatus.open: openDeferred++; break;
        case DeferredTaskStatus.started: startedDeferred++; break;
        case DeferredTaskStatus.completed: completedDeferred++; break;
      }
    }
    final totalOutcomes = success + failure;
    final successRate = totalOutcomes == 0 ? 0 : ((success * 100) / totalOutcomes).round();
    return [
      'Window: last 14 days',
      'Execution: success=$success failure=$failure success_rate=$successRate%',
      if (topActions.isNotEmpty) 'Frequent action types: $topActions',
      if (journal.isNotEmpty) 'Journal trend: dominant_mood=$topMood entries=${journal.length}',
      'Deferred tasks: open=$openDeferred started=$startedDeferred completed=$completedDeferred',
    ].join(' | ');
  }

  Future<void> _syncBehaviorPatternToSupermemory(String summary) async {
    if (summary.trim().isEmpty || summary == 'Insufficient longitudinal data yet.') return;
    final meta = _memory.getSegment(_supermemoryMetaKey) as Map<String, dynamic>? ?? {};
    final lastSyncRaw = meta['last_behavior_sync_at']?.toString();
    final lastHash = meta['last_behavior_summary_hash']?.toString();
    final currentHash = summary.hashCode.toString();
    if (lastHash == currentHash) return;
    if (lastSyncRaw != null) {
      final lastSync = DateTime.tryParse(lastSyncRaw);
      if (lastSync != null && DateTime.now().difference(lastSync) < const Duration(hours: 24)) return;
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

  List<Map<String, dynamic>> _compactTimeline(List<Map<String, dynamic>>? timeline) {
    if (timeline == null || timeline.isEmpty) return const [];
    final start = timeline.length > _maxTimelineEntriesInPrompt
        ? timeline.length - _maxTimelineEntriesInPrompt
        : 0;
    return timeline.sublist(start).map((item) => {
      'sender': (item['sender'] ?? '').toString(),
      'text': _truncateText(
        (item['text'] ?? '').toString().replaceAll('\n', ' ').trim(),
        _maxTimelineTextLen,
      ),
      'timestamp': (item['timestamp'] ?? '').toString(),
    }).toList();
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
        compact[entry.key] = value is String ? _truncateText(value, 120) : value;
        count++;
      }
    }
    return compact;
  }

  List<Map<String, dynamic>> _compactTemporalEvents(TemporalBehaviorStore store) {
    final events = store.recentEvents(_maxTemporalEventsInPrompt);
    return events.map((e) => {
      'eventType': e.eventType,
      'timestamp': e.timestamp.toIso8601String(),
      if (e.durationSeconds != null) 'durationSeconds': e.durationSeconds,
      if (e.taskTitle != null && e.taskTitle!.isNotEmpty)
        'taskTitle': _truncateText(e.taskTitle!, 80),
    }).toList();
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
        .replaceAll('{{FOCUS}}', metrics.focusMinutes.toString())
        .replaceAll('{{DISTRACTIONS}}', metrics.distractionCount.toString());
  }

  List<String> _sanitizeInsightLines(String rawText) {
    final lines = rawText
        .split('\n')
        .map((line) => line.trim())
        .map((line) {
          if (line.startsWith('-') || line.startsWith('*')) return line.substring(1).trim();
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

  Future<List<String>> extractDeepContextInsights(String journalText) async {
    if (journalText.trim().isEmpty) return [];
    final prompt = """
You are an expert psychological profiler and context engine.
Analyze the following journal entry written by the user.

ENTRY:
\"$journalText\"

Extract only the most critical, enduring insights about the user. Ignore daily noise.
Focus on:
1. Core Beliefs or Identity statements
2. Primary Stressors or Fears
3. Long-Term Aspirations

Output as a clean bulleted list containing only the insights. Do not include introductory text.
""";
    try {
      final responseText = await _callGeminiDirect('', [TextPart(prompt)], null);
      final insights = responseText?.trim() ?? '';
      if (insights.isEmpty || insights.length <= 10) return [];
      return _sanitizeInsightLines(insights);
    } catch (e) {
      debugPrint('AIService: Journal Extraction Failed - $e');
      return [];
    }
  }

  Future<List<String>> extractDeepContext(String journalText) async {
    final insights = await extractDeepContextInsights(journalText);
    if (insights.isEmpty) return const [];
    for (final line in insights) {
      await _supermemory.saveMemory('User core context: $line', tags: ['journal_insight', 'psychology']);
      _logDebug('Extracted Insight: $line');
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
    if (imageBytes != null) {
      imageBytes = await _downscaleImageForUpload(imageBytes);
    }

    final segToggles = _memory.getSegmentToggles();

    List<String> longTermMemories = [];
    String? userProfile;
    final shouldUseSupermemory =
        segToggles['supermemory'] == true &&
        userText.trim().isNotEmpty &&
        userText.trim().length >= 12;

    if (shouldUseSupermemory) {
      try {
        final recallFuture = _supermemory.recall(userText, limit: 3).timeout(const Duration(milliseconds: 1400));
        final profileFuture = _supermemory.getUserProfile().timeout(const Duration(milliseconds: 900));
        final results = await Future.wait<dynamic>([recallFuture, profileFuture], eagerError: false);
        longTermMemories = (results[0] as List).map((m) => (m as dynamic).content.toString()).toList();
        userProfile = results[1] as String?;
      } catch (e) {
        debugPrint('SUPERMEMORY RECALL ERROR: $e');
      }
    }

    final protocol = _memory.getSegment('protocol') as Map<String, dynamic>? ?? {};
    final prefs = _memory.getSegment('preferences') as Map<String, dynamic>? ?? {};
    final goal = protocol['main_goal'] ?? 'Unknown';
    final blocker = protocol['main_blocker'] ?? 'Distractions';
    final wake = prefs['wake_time'] ?? '07:00';
    final sleep = prefs['sleep_time'] ?? '23:00';

    final compactTimeline = _compactTimeline(conversationTimeline);
    final compactCurrentEvents = currentEvents.take(_maxCalendarEventsInPrompt).toList();

    final temporalFingerprintStore = TemporalBehaviorStore(_memory);
    final temporalSnapshot = TemporalContextBuilder(_memory).build(
      calendarEventStrings: compactCurrentEvents,
      behaviorStore: temporalFingerprintStore,
      focusMinutesSession: metrics.focusMinutes,
    );

    final compactRelevantLogs = _memory
        .getRelevantHistory('')
        .take(_maxRecentHistoryLogs)
        .map((e) => e.toJson())
        .toList();

    final compactDeferredTasks = _memory
        .getDeferredTasks(limit: _maxDeferredTasksInPrompt)
        .map((t) => {
              'description': _truncateText(t.description, 120),
              'promisedFor': t.promisedFor,
              'status': t.status.name,
              'createdAt': t.createdAt.toIso8601String(),
              if (t.startedAt != null) 'startedAt': t.startedAt!.toIso8601String(),
              if (t.completedAt != null) 'completedAt': t.completedAt!.toIso8601String(),
            })
        .toList();

    final rawPendingDebriefs = _memory.memory['pending_debriefs'];
    final pendingDebriefs = (rawPendingDebriefs is List)
        ? rawPendingDebriefs
            .whereType<Map>()
            .take(6)
            .map((e) => {
                  'title': e['title']?.toString() ?? '',
                  'endTime': e['endTime']?.toString() ?? '',
                })
            .toList()
        : <Map<String, String>>[];

    final compactTemporalEvents = _compactTemporalEvents(temporalFingerprintStore);
    final behaviorPatternSummary = _buildBehaviorPatternSummary();
    unawaited(_syncBehaviorPatternToSupermemory(behaviorPatternSummary));

    final Map<String, dynamic> dataInput = {
      'user_input': userText,
      'user_profile': {
        'name': 'User',
        'main_goal': context.mainGoal,
        'metrics': metrics.toJson(),
        if (segToggles['identity'] == true) 'identity': _memory.getSegment('identity'),
        if (segToggles['preferences'] == true) 'preferences': prefs,
        if (segToggles['protocol'] == true) 'protocol': protocol,
        if (segToggles['facts'] == true) 'facts': _compactFacts(_memory.getFacts()),
      },
      'agent_memory': {
        if (segToggles['history'] == true) 'recent_logs': compactRelevantLogs,
        'activity_log': (activityLog ?? []).take(6).toList(),
        'conversation_timeline': compactTimeline,
        'deferred_tasks': compactDeferredTasks,
        if (pendingDebriefs.isNotEmpty) 'pending_debriefs': pendingDebriefs,
        if (compactTemporalEvents.isNotEmpty) 'temporal_events': compactTemporalEvents,
        'behavior_pattern_summary': behaviorPatternSummary,
        if (segToggles['supermemory'] == true) 'long_term_memories': longTermMemories,
        if (segToggles['supermemory'] == true) 'supermemory_profile': userProfile,
      },
      'static_context': {
        'timetable': context.fixedTimetable.take(12).toList(),
        'device_telemetry': _compactTelemetry(deviceContext),
        'temporal_status': 'Active Session',
        'temporal_live': temporalSnapshot.toInlineBlock(),
      },
      'current_schedule': compactCurrentEvents,
      if (friendActivitySummary != null &&
          friendActivitySummary.isNotEmpty &&
          friendActivitySummary != '[]')
        'social_context': {
          'description':
              'Recent public activities from the user\'s accountability circle (friends). Use this to weave organic mentions like \'Priya just finished a 45min focus block\' into your responses when contextually relevant. Do NOT list all activities; pick 1-2 notable ones.',
          'friend_activities': friendActivitySummary,
        },
    };

    final List<Part> messageParts = [];

    // Resolve toolkit and build system prompt
    final activeToolkit = _resolveActiveToolkit(userText, compactTimeline);
    final now = DateTime.now();
    final days = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

    String timePeriod;
    if (now.hour >= 5 && now.hour < 12) {
      timePeriod = 'Morning';
    } else if (now.hour >= 12 && now.hour < 15) {
      timePeriod = 'Midday';
    } else if (now.hour >= 15 && now.hour < 20) {
      timePeriod = 'Evening';
    } else {
      timePeriod = 'Night';
    }

    final hour12 = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final ampm = now.hour >= 12 ? 'pm' : 'am';
    final timeFormatted = '$hour12:${now.minute.toString().padLeft(2, '0')}$ampm';
    final dateFormatted = '${days[now.weekday % 7]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
    final dateFormattedISO = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    String timeGap = 'First message of session';
    String lastInteraction = 'Session start';
    if (_lastInteractionTime != null) {
      final gap = now.difference(_lastInteractionTime!);
      if (gap.inMinutes < 2) {
        timeGap = 'Just now (< 2 min)';
      } else if (gap.inMinutes < 60) {
        timeGap = '${gap.inMinutes} minutes ago';
      } else if (gap.inHours < 24) {
        final hrs = gap.inHours;
        final mins = gap.inMinutes % 60;
        timeGap = '$hrs hour${hrs > 1 ? 's' : ''}${mins > 0 ? ' $mins min' : ''} ago';
      } else {
        timeGap = '${gap.inDays} day${gap.inDays > 1 ? 's' : ''} ago';
      }
      final lastHour12 = _lastInteractionTime!.hour > 12
          ? _lastInteractionTime!.hour - 12
          : (_lastInteractionTime!.hour == 0 ? 12 : _lastInteractionTime!.hour);
      final lastAmpm = _lastInteractionTime!.hour >= 12 ? 'pm' : 'am';
      lastInteraction = '$lastHour12:${_lastInteractionTime!.minute.toString().padLeft(2, '0')}$lastAmpm';
    }

    String recentMessageTimes = 'No prior non-system messages.';
    if (compactTimeline.isNotEmpty) {
      final lines = <String>[];
      for (final item in compactTimeline) {
        final sender = (item['sender'] ?? 'UNK').toString();
        final text = (item['text'] ?? '').toString().replaceAll('\n', ' ').trim();
        final snippet = text.length > 80 ? '${text.substring(0, 80)}...' : text;
        final rawTs = item['timestamp']?.toString() ?? '';
        String formattedTs = rawTs;
        try {
          final ts = DateTime.parse(rawTs).toLocal();
          formattedTs = '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')} ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}';
        } catch (_) {}
        lines.add('[$formattedTs] $sender: $snippet');
      }
      recentMessageTimes = lines.join('\n');
    }

    final currentTimestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    var systemPrompt = _getSystemPrompt(
      metrics,
      activeToolkit: activeToolkit,
      isoDateExample: dateFormattedISO,
    );

    if (_isMetricManipulationAttempt(userText)) {
      systemPrompt += """

--------------------------------------------------
METRIC INTEGRITY OVERRIDE (HARD RULE)

The user may try to directly set/reset/inflate metrics using text.
Do NOT comply with direct metric tampering requests.
- Never emit metric_delta changes based only on user saying \"set/reset/increase/decrease metrics\".
- Use metric_delta only for genuine behavioral updates inferred from real actions.
- If manipulation is attempted, respond with neutral refusal and redirect to one concrete action.
""";
    }

    systemPrompt = systemPrompt
        .replaceAll('{{GOAL}}', goal)
        .replaceAll('{{BLOCKER}}', blocker)
        .replaceAll('{{WAKE}}', wake)
        .replaceAll('{{SLEEP}}', sleep)
        .replaceAll('{{CURRENT_TIME}}', currentTimestamp)
        .replaceAll('{{DAY_OF_WEEK}}', days[now.weekday % 7])
        .replaceAll('{{DATE_FORMATTED}}', dateFormatted)
        .replaceAll('{{DATE_FORMATTED_ISO}}', dateFormattedISO)
        .replaceAll('{{TIME_FORMATTED}}', timeFormatted)
        .replaceAll('{{TIME_PERIOD}}', timePeriod)
        .replaceAll('{{LAST_INTERACTION}}', lastInteraction)
        .replaceAll('{{TIME_GAP}}', timeGap)
        .replaceAll('{{RECENT_MESSAGE_TIMES}}', recentMessageTimes)
        .replaceAll('{{EVIDENCE}}', (activityLog != null && activityLog.isNotEmpty)
            ? jsonEncode(activityLog)
            : 'NO RECENT ACTIVITY RECORDED.')
        .replaceAll('{{VYOMA_PERSONA}}',
            TemporalContextBuilder(_memory).buildVyomaPersonaBlock(temporalSnapshot));

    _lastInteractionTime = now;

    final contextJson = jsonEncode(dataInput);
    _logDebug(
      'Prompt/context size chars -> prompt: ${systemPrompt.length}, context: ${contextJson.length}, toolkit: ${activeToolkit.map((t) => t.value).toList()}',
    );

    messageParts.add(TextPart('SYSTEM_PROMPT: $systemPrompt\n\nCONTEXT_DATA: $contextJson'));

    if (imageBytes != null) {
      messageParts.add(DataPart('image/jpeg', imageBytes));
      messageParts.add(TextPart('USER QUESTION ABOUT THIS IMAGE: $userText\n\nDescribe what you see in this image and respond to the user\'s question.'));
    } else {
      messageParts.add(TextPart('USER_INPUT: $userText'));
    }

    if (imageBytes != null) {
      _logDebug('Image detected! Prioritizing Gemini 2.5 Flash for superior vision.');
      final geminiRes = await _attemptGeminiRequest(messageParts, imageBytes);
      if (geminiRes != null) return geminiRes;
      _logDebug('Gemini Vision failed! Falling back to NIM Llama Vision.');
    }

    String? nvidiaErr;
    String? geminiErr;

    try {
      _logDebug('Trying Nvidia NIM...');
      final textPrompt = 'SYSTEM_PROMPT: $systemPrompt\n\nCONTEXT_DATA: $contextJson\n\nUSER_INPUT: $userText';
      final response = await _callNvidia(textPrompt, '', imageBytes: imageBytes);
      final parsed = _parseProtocolResponse(response);
      if (_streamTokenCallback != null) {
        for (final word in parsed.response.split(' ')) {
          _streamTokenCallback!('$word ');
          await Future.delayed(const Duration(milliseconds: 18));
        }
      }
      return parsed;
    } catch (e) {
      debugPrint('Nvidia Error: $e');
      _logDebug('NVIDIA ERROR: $e');
      nvidiaErr = e.toString();
    }

    _logDebug('NVIDIA FAILED. ENGAGING GEMINI FALLBACK.');

    final geminiRes = await _attemptGeminiRequest(messageParts, imageBytes, onError: (err) => geminiErr = err);
    if (geminiRes != null) return geminiRes;

    return AIResponse(
      response: _buildAllProvidersFailedMessage(nvidiaErr: nvidiaErr, geminiErr: geminiErr),
      actions: [],
    );
  }

  String _buildAllProvidersFailedMessage({String? nvidiaErr, String? geminiErr}) {
    final reasons = <String>[];
    if (geminiErr != null) {
      final lower = geminiErr.toLowerCase();
      if (lower.contains('api key expired') || lower.contains('api_key_invalid') || lower.contains('invalid api key')) {
        reasons.add('Gemini API key expired — renew it in Google AI Studio.');
      } else if (lower.contains('quota') || lower.contains('429')) {
        reasons.add('Gemini quota exhausted — try again later.');
      } else if (lower.contains('timeout')) {
        reasons.add('Gemini request timed out.');
      } else if (lower.contains('413') || lower.contains('payload too large')) {
        reasons.add('Gemini payload too large — image too big.');
      } else if (lower.contains('http 5') || lower.contains('non-json') || lower.contains('gateway')) {
        reasons.add('Gemini backend gateway error: ${_shortErr(geminiErr)}');
      } else {
        reasons.add('Gemini failed: ${_shortErr(geminiErr)}');
      }
    }
    if (nvidiaErr != null) {
      final lower = nvidiaErr.toLowerCase();
      if (lower.contains('end of life') || lower.contains('410')) {
        reasons.add('Nvidia NIM model retired — update model name.');
      } else if (lower.contains('413') || lower.contains('payload too large')) {
        reasons.add('Nvidia rejected the image — file still too large.');
      } else if (lower.contains('401') || lower.contains('403')) {
        reasons.add('Nvidia NIM unauthorized — check backend API key.');
      } else {
        reasons.add('Nvidia failed: ${_shortErr(nvidiaErr)}');
      }
    }
    if (reasons.isEmpty) return 'ALL SYSTEMS OFFLINE. HQ IS UNREACHABLE.';
    return 'ALL SYSTEMS OFFLINE.\n\n${reasons.join('\n')}';
  }

  String _shortErr(String err) {
    final cleaned = err.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.length > 140 ? '${cleaned.substring(0, 140)}…' : cleaned;
  }

  Future<AIResponse> sendMessageWithStream({
    required String userText,
    required List<String> calendarEvents,
    required ProductivityMetrics metrics,
    required StaticContext staticContext,
    required Map<String, dynamic> deviceTelemetry,
    Uint8List? imageBytes,
    List<Map<String, dynamic>>? conversationTimeline,
    String? friendActivitySummary,
    required void Function(String token) onToken,
  }) async {
    _streamTokenCallback = onToken;
    try {
      return await sendMessage(
        userText,
        calendarEvents,
        metrics,
        staticContext,
        deviceTelemetry,
        imageBytes: imageBytes,
        conversationTimeline: conversationTimeline,
        friendActivitySummary: friendActivitySummary,
      );
    } finally {
      _streamTokenCallback = null;
    }
  }

  void Function(String token)? _streamTokenCallback;

  Future<AIResponse?> _attemptGeminiRequest(
    List<Part> messageParts,
    Uint8List? imageBytes, {
    void Function(String error)? onError,
  }) async {
    try {
      _logDebug('Trying Gemini backend...');
      final response = await _callGeminiDirect('', messageParts, imageBytes).timeout(
        const Duration(seconds: 45),
        onTimeout: () { throw Exception('Gemini request timeout'); },
      );
      if (response != null) {
        _logDebug('Gemini Request SUCCESS');
        final parsed = _parseProtocolResponse(response);
        if (_streamTokenCallback != null) {
          for (final word in parsed.response.split(' ')) {
            _streamTokenCallback!('$word ');
            await Future.delayed(const Duration(milliseconds: 18));
          }
        }
        return parsed;
      }
    } catch (e) {
      _logDebug('Gemini Error: $e');
      onError?.call(e.toString());
    }
    return null;
  }

  Future<String?> _callGeminiDirect(
    String apiKey,
    List<Part> messageParts,
    Uint8List? imageBytes,
  ) async {
    final idToken = await _requireIdToken();
    final url = Uri.parse('https://vyoma-api-backend-9629c91b8aad.herokuapp.com/api/gemini/generate');

    final List<Map<String, dynamic>> parts = [];
    for (final part in messageParts) {
      if (part is TextPart) {
        parts.add({'text': part.text});
      } else if (part is DataPart) {
        parts.add({'inlineData': {'mimeType': 'image/jpeg', 'data': base64Encode(imageBytes!)}});
      }
    }

    final body = jsonEncode({
      'modelName': 'gemini-2.5-flash',
      'payload': {
        'contents': [{'role': 'user', 'parts': parts}],
        'safetySettings': [
          {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_NONE'},
          {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_NONE'},
          {'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'threshold': 'BLOCK_NONE'},
          {'category': 'HARM_CATEGORY_DANGEROUS_CONTENT', 'threshold': 'BLOCK_NONE'},
        ],
        'generationConfig': {'maxOutputTokens': 16384},
      },
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $idToken'},
      body: body,
    );

    if (response.statusCode == 200) {
      final data = _safeJsonDecode(response.body);
      if (data == null) {
        throw Exception('Gemini backend returned non-JSON 200 response (gateway issue): ${_summarizeNonJson(response.body)}');
      }
      if (data['candidates'] != null && (data['candidates'] as List).isNotEmpty) {
        final candidate = data['candidates'][0];
        final content = candidate['content'];
        if (content != null && content['parts'] != null && (content['parts'] as List).isNotEmpty) {
          return content['parts'][0]['text'];
        } else {
          debugPrint('Gemini Empty/Safety Response: ${response.body}');
          throw Exception('Gemini returned no content (Check logs for safety/finishReason)');
        }
      }
    } else {
      final data = _safeJsonDecode(response.body);
      if (data == null) {
        throw Exception('Gemini backend HTTP ${response.statusCode}: ${_summarizeNonJson(response.body)}');
      }
      final msg = data['error'] is String ? data['error'] : data['error']?['message'] ?? 'Unknown Gemini API error';
      if (response.statusCode == 503) throw Exception('Gemini Overloaded: $msg');
      throw Exception(msg);
    }
    return null;
  }

  Map<String, dynamic>? _safeJsonDecode(String body) {
    try {
      final v = jsonDecode(body);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }

  String _summarizeNonJson(String body) {
    final flat = body.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return flat.length > 160 ? '${flat.substring(0, 160)}…' : flat;
  }

  Future<String> _callNvidia(String textPrompt, String apiKey, {Uint8List? imageBytes}) async {
    final idToken = await _requireIdToken();
    final url = Uri.parse('https://vyoma-api-backend-9629c91b8aad.herokuapp.com/api/nvidia/generate');

    final List<Map<String, dynamic>> messages = [];
    if (imageBytes != null) {
      messages.add({
        'role': 'user',
        'content': [
          {'type': 'text', 'text': textPrompt},
          {'type': 'image_url', 'image_url': {'url': 'data:image/jpeg;base64,${base64Encode(imageBytes)}'}},
        ],
      });
    } else {
      messages.add({'role': 'user', 'content': textPrompt});
    }

    final modelName = imageBytes != null ? 'meta/llama-3.2-11b-vision-instruct' : 'meta/llama-3.3-70b-instruct';
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json; charset=utf-8', 'Authorization': 'Bearer $idToken'},
      body: jsonEncode({'model': modelName, 'messages': messages}),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      debugPrint('NVIDIA RAW FETCH: ${data['choices'][0]['message']['content']}');
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('Nvidia Failed [${response.statusCode}]: ${response.body}');
    }
  }

  Future<String> _requireIdToken() async {
    final auth = FirebaseAuth.instance;
    User? user = auth.currentUser;
    if (user == null) {
      try {
        final credential = await auth.signInAnonymously();
        user = credential.user;
      } on FirebaseAuthException catch (e) {
        throw Exception('Authentication unavailable (${e.code}).');
      }
    }
    if (user == null) throw Exception('Authentication unavailable.');
    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) throw Exception('Authentication token unavailable.');
    return token;
  }

  Future<Uint8List> _downscaleImageForUpload(Uint8List bytes) async {
    const int maxDim = 2048;
    const int skipIfUnderBytes = 1500 * 1024;
    if (bytes.length <= skipIfUnderBytes) return bytes;
    try {
      final result = await compute(_decodeResizeEncodeJpeg, {'bytes': bytes, 'maxDim': maxDim, 'quality': 88});
      _logDebug('Image downscaled: ${(bytes.length / 1024).toStringAsFixed(0)}KB → ${(result.length / 1024).toStringAsFixed(0)}KB');
      return result;
    } catch (e) {
      _logDebug('Image downscale failed, sending original: $e');
      return bytes;
    }
  }

  AIResponse _parseProtocolResponse(String responseText) {
    final jsonMatch = RegExp(
      r'\{[\s\S]*"version"[\s\S]*"vyoma-action-v1"[\s\S]*\}',
    ).firstMatch(responseText);
    if (jsonMatch != null) {
      try {
        final jsonStr = jsonMatch.group(0)!;
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        final proposal = AIActionProposal.fromJson(json);
        _logDebug('Protocol v1 parse SUCCESS: ${proposal.intent.value}, ${proposal.actions.length} actions');
        return AIResponse(
          response: proposal.userVisibleResponse,
          actions: proposal.actions.map((a) => AIResponseAction(
            type: _mapActionTypeToLegacy(a.type),
            summary: a.title,
            startTime: a.startTime?.toIso8601String(),
            durationMinutes: a.startTime != null && a.endTime != null
                ? a.endTime!.difference(a.startTime!).inMinutes
                : null,
          )).toList(),
        );
      } on VyomaProtocolException catch (e) {
        _logDebug('Protocol parse error (falling back to XML): $e');
      } catch (e) {
        _logDebug('JSON decode error (falling back to XML): $e');
      }
    }
    return _parseXmlResponse(responseText);
  }

  String _mapActionTypeToLegacy(AIActionType type) {
    switch (type) {
      case AIActionType.calendarCreate: return 'create';
      case AIActionType.calendarMove: return 'move';
      case AIActionType.calendarDelete: return 'delete';
      case AIActionType.timetableReplaceDay: return 'update_timetable';
      case AIActionType.timetableClearDay: return 'delete';
      case AIActionType.reminderCreate: return 'notify';
      case AIActionType.metricsIncrement: return 'none';
    }
  }

  AIActionProposal? tryParseProposal(String responseText) {
    final jsonMatch = RegExp(
      r'\{[\s\S]*"version"[\s\S]*"vyoma-action-v1"[\s\S]*\}',
    ).firstMatch(responseText);
    if (jsonMatch == null) return null;
    try {
      final json = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
      return AIActionProposal.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  AIResponse _parseXmlResponse(String responseText) {
    debugPrint('--- PARSING AI XML ---\n$responseText\n-----------------------');

    String? extractTag(String tag) {
      final regExp = RegExp('<$tag>(.*?)</$tag>', dotAll: true);
      final match = regExp.firstMatch(responseText);
      return match?.group(1)?.trim();
    }

    String? extractInnerTag(String source, String tag) {
      final regExp = RegExp('<$tag>(.*?)</$tag>', dotAll: true);
      final match = regExp.firstMatch(source);
      return match?.group(1)?.trim();
    }

    Map<String, String> parseXmlAttributes(String attrs) {
      final out = <String, String>{};
      final regExp = RegExp(r'(\w+)\s*=\s*"([^"]*)"');
      for (final match in regExp.allMatches(attrs)) {
        final key = (match.group(1) ?? '').trim();
        final value = (match.group(2) ?? '').trim();
        if (key.isNotEmpty) out[key] = value;
      }
      return out;
    }

    final verbal = extractTag('verbal') ?? responseText.trim();
    final thought = extractTag('thought');

    List<AIResponseAction> actionsList = [];
    final actionsStr = extractTag('actions');

    AIResponseAction? inferActionFromText(String text) {
      final cleaned = text.replaceAll('\n', ' ').trim();
      if (cleaned.isEmpty) return null;
      final lower = cleaned.toLowerCase();

      final moveMatch = RegExp(
        r'(?:reschedule|move|shift)\s+(.+?)\s+(?:to|at)\s+(\d{1,2}[:.]\d{2}(?:\s*(?:am|pm))?)',
        caseSensitive: false,
      ).firstMatch(cleaned);
      if (moveMatch != null) {
        return AIResponseAction(type: 'move', summary: moveMatch.group(1)?.trim(), startTime: moveMatch.group(2)?.trim());
      }

      final createMatch = RegExp(
        r'(?:schedule|create|add)\s+(.+?)\s+(?:to|at)\s+(\d{1,2}[:.]\d{2}(?:\s*(?:am|pm))?)',
        caseSensitive: false,
      ).firstMatch(cleaned);
      if (createMatch != null) {
        return AIResponseAction(type: 'create', summary: createMatch.group(1)?.trim(), startTime: createMatch.group(2)?.trim());
      }

      if (RegExp(r'\b(reschedule|move|shift)\b').hasMatch(lower)) {
        final subject = RegExp(r'(?:reschedule|move|shift)\s+(.+?)(?:\.|$)', caseSensitive: false)
            .firstMatch(cleaned)?.group(1)?.trim();
        return AIResponseAction(type: 'move', summary: subject);
      }

      return null;
    }

    if (actionsStr != null && actionsStr.isNotEmpty) {
      final normalizedActions = actionsStr.trim();
      final looksLikeXmlAction = normalizedActions.startsWith('<');

      void parseXmlActions() {
        final actionBlock = RegExp(
          r'<(create|schedule|move|delete|notify|update_timetable)([^>]*)>(.*?)</\1>',
          dotAll: true, caseSensitive: false,
        );
        final selfClosingActionBlock = RegExp(
          r'<(create|schedule|move|delete|notify|update_timetable)([^>]*)/>', dotAll: true, caseSensitive: false,
        );

        void appendParsedAction({required String rawType, required String attrsRaw, required String bodyRaw}) {
          final type = AIResponseAction._normalizeActionType(rawType.trim());
          final attrs = parseXmlAttributes(attrsRaw);
          final body = bodyRaw.trim();
          if (type.isEmpty) return;

          final startTime = attrs['startTime'] ?? attrs['start_time'] ?? extractInnerTag(body, 'startTime');
          final endTime = attrs['endTime'] ?? attrs['end_time'] ?? extractInnerTag(body, 'endTime');
          final recurrence = attrs['recurrence'] ?? extractInnerTag(body, 'recurrence');
          final message = attrs['message'] ?? extractInnerTag(body, 'message');
          final notifyAt = attrs['notifyAt'] ?? attrs['notify_at'] ?? extractInnerTag(body, 'notifyAt');

          var summary = attrs['summary'] ?? attrs['subject'] ?? extractInnerTag(body, 'summary') ?? extractInnerTag(body, 'subject');
          if (summary == null || summary.isEmpty) {
            final plainBody = body.replaceAll(RegExp(r'<[^>]+>'), '').trim();
            if (plainBody.isNotEmpty) summary = plainBody;
          }

          int? durationMinutes;
          final durationRaw = attrs['durationMinutes'] ?? attrs['duration_minutes'] ?? extractInnerTag(body, 'durationMinutes');
          if (durationRaw != null) durationMinutes = int.tryParse(durationRaw);
          if (durationMinutes == null && startTime != null && endTime != null) {
            final start = DateTime.tryParse(startTime);
            final end = DateTime.tryParse(endTime);
            if (start != null && end != null) {
              final diff = end.difference(start).inMinutes;
              if (diff > 0) durationMinutes = diff;
            }
          }

          actionsList.add(AIResponseAction(
            type: type, summary: summary, startTime: startTime,
            durationMinutes: durationMinutes, recurrence: recurrence,
            message: message, notifyAt: notifyAt,
          ));
        }

        for (final m in actionBlock.allMatches(normalizedActions)) {
          appendParsedAction(rawType: m.group(1) ?? '', attrsRaw: m.group(2) ?? '', bodyRaw: m.group(3) ?? '');
        }
        for (final m in selfClosingActionBlock.allMatches(normalizedActions)) {
          appendParsedAction(rawType: m.group(1) ?? '', attrsRaw: m.group(2) ?? '', bodyRaw: '');
        }
      }

      if (!looksLikeXmlAction) {
        try {
          final decoded = jsonDecode(normalizedActions);
          if (decoded is List) {
            bool isNakedTimetable = false;
            if (decoded.isNotEmpty && decoded.first is Map) {
              final firstItem = decoded.first as Map;
              if (firstItem.containsKey('dayOfWeek') || firstItem.containsKey('subject') || firstItem.containsKey('venue')) {
                isNakedTimetable = true;
              }
            }
            if (isNakedTimetable) {
              actionsList.add(AIResponseAction.fromJson({'type': 'update_timetable', 'slots': decoded}));
            } else {
              for (final item in decoded) {
                if (item is Map<String, dynamic>) {
                  actionsList.add(AIResponseAction.fromJson(item));
                } else if (item is String) {
                  final inferred = inferActionFromText(item);
                  if (inferred != null) actionsList.add(inferred);
                }
              }
            }
          } else if (decoded is Map<String, dynamic>) {
            actionsList = [AIResponseAction.fromJson(decoded)];
          }
        } catch (e) {
          debugPrint('Failed to parse <actions> JSON: $e');
        }
      }

      if (actionsList.isEmpty) parseXmlActions();

      if (actionsList.isEmpty) {
        final bracketText = normalizedActions.replaceAll('[', ' ').replaceAll(']', ' ').replaceAll('"', ' ').trim();
        final inferred = inferActionFromText(bracketText);
        if (inferred != null) actionsList.add(inferred);
      }
    }

    if (actionsList.isEmpty) {
      final inferredFromVerbal = inferActionFromText(verbal);
      if (inferredFromVerbal != null) actionsList.add(inferredFromVerbal);
    }

    MetricDelta? metricDelta;
    final metricsStr = extractTag('metric_delta');
    if (metricsStr != null && metricsStr.isNotEmpty) {
      try { metricDelta = MetricDelta.fromJson(jsonDecode(metricsStr)); } catch (e) { debugPrint('Failed to parse <metric_delta> JSON: $e'); }
    }

    MemoryUpdate? memoryUpdate;
    final memoryStr = extractTag('memory_update');
    if (memoryStr != null && memoryStr.isNotEmpty && memoryStr != 'null') {
      try { memoryUpdate = MemoryUpdate.fromJson(jsonDecode(memoryStr)); } catch (e) { debugPrint('Failed to parse <memory_update> JSON: $e'); }
    }

    return AIResponse(
      response: verbal,
      thoughtProcess: thought,
      actions: actionsList,
      metricDelta: metricDelta,
      memoryUpdate: memoryUpdate,
    );
  }
}

/// Top-level isolate function for image resize.
Uint8List _decodeResizeEncodeJpeg(Map<String, dynamic> args) {
  final Uint8List bytes = args['bytes'] as Uint8List;
  final int maxDim = args['maxDim'] as int;
  final int quality = args['quality'] as int;

  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;

  final int longEdge = decoded.width > decoded.height ? decoded.width : decoded.height;
  final img.Image scaled = longEdge > maxDim
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? maxDim : null,
          height: decoded.height > decoded.width ? maxDim : null,
        )
      : decoded;

  return Uint8List.fromList(img.encodeJpg(scaled, quality: quality));
}
