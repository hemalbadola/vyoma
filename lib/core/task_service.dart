import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/task.dart';
import 'accountability_service.dart';
import 'cofocus_service.dart';

class TaskService extends ChangeNotifier {
  static const String _kTasksKey = 'vyoma_tasks';
  static const String _kDailyMetricsKey = 'vyoma_daily_metrics';

  final AccountabilityService? _accountability;
  final CoFocusService? _coFocusService;
  final dynamic _userService; // Inject UserService gracefully
  List<VyomaTask> _tasks = [];
  
  List<VyomaTask> get tasks => List.unmodifiable(_tasks);
  List<VyomaTask> get activeTasks => _tasks.where((t) => !t.completed).toList();
  List<VyomaTask> get completedTasks => _tasks.where((t) => t.completed).toList();
  List<VyomaTask> get overdueTasks => _tasks.where((t) => t.isOverdue).toList();
  List<VyomaTask> get dueTodayTasks => _tasks.where((t) => !t.completed && t.isDueToday).toList();
  
  TaskService({
    AccountabilityService? accountability,
    CoFocusService? coFocusService,
    dynamic userService,
  })  : _accountability = accountability,
        _coFocusService = coFocusService,
        _userService = userService {
    _loadFromStorage();
  }

  // --- CRUD ---

  Future<VyomaTask> addTask({
    required String title,
    String? description,
    String? project,
    DateTime? deadline,
    String priority = 'normal',
  }) async {
    final task = VyomaTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      project: project,
      createdAt: DateTime.now(),
      deadline: deadline,
      priority: priority,
    );
    _tasks.add(task);
    await _saveToStorage();
    return task;
  }

  Future<void> completeTask(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    _tasks[index] = _tasks[index].copyWith(
      completed: true,
      completedAt: DateTime.now(),
    );
    await _saveToStorage();
    
    // Fire accountability event
    _accountability?.onTaskCompleted(_tasks[index].title);
  }

  Future<void> uncompleteTask(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    _tasks[index] = _tasks[index].copyWith(completed: false);
    await _saveToStorage();
  }

  Future<void> deleteTask(String taskId) async {
    _tasks.removeWhere((t) => t.id == taskId);
    await _saveToStorage();
  }

  Future<void> addFocusTime(String taskId, int minutes) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    _tasks[index] = _tasks[index].copyWith(
      focusMinutes: _tasks[index].focusMinutes + minutes,
    );
    await _saveToStorage();
    
    // Fire accountability event
    _accountability?.onFocusSessionEnded(_tasks[index].title, minutes);
    
    // Distribute focus time to active pacts
    _coFocusService?.logFocusProgress(minutes);
  }

  /// Find tasks matching a search query (used by AI for task lookup)
  List<VyomaTask> searchTasks(String query) {
    final lower = query.toLowerCase();
    return _tasks.where((t) {
      return t.title.toLowerCase().contains(lower) ||
          (t.description?.toLowerCase().contains(lower) ?? false) ||
          (t.project?.toLowerCase().contains(lower) ?? false);
    }).toList();
  }

  /// Get unfinished tasks from yesterday (for morning briefing carryover)
  List<VyomaTask> getCarryoverTasks() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _tasks.where((t) {
      if (t.completed) return false;
      return t.createdAt.isBefore(today);
    }).toList();
  }

  /// Get tasks grouped by project
  Map<String, List<VyomaTask>> getTasksByProject() {
    final grouped = <String, List<VyomaTask>>{};
    for (final task in activeTasks) {
      final project = task.project ?? 'Uncategorized';
      grouped.putIfAbsent(project, () => []).add(task);
    }
    return grouped;
  }

  // --- Daily Metrics Snapshot (for Weekly Retro) ---

  Future<void> saveDailySnapshot({
    required int focusMinutes,
    required int distractionCount,
    required int tasksCompleted,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10); // "2026-04-05"
    
    final existing = prefs.getString(_kDailyMetricsKey);
    final Map<String, dynamic> allMetrics = existing != null ? jsonDecode(existing) : {};
    
    allMetrics[today] = {
      'focusMinutes': focusMinutes,
      'distractionCount': distractionCount,
      'tasksCompleted': tasksCompleted,
      'activeTasks': activeTasks.length,
      'overdueTasks': overdueTasks.length,
    };

    // Keep last 90 days
    if (allMetrics.length > 90) {
      final sorted = allMetrics.keys.toList()..sort();
      for (final key in sorted.take(allMetrics.length - 90)) {
        allMetrics.remove(key);
      }
    }

    await prefs.setString(_kDailyMetricsKey, jsonEncode(allMetrics));
  }

  /// Get daily metrics for the last N days
  Future<Map<String, Map<String, dynamic>>> getDailyMetrics({int days = 14}) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_kDailyMetricsKey);
    if (data == null) return {};

    final Map<String, dynamic> all = jsonDecode(data);
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final cutoffStr = cutoff.toIso8601String().substring(0, 10);

    final result = <String, Map<String, dynamic>>{};
    for (final entry in all.entries) {
      if (entry.key.compareTo(cutoffStr) >= 0) {
        result[entry.key] = Map<String, dynamic>.from(entry.value);
      }
    }
    return result;
  }

  // --- Persistence ---

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_kTasksKey);
    if (data != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(data);
        _tasks = jsonList.map((e) => VyomaTask.fromJson(e)).toList();
      } catch (e) {
        debugPrint("Failed to load tasks: $e");
        _tasks = [];
      }
    }
    notifyListeners();
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _tasks.map((t) => t.toJson()).toList();
    await prefs.setString(_kTasksKey, jsonEncode(jsonList));
    notifyListeners();

    // Mirror top 3 active tasks to public profile for accountability pings
    if (_userService != null) {
      final profile = _userService.profile;
      if (profile != null && profile.shareTasksWithFriends) {
        final toSync = activeTasks.take(3).map((t) => t.title).toList();
        _userService.syncActiveTasks(toSync).catchError((e) {
          debugPrint("Failed to sync active tasks to Firebase: $e");
        });
      } else if (profile != null && !profile.shareTasksWithFriends) {
        // Clear tasks if privacy is enabled
        _userService.syncActiveTasks([]).catchError((e) {
          debugPrint("Failed to clear hidden tasks: $e");
        });
      }
    }
  }
}
