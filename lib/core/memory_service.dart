import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class MemoryService extends ChangeNotifier {
  Map<String, dynamic> _memory = {};
  bool _isInitialized = false;

  Map<String, dynamic> get memory => _memory;
  bool get isInitialized => _isInitialized;

  // Keys
  static const kIdentity = 'identity';
  static const kTimetable = 'timetable';
  static const kPreferences = 'preferences';
  static const kEnabledSegments = 'enabled_segments';
  static const kJournalEntries = 'journal_entries';
  static const kDeferredTasks = 'deferred_tasks';

  // Memory Segment Categories (for AI context)
  static const List<String> memoryCategories = [
    'identity',      // Who the user is
    'facts',         // Learned facts about user
    'preferences',   // Wake/sleep times, settings
    'history',       // Past interactions
    'protocol',      // Goals and blockers
    'supermemory',   // Long-term vector memory
  ];

  /// Check if a memory segment is enabled for AI context
  bool isSegmentEnabled(String segment) {
    final enabled = _memory[kEnabledSegments] as Map<String, dynamic>? ?? {};
    return enabled[segment] ?? true; // Default: all enabled
  }

  /// Toggle a memory segment on/off
  Future<void> toggleSegment(String segment, bool enabled) async {
    final segments = _memory[kEnabledSegments] as Map<String, dynamic>? ?? {};
    segments[segment] = enabled;
    _memory[kEnabledSegments] = segments;
    await _saveMemory();
    notifyListeners();
    debugPrint("MEMORY: Segment '$segment' ${enabled ? 'ENABLED' : 'DISABLED'}");
  }

  /// Get all enabled segments for AI context filtering
  Map<String, bool> getSegmentToggles() {
    final enabled = _memory[kEnabledSegments] as Map<String, dynamic>? ?? {};
    return {
      for (final cat in memoryCategories)
        cat: enabled[cat] ?? true,
    };
  }

  Future<void> init() async {
    if (_isInitialized) return;
    await _loadMemory();
    _isInitialized = true;
    notifyListeners();
  }

  Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/memory.json');
  }

  Future<void> _loadMemory() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final decoded = jsonDecode(jsonString);
        _memory = _deepCast(decoded);
      } else {
        _memory = {}; // Start fresh
      }
    } catch (e) {
      debugPrint("Memory Corruption: $e");
      _memory = {};
    }
  }

  /// Recursively cast nested maps to a string-keyed dynamic map.
  Map<String, dynamic> _deepCast(dynamic data) {
    if (data is Map) {
      return data.map((key, value) {
        if (value is Map) {
          return MapEntry(key.toString(), _deepCast(value));
        } else if (value is List) {
          return MapEntry(key.toString(), value.map((e) => e is Map ? _deepCast(e) : e).toList());
        }
        return MapEntry(key.toString(), value);
      });
    }
    return {};
  }

  Future<void> _saveMemory() async {
    try {
      final file = await _getFile();
      await file.writeAsString(jsonEncode(_memory));
      notifyListeners();
    } catch (e) {
      debugPrint("Memory Write Error: $e");
    }
  }

  // --- CRUD Operations ---

  dynamic getSegment(String key) {
    final segment = _memory[key];
    // Ensure we return properly typed maps
    if (segment is Map && segment is! Map<String, dynamic>) {
      return _deepCast(segment);
    }
    return segment;
  }

  Future<void> updateSegment(String key, dynamic data) async {
    _memory[key] = data;
    await _saveMemory();
  }

  Future<void> updateIdentity(String role, String institution) async {
    await updateSegment(kIdentity, {
      'role': role,
      'institution': institution,
    });
  }

  Future<void> updateTimetable(Map<String, List<String>> weeklySchedule) async {
    await updateSegment(kTimetable, weeklySchedule);
  }

  Future<void> updateRoutine(String wakeTime, String sleepTime) async {
    final prefs = getSegment(kPreferences) ?? {};
    prefs['wake_time'] = wakeTime;
    prefs['sleep_time'] = sleepTime;
    await updateSegment(kPreferences, prefs);
  }

  Future<void> updateProtocol(String mainGoal, String mainBlocker) async {
    await updateSegment('protocol', {
      'main_goal': mainGoal,
      'main_blocker': mainBlocker,
    });
  }

  Future<void> updateSubjects(List<String> subjects) async {
    await updateSegment('user_subjects', subjects.take(3).toList());
  }

  /// Returns true if the user has completed onboarding (i.e., has an identity)
  bool get hasOnboarded => _memory.containsKey(kIdentity);
  
  // --- AGENT REPLAY BUFFER ---

  List<AgentLog> getRelevantHistory(String actionType) {
    if (_memory['agent_history'] == null) return [];
    
    final List<dynamic> logs = _memory['agent_history'];
    return logs
        .map((e) => AgentLog.fromJson(e))
        .where((log) => log.actionType.toLowerCase().contains(actionType.toLowerCase()))
        .toList()
        // Sort by recency? Or just take last 5?
        .reversed
        .take(5)
        .toList();
  }

  Future<void> logInteraction(AgentLog log) async {
    if (_memory['agent_history'] == null) {
      _memory['agent_history'] = [];
    }
    (_memory['agent_history'] as List).add(log.toJson());
    await _saveMemory();
    
    // Also remove from pending if exists
    removePendingDebrief(log.eventId);
  }

  List<AgentLog> getAllLogs() {
    if (_memory['agent_history'] == null) return [];
    return (_memory['agent_history'] as List)
      .map((e) => AgentLog.fromJson(e))
      .toList()
      .reversed
      .toList();
  }

  Future<void> deleteLog(int index) async {
     if (_memory['agent_history'] == null) return;
     final list = _memory['agent_history'] as List;
     // The UI will likely show reversed list, so we need to handle index mapping or just direct delete if passed correctly
     // Use careful indexing. For simplicity, let's assume we delete from the actual underlying list order if possible, 
     // but usually we want to delete by ID or timestamp. 
     // Let's rely on simple list manipulation for now, assuming index matches the *reversed* view if we handle it in UI, 
     // or better: delete by equality check on timestamp/eventID.
     
     // actually, let's simple removal by index of the REVERSED list is tricky.
     // SAFE WAY: Remove by reference isn't easy with JSON recreation.
     // Let's remove by index in natural order (0 is oldest).
     if (index >= 0 && index < list.length) {
       list.removeAt(index);
       await _saveMemory();
     }
  }

  Future<void> clearMemorySlab(String key) async {
    _memory.remove(key);
    await _saveMemory();
  }

  // --- DEBRIEF SYSTEM ---

  List<PendingDebrief> getPendingDebriefs() {
    if (_memory['pending_debriefs'] == null) return [];
    
    final List<dynamic> list = _memory['pending_debriefs'];
    final now = DateTime.now();
    
    return list
        .map((e) => PendingDebrief.fromJson(e))
        .where((d) => d.endTime.isBefore(now)) // Only show passed events
        .toList();
  }

  Future<void> addPendingDebrief(String eventId, String title, DateTime endTime) async {
    if (_memory['pending_debriefs'] == null) {
      _memory['pending_debriefs'] = [];
    }
    final debrief = PendingDebrief(eventId: eventId, title: title, endTime: endTime);
    (_memory['pending_debriefs'] as List).add(debrief.toJson());
    await _saveMemory();
  }

  Future<void> removePendingDebrief(String? eventId) async {
    if (eventId == null || _memory['pending_debriefs'] == null) return;
    
    final List<dynamic> list = _memory['pending_debriefs'];
    list.removeWhere((e) => e['eventId'] == eventId);
    _memory['pending_debriefs'] = list;
    await _saveMemory();
    notifyListeners();
  }

  // --- FACT STORE (SEMANTIC MEMORY) ---
  
  static const kFacts = 'facts';

  Future<void> learnFact(String key, String value) async {
    final facts = _memory[kFacts] as Map<String, dynamic>? ?? {};
    facts[key] = value;
    _memory[kFacts] = facts;
    await _saveMemory();
    debugPrint("MEMORY: Learned Fact [$key] = $value");
  }

  Future<void> forgetFact(String key) async {
    final facts = _memory[kFacts] as Map<String, dynamic>? ?? {};
    if (facts.containsKey(key)) {
      facts.remove(key);
      _memory[kFacts] = facts;
      await _saveMemory();
    }
  }

  Map<String, dynamic> getFacts() {
    return _memory[kFacts] as Map<String, dynamic>? ?? {};
  }

  // --- JOURNAL STORE (VAULT) ---

  Future<void> addJournalEntry(JournalEntry entry) async {
    if (_memory[kJournalEntries] == null) {
      _memory[kJournalEntries] = [];
    }

    final list = _memory[kJournalEntries] as List;
    list.add(entry.toJson());

    // Keep latest 200 entries to bound file growth.
    if (list.length > 200) {
      list.removeRange(0, list.length - 200);
    }

    _memory[kJournalEntries] = list;
    await _saveMemory();
  }

  Future<void> deleteJournalEntry(String id) async {
    if (_memory[kJournalEntries] == null) return;
    final list = _memory[kJournalEntries] as List;
    list.removeWhere((e) => e['id'] == id);
    _memory[kJournalEntries] = list;
    await _saveMemory();
  }

  List<JournalEntry> getJournalEntries({int? limit}) {
    if (_memory[kJournalEntries] == null) return [];

    final items = (_memory[kJournalEntries] as List)
        .map((e) => JournalEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (limit == null || items.length <= limit) return items;
    return items.take(limit).toList();
  }

  /// Total persisted journal entries (not capped by [getJournalEntries] limit).
  int getJournalEntryCount() {
    final raw = _memory[kJournalEntries];
    if (raw == null) return 0;
    return (raw as List).length;
  }

  int getJournalStreakDays() {
    final entries = getJournalEntries();
    if (entries.isEmpty) return 0;

    final uniqueDays = <DateTime>{};
    for (final entry in entries) {
      uniqueDays.add(DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day));
    }

    int streak = 0;
    final today = DateTime.now();
    DateTime cursor = DateTime(today.year, today.month, today.day);

    while (uniqueDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return streak;
  }

  // --- DEFERRED TASKS ("I'LL START TOMORROW" MEMORY) ---

  List<DeferredTask> getDeferredTasks({bool includeCompleted = false, int? limit}) {
    if (_memory[kDeferredTasks] == null) return [];

    var tasks = (_memory[kDeferredTasks] as List)
        .map((e) => DeferredTask.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (!includeCompleted) {
      tasks = tasks.where((t) => t.status != DeferredTaskStatus.completed).toList();
    }

    if (limit != null && tasks.length > limit) {
      return tasks.take(limit).toList();
    }
    return tasks;
  }

  Future<void> addDeferredTask({
    required String description,
    String promisedFor = 'tomorrow',
  }) async {
    final trimmed = description.trim();
    if (trimmed.isEmpty) return;

    if (_memory[kDeferredTasks] == null) {
      _memory[kDeferredTasks] = [];
    }

    final list = _memory[kDeferredTasks] as List;
    final existingOpen = list
        .map((e) => DeferredTask.fromJson(Map<String, dynamic>.from(e)))
        .where((t) => t.status != DeferredTaskStatus.completed)
        .any((t) => t.description.toLowerCase() == trimmed.toLowerCase());

    if (existingOpen) return;

    final task = DeferredTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      description: trimmed,
      promisedFor: promisedFor,
      status: DeferredTaskStatus.open,
      createdAt: DateTime.now(),
      startedAt: null,
      completedAt: null,
    );

    list.add(task.toJson());

    // Keep memory bounded.
    if (list.length > 120) {
      list.removeRange(0, list.length - 120);
    }

    _memory[kDeferredTasks] = list;
    await _saveMemory();
  }

  Future<DeferredTask?> markLatestDeferredTaskStarted() async {
    if (_memory[kDeferredTasks] == null) return null;

    final list = (_memory[kDeferredTasks] as List)
        .map((e) => DeferredTask.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final idx = list.indexWhere((t) => t.status == DeferredTaskStatus.open);
    if (idx == -1) return null;

    final updated = list[idx].copyWith(
      status: DeferredTaskStatus.started,
      startedAt: DateTime.now(),
    );
    list[idx] = updated;

    _memory[kDeferredTasks] = list.map((t) => t.toJson()).toList();
    await _saveMemory();
    return updated;
  }

  Future<DeferredTask?> markLatestDeferredTaskCompleted() async {
    if (_memory[kDeferredTasks] == null) return null;

    final list = (_memory[kDeferredTasks] as List)
        .map((e) => DeferredTask.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    int idx = list.indexWhere((t) => t.status == DeferredTaskStatus.started);
    idx = idx == -1 ? list.indexWhere((t) => t.status == DeferredTaskStatus.open) : idx;
    if (idx == -1) return null;

    final updated = list[idx].copyWith(
      status: DeferredTaskStatus.completed,
      completedAt: DateTime.now(),
      startedAt: list[idx].startedAt ?? DateTime.now(),
    );
    list[idx] = updated;

    _memory[kDeferredTasks] = list.map((t) => t.toJson()).toList();
    await _saveMemory();
    return updated;
  }
}

// --- MODELS ---

class AgentLog {
  final DateTime timestamp;
  final String context; // e.g. "Monday 8PM"
  final String actionType; // e.g. "Coding"
  final String outcome; // "Success", "Failure"
  final int energyImpact;
  final String? eventId;

  AgentLog({
    required this.timestamp,
    required this.context,
    required this.actionType,
    required this.outcome,
    required this.energyImpact,
    this.eventId,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'context': context,
    'actionType': actionType,
    'outcome': outcome,
    'energyImpact': energyImpact,
    'eventId': eventId,
  };

  factory AgentLog.fromJson(Map<String, dynamic> json) {
    return AgentLog(
      timestamp: DateTime.parse(json['timestamp']),
      context: json['context'],
      actionType: json['actionType'],
      outcome: json['outcome'],
      energyImpact: json['energyImpact'],
      eventId: json['eventId'],
    );
  }
}

class PendingDebrief {
  final String eventId;
  final String title;
  final DateTime endTime;

  PendingDebrief({required this.eventId, required this.title, required this.endTime});

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'title': title,
    'endTime': endTime.toIso8601String(),
  };

  factory PendingDebrief.fromJson(Map<String, dynamic> json) {
    return PendingDebrief(
      eventId: json['eventId'],
      title: json['title'],
      endTime: DateTime.parse(json['endTime']),
    );
  }
}

class JournalEntry {
  final String id;
  final DateTime timestamp;
  final String text;
  final String mood;
  final List<String> tags;
  final int actionableCount;
  final List<String> acceptedInsights;

  JournalEntry({
    required this.id,
    required this.timestamp,
    required this.text,
    required this.mood,
    required this.tags,
    required this.actionableCount,
    required this.acceptedInsights,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'text': text,
    'mood': mood,
    'tags': tags,
    'actionableCount': actionableCount,
    'acceptedInsights': acceptedInsights,
  };

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      text: json['text'] as String? ?? '',
      mood: json['mood'] as String? ?? 'neutral',
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      actionableCount: json['actionableCount'] as int? ?? 0,
      acceptedInsights: (json['acceptedInsights'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

enum DeferredTaskStatus { open, started, completed }

class DeferredTask {
  final String id;
  final String description;
  final String promisedFor;
  final DeferredTaskStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  DeferredTask({
    required this.id,
    required this.description,
    required this.promisedFor,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
  });

  DeferredTask copyWith({
    String? id,
    String? description,
    String? promisedFor,
    DeferredTaskStatus? status,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return DeferredTask(
      id: id ?? this.id,
      description: description ?? this.description,
      promisedFor: promisedFor ?? this.promisedFor,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'promisedFor': promisedFor,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'startedAt': startedAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
  };

  factory DeferredTask.fromJson(Map<String, dynamic> json) {
    final statusRaw = (json['status'] as String?) ?? 'open';
    final status = DeferredTaskStatus.values.firstWhere(
      (s) => s.name == statusRaw,
      orElse: () => DeferredTaskStatus.open,
    );

    return DeferredTask(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      description: json['description'] as String? ?? '',
      promisedFor: json['promisedFor'] as String? ?? 'tomorrow',
      status: status,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      startedAt: json['startedAt'] != null ? DateTime.tryParse(json['startedAt'] as String) : null,
      completedAt: json['completedAt'] != null ? DateTime.tryParse(json['completedAt'] as String) : null,
    );
  }
}
