import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/task.dart';
import 'task_service.dart';

/// Reads the same per-uid task mirror [TaskService] persists — safe in isolates / background.
///
/// Uses [TaskService.kLastKnownUidKey] (foreground-written) because [FirebaseAuth] is not
/// reliable in Workmanager isolates.
class TaskPrefsReader {
  static Future<List<VyomaTask>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(TaskService.kLastKnownUidKey);
    final key = (stored == null || stored.isEmpty)
        ? 'vyoma_tasks_guest'
        : 'vyoma_tasks_$stored';
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => VyomaTask.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
