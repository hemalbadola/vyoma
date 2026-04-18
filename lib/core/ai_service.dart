import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'memory_service.dart';
import 'models/static_context.dart';
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
        json['message'] != null)
      return 'notify';
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
  static const int _maxRecentHistoryLogs = 4;
  static const int _maxFactEntries = 16;
  static const int _maxDeferredTasksInPrompt = 5;
  static const int _maxTimelineEntriesInPrompt = 6;
  static const int _maxTimelineTextLen = 90;
  static const String _supermemoryMetaKey = 'supermemory_meta';

  final MemoryService _memory;
  MemoryService get memory => _memory;

  final List<String> _logHistory = [];

  // Getters for UI
  List<String> get logs => List.unmodifiable(_logHistory);

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

  AIService(this._memory) {}

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

  bool _needsCalendarActionSchema(
    String userText,
    List<Map<String, dynamic>> compactTimeline,
  ) {
    final lower = userText.toLowerCase();
    final explicit = RegExp(
      r'\b(schedule|plan|calendar|event|remind|reminder|notify|timetable|reschedule|delete|move|add|create|class|classes|slot)\b',
    ).hasMatch(lower);
    if (explicit) return true;

    final confirmation = RegExp(
      r'\b(do it|go ahead|yes|yep|yeah|schedule them|add them|do that|please do)\b',
    ).hasMatch(lower);
    if (!confirmation) return false;

    for (final item in compactTimeline.reversed) {
      final sender = (item['sender'] ?? '').toString().toUpperCase();
      final text = (item['text'] ?? '').toString().toLowerCase();
      if (sender != 'VYOMA') continue;
      if (RegExp(
        r'\b(schedule|scheduled|calendar|event|class|classes|timetable|reminder)\b',
      ).hasMatch(text)) {
        return true;
      }
    }
    return false;
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
        'Journal trend: dominant_mood=$topMood entries=$journal.length',
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

  String _getSystemPrompt(
    ProductivityMetrics metrics, {
    required bool includeCalendarSchema,
  }) {
    final calendarSection = includeCalendarSchema
        ? """

CALENDAR ACTIONS
- Only use <actions> when user explicitly asks to schedule/edit reminders/events/timetable.
- Allowed action types: create, move, delete, notify, update_timetable.
- create.startTime and notify.notifyAt must be ISO like {{DATE_FORMATTED_ISO}}THH:mm:ss.
- update_timetable requires slots with keys: dayOfWeek, startTime, endTime, subject, venue. ALL TIMES MUST BE 24-HOUR FORMAT (e.g., 14:10 not 02:10, 13:50 not 01:50).
- CRITICAL: <actions> MUST contain ONLY a valid JSON array. Do not use Markdown bullet points or list formatting inside the <actions> tag.
"""
        : """

CALENDAR ACTIONS
- Default: <actions> should be [] unless user explicitly asks for scheduling/reminders/events.
""";

    return """
IDENTITY
You are Vyoma: calm, direct, and practical. You prioritize execution over motivational talk.

TIME GROUNDING
CURRENT TIMESTAMP: {{CURRENT_TIME}}
DAY OF WEEK: {{DAY_OF_WEEK}}
DATE: {{DATE_FORMATTED}}
TIME: {{TIME_FORMATTED}} ({{TIME_PERIOD}})
LAST INTERACTION: {{LAST_INTERACTION}}
TIME GAP: {{TIME_GAP}}
RECENT MESSAGE TIMES: {{RECENT_MESSAGE_TIMES}}

RULES
- Use only provided time fields; never invent prior-day claims.
- If evidence is missing, say so briefly and ask one clarifying question.
- Do not mirror explicit/insulting phrasing; reframe neutrally.
- Keep replies concise and non-repetitive.

CONTEXT
TODAY'S RHYTHM: Focus {{FOCUS}}m | Diversions {{DISTRACTIONS}}
USER'S GOAL: {{GOAL}}
CURRENT OBSTACLE: {{BLOCKER}}
OPERATING HOURS: {{WAKE}} -> {{SLEEP}}
RECENT ACTIVITY: {{EVIDENCE}}
$calendarSection

OUTPUT FORMAT (STRICT XML TAGS)
Return exactly these tags (no markdown code fences):
<thought>...(1-2 sentences MAX. NEVER put extracted data here.)</thought>
<verbal>...(short response to user)</verbal>
<actions>[{"type": "update_timetable", "slots": [{"dayOfWeek": "Monday", "startTime": "08:00", "endTime": "09:00", "subject": "Math", "venue": "Room"}]}]</actions>
<metric_delta>{"focus_change":0,"distraction_change":0,"task_change":0,"note":""}</metric_delta>
<memory_update>null</memory_update>

CRITICAL RULES FOR IMAGE/TIMETABLE EXTRACTION:
- NEVER dump extracted data into <thought>. Keep <thought> to 1-2 sentences.
- ALL extracted schedule data MUST go directly into <actions> as a JSON array.
- When processing an image of a timetable, output the slots immediately in <actions>. Do NOT plan or describe what you see in <thought>.

MEMORY_UPDATE RULE
- Use null by default.
- Populate only if user explicitly says "remember this".
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
    String? temporalContext,
    String? friendActivitySummary,
  }) async {
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
        .take(_maxCalendarEventsInPrompt)
        .toList();
    final compactRelevantLogs = _memory
        .getRelevantHistory("")
        .take(_maxRecentHistoryLogs)
        .map((e) => e.toJson())
        .toList();
    final compactDeferredTasks = _memory
        .getDeferredTasks(limit: _maxDeferredTasksInPrompt)
        .map(
          (t) => {
            'description': _truncateText(t.description, 120),
            'promisedFor': t.promisedFor,
            'status': t.status.name,
            'createdAt': t.createdAt.toIso8601String(),
          },
        )
        .toList();

    final behaviorPatternSummary = _buildBehaviorPatternSummary();
    unawaited(_syncBehaviorPatternToSupermemory(behaviorPatternSummary));

    final Map<String, dynamic> dataInput = {
      "user_input": userText,
      "user_profile": {
        "name": "User",
        "main_goal": context.mainGoal,
        "metrics": metrics.toJson(),
        // Only include if segment is enabled
        if (segToggles['identity'] == true)
          "identity": _memory.getSegment('identity'),
        if (segToggles['preferences'] == true) "preferences": prefs,
        if (segToggles['protocol'] == true) "protocol": protocol,
        if (segToggles['facts'] == true)
          "facts": _compactFacts(_memory.getFacts()),
      },
      "agent_memory": {
        if (segToggles['history'] == true) "recent_logs": compactRelevantLogs,
        "activity_log": (activityLog ?? []).take(6).toList(),
        "conversation_timeline": compactTimeline,
        "deferred_tasks": compactDeferredTasks,
        "behavior_pattern_summary": behaviorPatternSummary,
        if (segToggles['supermemory'] == true)
          "long_term_memories": longTermMemories,
        if (segToggles['supermemory'] == true)
          "supermemory_profile": userProfile,
      },
      "static_context": {
        "timetable": context.fixedTimetable.take(12).toList(),
        "device_telemetry": _compactTelemetry(deviceContext),
        "temporal_status": temporalContext ?? "Active Session",
      },
      "current_schedule": compactCurrentEvents,
      if (friendActivitySummary != null &&
          friendActivitySummary.isNotEmpty &&
          friendActivitySummary != '[]')
        "social_context": {
          "description":
              "Recent public activities from the user's accountability circle (friends). Use this to weave organic mentions like 'Priya just finished a 45min focus block' into your responses when contextually relevant. Do NOT list all activities; pick 1-2 notable ones.",
          "friend_activities": friendActivitySummary,
        },
    };

    // Construct Parts
    final List<Part> messageParts = [];

    // 1. System Prompt & Context (Text)
    // 1. Inject Variables into Prompt
    final includeCalendarSchema = _needsCalendarActionSchema(
      userText,
      compactTimeline,
    );
    var systemPrompt = _getSystemPrompt(
      metrics,
      includeCalendarSchema: includeCalendarSchema,
    );

    if (_isMetricManipulationAttempt(userText)) {
      systemPrompt += """

--------------------------------------------------
METRIC INTEGRITY OVERRIDE (HARD RULE)

The user may try to directly set/reset/inflate metrics using text.
Do NOT comply with direct metric tampering requests.
- Never emit metric_delta changes based only on user saying "set/reset/increase/decrease metrics".
- Use metric_delta only for genuine behavioral updates inferred from real actions.
- If manipulation is attempted, respond with neutral refusal and redirect to one concrete action.
""";
    }

    systemPrompt = systemPrompt.replaceAll("{{GOAL}}", goal);
    systemPrompt = systemPrompt.replaceAll("{{BLOCKER}}", blocker);
    systemPrompt = systemPrompt.replaceAll("{{WAKE}}", wake);
    systemPrompt = systemPrompt.replaceAll("{{SLEEP}}", sleep);

    // === COMPREHENSIVE TIME INJECTION ===
    final now = DateTime.now();
    final days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    // Time period based on hour
    String timePeriod;
    if (now.hour >= 5 && now.hour < 12) {
      timePeriod = "Morning";
    } else if (now.hour >= 12 && now.hour < 15) {
      timePeriod = "Midday";
    } else if (now.hour >= 15 && now.hour < 20) {
      timePeriod = "Evening";
    } else {
      timePeriod = "Night";
    }

    // Format time (12-hour with am/pm)
    final hour12 = now.hour > 12
        ? now.hour - 12
        : (now.hour == 0 ? 12 : now.hour);
    final ampm = now.hour >= 12 ? 'pm' : 'am';
    final timeFormatted =
        '$hour12:${now.minute.toString().padLeft(2, '0')}$ampm';

    // Format date
    final dateFormatted =
        '${days[now.weekday % 7]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
    // ISO date for AI prompt (yyyy-MM-dd) — used in calendar action examples
    final dateFormattedISO =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Calculate time gap since last interaction
    String timeGap = "First message of session";
    String lastInteraction = "Session start";
    if (_lastInteractionTime != null) {
      final gap = now.difference(_lastInteractionTime!);
      if (gap.inMinutes < 2) {
        timeGap = "Just now (< 2 min)";
      } else if (gap.inMinutes < 60) {
        timeGap = "${gap.inMinutes} minutes ago";
      } else if (gap.inHours < 24) {
        final hrs = gap.inHours;
        final mins = gap.inMinutes % 60;
        timeGap =
            "$hrs hour${hrs > 1 ? 's' : ''}${mins > 0 ? ' $mins min' : ''} ago";
      } else {
        timeGap = "${gap.inDays} day${gap.inDays > 1 ? 's' : ''} ago";
      }
      // Format last interaction time
      final lastHour12 = _lastInteractionTime!.hour > 12
          ? _lastInteractionTime!.hour - 12
          : (_lastInteractionTime!.hour == 0 ? 12 : _lastInteractionTime!.hour);
      final lastAmpm = _lastInteractionTime!.hour >= 12 ? 'pm' : 'am';
      lastInteraction =
          '$lastHour12:${_lastInteractionTime!.minute.toString().padLeft(2, '0')}$lastAmpm';
    }

    // Build readable recent message timeline for stronger temporal grounding.
    String recentMessageTimes = "No prior non-system messages.";
    if (compactTimeline.isNotEmpty) {
      final lines = <String>[];
      for (final item in compactTimeline) {
        final sender = (item['sender'] ?? 'UNK').toString();
        final text = (item['text'] ?? '')
            .toString()
            .replaceAll('\n', ' ')
            .trim();
        final snippet = text.length > 80 ? '${text.substring(0, 80)}...' : text;
        final rawTs = item['timestamp']?.toString() ?? '';

        String formattedTs = rawTs;
        try {
          final ts = DateTime.parse(rawTs).toLocal();
          formattedTs =
              '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')} ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}';
        } catch (_) {}

        lines.add('[$formattedTs] $sender: $snippet');
      }
      recentMessageTimes = lines.join('\n');
    }

    // Inject all time variables
    final currentTimestamp =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    systemPrompt = systemPrompt.replaceAll(
      "{{CURRENT_TIME}}",
      currentTimestamp,
    );
    systemPrompt = systemPrompt.replaceAll(
      "{{DAY_OF_WEEK}}",
      days[now.weekday % 7],
    );
    systemPrompt = systemPrompt.replaceAll("{{DATE_FORMATTED}}", dateFormatted);
    systemPrompt = systemPrompt.replaceAll(
      "{{DATE_FORMATTED_ISO}}",
      dateFormattedISO,
    );
    systemPrompt = systemPrompt.replaceAll("{{TIME_FORMATTED}}", timeFormatted);
    systemPrompt = systemPrompt.replaceAll("{{TIME_PERIOD}}", timePeriod);
    systemPrompt = systemPrompt.replaceAll(
      "{{LAST_INTERACTION}}",
      lastInteraction,
    );
    systemPrompt = systemPrompt.replaceAll("{{TIME_GAP}}", timeGap);
    systemPrompt = systemPrompt.replaceAll(
      "{{RECENT_MESSAGE_TIMES}}",
      recentMessageTimes,
    );

    // Update last interaction time for next message
    _lastInteractionTime = now;

    // Inject Evidence into Prompt Text for stronger visibility
    String evidenceStr = (activityLog != null && activityLog.isNotEmpty)
        ? jsonEncode(activityLog)
        : "NO RECENT ACTIVITY RECORDED.";
    systemPrompt = systemPrompt.replaceAll("{{EVIDENCE}}", evidenceStr);

    final contextJson = jsonEncode(dataInput);
    _logDebug(
      'Prompt/context size chars -> prompt: ${systemPrompt.length}, context: ${contextJson.length}',
    );

    messageParts.add(
      TextPart("SYSTEM_PROMPT: $systemPrompt\n\nCONTEXT_DATA: $contextJson"),
    );

    // 2. Image (if present) - add BEFORE user question for proper vision processing
    if (imageBytes != null) {
      // Gemini expects 'image/jpeg' or 'image/png'. Assuming png/jpeg from picker.
      messageParts.add(DataPart('image/jpeg', imageBytes));
      // Add user's question about the image explicitly
      messageParts.add(
        TextPart(
          "USER QUESTION ABOUT THIS IMAGE: $userText\n\nDescribe what you see in this image and respond to the user's question.",
        ),
      );
    } else {
      // No image, just add user input
      messageParts.add(TextPart("USER_INPUT: $userText"));
    }

    // 0. VISION HIGHJACK: If image exists, prioritize Gemini
    if (imageBytes != null) {
      _logDebug(
        "Image detected! Prioritizing Gemini 2.5 Flash for superior vision.",
      );
      final geminiRes = await _attemptGeminiRequest(messageParts, imageBytes);
      if (geminiRes != null) return geminiRes;

      _logDebug("Gemini Vision failed! Falling back to NIM Llama Vision.");
    }

    // 1. Try Nvidia NIM (PRIMARY)
    try {
      _logDebug("Trying Nvidia NIM...");
      final textPrompt =
          "SYSTEM_PROMPT: $systemPrompt\n\nCONTEXT_DATA: $contextJson\n\nUSER_INPUT: $userText";
      final response = await _callNvidia(
        textPrompt,
        "",
        imageBytes: imageBytes,
      );

      final parsed = _parseXmlResponse(response);
      if (_streamTokenCallback != null) {
        for (final word in parsed.response.split(' ')) {
          _streamTokenCallback!('$word ');
          await Future.delayed(const Duration(milliseconds: 18));
        }
      }
      return parsed;
    } catch (e) {
      debugPrint("Nvidia Error: $e");
      _logDebug("NVIDIA ERROR: $e");
    }

    _logDebug("NVIDIA FAILED. ENGAGING GROK FALLBACK.");

    // 2. Try Grok (SECONDARY)
    try {
      _logDebug("Trying Grok...");
      final textPrompt =
          "SYSTEM_PROMPT: $systemPrompt\n\nCONTEXT_DATA: $contextJson\n\nUSER_INPUT: $userText";
      final response = await _callGrok(textPrompt, "", imageBytes: imageBytes);

      final parsed = _parseXmlResponse(response);
      if (_streamTokenCallback != null) {
        for (final word in parsed.response.split(' ')) {
          _streamTokenCallback!('$word ');
          await Future.delayed(const Duration(milliseconds: 18));
        }
      }
      return parsed;
    } catch (e) {
      debugPrint("Grok Error: $e");
      _logDebug("GROK ERROR: $e");
    }

    _logDebug("GROK FAILED. ENGAGING GEMINI FALLBACK.");

    // 3. Try Gemini (TERTIARY)
    final geminiRes = await _attemptGeminiRequest(messageParts, imageBytes);
    if (geminiRes != null) return geminiRes;

    return AIResponse(
      response: "ALL SYSTEMS OFFLINE. HQ IS UNREACHABLE.",
      actions: [],
    );
  }

  Future<AIResponse?> _attemptGeminiRequest(
    List<Part> messageParts,
    Uint8List? imageBytes,
  ) async {
    try {
      _logDebug("Trying Gemini backend...");

      final response = await _callGeminiDirect("", messageParts, imageBytes)
          .timeout(
            const Duration(seconds: 45),
            onTimeout: () {
              throw Exception('Gemini request timeout');
            },
          );

      if (response != null) {
        _logDebug("Gemini Request SUCCESS");

        final parsed = _parseXmlResponse(response);
        if (_streamTokenCallback != null) {
          for (final word in parsed.response.split(' ')) {
            _streamTokenCallback!('$word ');
            await Future.delayed(const Duration(milliseconds: 18));
          }
        }
        return parsed;
      }
    } catch (e) {
      _logDebug("Gemini Error: $e");
    }
    return null;
  }

  Future<String?> _callGeminiDirect(
    String apiKey,
    List<Part> messageParts,
    Uint8List? imageBytes,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not authenticated");
    final idToken = await user.getIdToken();

    final url = Uri.parse(
      'https://vyoma-api-backend-9629c91b8aad.herokuapp.com/api/gemini/generate',
    );

    // Build parts for JSON request
    final List<Map<String, dynamic>> parts = [];

    for (final part in messageParts) {
      if (part is TextPart) {
        parts.add({'text': part.text});
      } else if (part is DataPart) {
        parts.add({
          'inlineData': {
            'mimeType': 'image/jpeg',
            'data': base64Encode(imageBytes!),
          },
        });
      }
    }

    final body = jsonEncode({
      'modelName': 'gemini-2.5-flash',
      'payload': {
        'contents': [
          {'role': 'user', 'parts': parts},
        ],
        'safetySettings': [
          {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_NONE'},
          {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_NONE'},
          {
            'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
            'threshold': 'BLOCK_NONE',
          },
          {
            'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
            'threshold': 'BLOCK_NONE',
          },
        ],
        'generationConfig': {'maxOutputTokens': 16384},
      },
    });

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['candidates'] != null &&
          (data['candidates'] as List).isNotEmpty) {
        final candidate = data['candidates'][0];
        final content = candidate['content'];
        if (content != null &&
            content['parts'] != null &&
            (content['parts'] as List).isNotEmpty) {
          final text = content['parts'][0]['text'];
          return text;
        } else {
          debugPrint("Gemini Empty/Safety Response: ${response.body}");
          throw Exception(
            "Gemini returned no content (Check logs for safety/finishReason)",
          );
        }
      }
    } else {
      final error = jsonDecode(response.body);
      final msg = error['error']?['message'] ?? 'Unknown Gemini API error';
      if (response.statusCode == 503) {
        throw Exception("Gemini Overloaded: $msg");
      }
      throw Exception(msg);
    }
    return null;
  }

  Future<String> _callNvidia(
    String textPrompt,
    String apiKey, {
    Uint8List? imageBytes,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not authenticated");
    final idToken = await user.getIdToken();

    final url = Uri.parse(
      'https://vyoma-api-backend-9629c91b8aad.herokuapp.com/api/nvidia/generate',
    );

    final List<Map<String, dynamic>> messages = [];

    if (imageBytes != null) {
      messages.add({
        'role': 'user',
        'content': [
          {'type': 'text', 'text': textPrompt},
          {
            'type': 'image_url',
            'image_url': {
              'url': 'data:image/jpeg;base64,${base64Encode(imageBytes)}',
            },
          },
        ],
      });
    } else {
      messages.add({'role': 'user', 'content': textPrompt});
    }

    final modelName = imageBytes != null
        ? 'meta/llama-3.2-11b-vision-instruct'
        : 'meta/llama3-70b-instruct';

    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({'model': modelName, 'messages': messages}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      debugPrint(
        "NVIDIA RAW FETCH: ${data['choices'][0]['message']['content']}",
      );
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception(
        'Nvidia Failed [${response.statusCode}]: ${response.body}',
      );
    }
  }

  /// Active streaming callback — non-null when a streaming request is in progress.
  void Function(String token)? _streamTokenCallback;

  Future<String> _callGrok(
    String textPrompt,
    String apiKey, {
    Uint8List? imageBytes,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not authenticated");
    final idToken = await user.getIdToken();

    final url = Uri.parse(
      'https://vyoma-api-backend-9629c91b8aad.herokuapp.com/api/grok/generate',
    );

    final List<Map<String, dynamic>> messages = [];

    if (imageBytes != null) {
      messages.add({
        'role': 'user',
        'content': [
          {'type': 'text', 'text': textPrompt},
          {
            'type': 'image_url',
            'image_url': {
              'url': 'data:image/jpeg;base64,${base64Encode(imageBytes)}',
            },
          },
        ],
      });
    } else {
      messages.add({'role': 'user', 'content': textPrompt});
    }

    final modelCandidates = imageBytes != null
        ? const ['grok-2-vision-1212', 'grok-2-vision-latest']
        : const ['grok-3-mini', 'grok-2-latest', 'grok-beta'];

    String? lastError;

    for (final modelName in modelCandidates) {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'model': modelName, 'messages': messages}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      }

      lastError =
          'Grok Failed [${response.statusCode}] for model $modelName: ${response.body}';

      // Continue to next model only when model is unavailable.
      if (response.statusCode == 400 &&
          response.body.toLowerCase().contains('model not found')) {
        continue;
      }

      throw Exception(lastError);
    }

    throw Exception(lastError ?? 'Grok Failed: No compatible model available.');
  }

  AIResponse _parseXmlResponse(String responseText) {
    debugPrint(
      "--- PARSING AI XML ---\n$responseText\n-----------------------",
    );

    // Helper to extract content between XML tags
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
        if (key.isNotEmpty) {
          out[key] = value;
        }
      }
      return out;
    }

    final verbal =
        extractTag('verbal') ??
        responseText.trim(); // Fallback to raw text if no tag
    final thought = extractTag('thought');

    // Parse Actions
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
        return AIResponseAction(
          type: 'move',
          summary: moveMatch.group(1)?.trim(),
          startTime: moveMatch.group(2)?.trim(),
        );
      }

      final createMatch = RegExp(
        r'(?:schedule|create|add)\s+(.+?)\s+(?:to|at)\s+(\d{1,2}[:.]\d{2}(?:\s*(?:am|pm))?)',
        caseSensitive: false,
      ).firstMatch(cleaned);
      if (createMatch != null) {
        return AIResponseAction(
          type: 'create',
          summary: createMatch.group(1)?.trim(),
          startTime: createMatch.group(2)?.trim(),
        );
      }

      if (RegExp(r'\b(reschedule|move|shift)\b').hasMatch(lower)) {
        final subject = RegExp(
          r'(?:reschedule|move|shift)\s+(.+?)(?:\.|$)',
          caseSensitive: false,
        ).firstMatch(cleaned)?.group(1)?.trim();
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
          dotAll: true,
          caseSensitive: false,
        );
        final selfClosingActionBlock = RegExp(
          r'<(create|schedule|move|delete|notify|update_timetable)([^>]*)\/>',
          dotAll: true,
          caseSensitive: false,
        );

        void appendParsedAction({
          required String rawType,
          required String attrsRaw,
          required String bodyRaw,
        }) {
          final type = AIResponseAction._normalizeActionType(rawType.trim());
          final attrs = parseXmlAttributes(attrsRaw);
          final body = bodyRaw.trim();

          if (type.isEmpty) return;

          final startTime =
              attrs['startTime'] ??
              attrs['start_time'] ??
              extractInnerTag(body, 'startTime');
          final endTime =
              attrs['endTime'] ??
              attrs['end_time'] ??
              extractInnerTag(body, 'endTime');
          final recurrence =
              attrs['recurrence'] ?? extractInnerTag(body, 'recurrence');
          final message = attrs['message'] ?? extractInnerTag(body, 'message');
          final notifyAt =
              attrs['notifyAt'] ??
              attrs['notify_at'] ??
              extractInnerTag(body, 'notifyAt');

          var summary =
              attrs['summary'] ??
              attrs['subject'] ??
              extractInnerTag(body, 'summary') ??
              extractInnerTag(body, 'subject');

          if (summary == null || summary.isEmpty) {
            final plainBody = body.replaceAll(RegExp(r'<[^>]+>'), '').trim();
            if (plainBody.isNotEmpty) {
              summary = plainBody;
            }
          }

          int? durationMinutes;
          final durationRaw =
              attrs['durationMinutes'] ??
              attrs['duration_minutes'] ??
              extractInnerTag(body, 'durationMinutes');
          if (durationRaw != null) {
            durationMinutes = int.tryParse(durationRaw);
          }

          if (durationMinutes == null && startTime != null && endTime != null) {
            final start = DateTime.tryParse(startTime);
            final end = DateTime.tryParse(endTime);
            if (start != null && end != null) {
              final diff = end.difference(start).inMinutes;
              if (diff > 0) durationMinutes = diff;
            }
          }

          actionsList.add(
            AIResponseAction(
              type: type,
              summary: summary,
              startTime: startTime,
              durationMinutes: durationMinutes,
              recurrence: recurrence,
              message: message,
              notifyAt: notifyAt,
            ),
          );
        }

        final matches = actionBlock.allMatches(normalizedActions);
        for (final m in matches) {
          appendParsedAction(
            rawType: m.group(1) ?? '',
            attrsRaw: m.group(2) ?? '',
            bodyRaw: m.group(3) ?? '',
          );
        }

        final selfMatches = selfClosingActionBlock.allMatches(
          normalizedActions,
        );
        for (final m in selfMatches) {
          appendParsedAction(
            rawType: m.group(1) ?? '',
            attrsRaw: m.group(2) ?? '',
            bodyRaw: '',
          );
        }
      }

      if (!looksLikeXmlAction) {
        try {
          final decoded = jsonDecode(normalizedActions);
          if (decoded is List) {
            bool isNakedTimetable = false;
            if (decoded.isNotEmpty && decoded.first is Map) {
              final firstItem = decoded.first as Map;
              if (firstItem.containsKey('dayOfWeek') ||
                  firstItem.containsKey('subject') ||
                  firstItem.containsKey('venue')) {
                isNakedTimetable = true;
              }
            }

            if (isNakedTimetable) {
              actionsList.add(
                AIResponseAction.fromJson({
                  'type': 'update_timetable',
                  'slots': decoded,
                }),
              );
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

      if (actionsList.isEmpty) {
        parseXmlActions();
      }

      if (actionsList.isEmpty) {
        final bracketText = normalizedActions
            .replaceAll('[', ' ')
            .replaceAll(']', ' ')
            .replaceAll('"', ' ')
            .trim();
        final inferred = inferActionFromText(bracketText);
        if (inferred != null) {
          actionsList.add(inferred);
        }
      }
    }

    if (actionsList.isEmpty) {
      final inferredFromVerbal = inferActionFromText(verbal);
      if (inferredFromVerbal != null) {
        actionsList.add(inferredFromVerbal);
      }
    }

    // Parse Metrics
    MetricDelta? metricDelta;
    final metricsStr = extractTag('metric_delta');
    if (metricsStr != null && metricsStr.isNotEmpty) {
      try {
        metricDelta = MetricDelta.fromJson(jsonDecode(metricsStr));
      } catch (e) {
        debugPrint("Failed to parse <metric_delta> JSON: $e");
      }
    }

    // Parse Memory
    MemoryUpdate? memoryUpdate;
    final memoryStr = extractTag('memory_update');
    if (memoryStr != null && memoryStr.isNotEmpty && memoryStr != 'null') {
      try {
        memoryUpdate = MemoryUpdate.fromJson(jsonDecode(memoryStr));
      } catch (e) {
        debugPrint("Failed to parse <memory_update> JSON: $e");
      }
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
