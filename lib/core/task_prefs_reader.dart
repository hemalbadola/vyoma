import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/task.dart';

/// Reads the same per-uid task mirror [TaskService] persists — safe in isolates / background.
class TaskPrefsReader {
  static String _tasksKey(String? uid) =>
      uid == null ? 'vyoma_tasks_guest' : 'vyoma_tasks_$uid';

  static Future<List<VyomaTask>> loadTasks() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_tasksKey(uid));
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
