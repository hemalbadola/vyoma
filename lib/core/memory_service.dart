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
    print("MEMORY: Segment '$segment' ${enabled ? 'ENABLED' : 'DISABLED'}");
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
      print("Memory Corruption: $e");
      _memory = {};
    }
  }

  /// Recursively cast nested maps to Map<String, dynamic>
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
      print("Memory Write Error: $e");
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
    print("MEMORY: Learned Fact [$key] = $value");
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
