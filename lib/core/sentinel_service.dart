import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_service.dart';
import 'memory_service.dart';
import 'notification_service.dart';
import 'task_prefs_reader.dart';
import 'temporal_behavior_store.dart';

/// Proactive clock-based nudges (deadlines, quiet app) — not chat-driven.
class SentinelService {
  SentinelService({
    required this.memory,
    required this.notifications,
  });

  final MemoryService memory;
  final NotificationService notifications;

  static String _deadlineKey(String taskId, DateTime day) =>
      'vyoma_sentinel_deadline_${taskId}_${day.year}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';

  /// First matching task id + nudge body, or null.
  Future<({String taskId, String body})?> pickDeadlineNudge() async {
    final tasks = await TaskPrefsReader.loadTasks();
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();

    for (final t in tasks) {
      if (t.completed || t.deadline == null) continue;
      final due = t.deadline!;
      final untilMin = due.difference(now).inMinutes;
      if (untilMin > 45 || untilMin < 0) continue;

      final key = _deadlineKey(t.id, now);
      if (prefs.getBool(key) == true) continue;

      final when =
          untilMin <= 1 ? 'now' : 'in about $untilMin minutes';
      final body =
          '"${t.title}" is due $when. Open Vyoma when you can — one honest move counts.';
      return (taskId: t.id, body: body);
    }
    return null;
  }

  Future<String?> refineNudgeWithModel(String draft) async {
    final prompt = '''
You are Vyoma composing ONE push notification line only.
Rules: max 140 characters. Plain text. No quotes wrapping the whole message. No emojis unless essential.
Draft idea: $draft
Return ONLY the notification body or EMPTY if user should not be disturbed.
''';
    final refined = await AIService.executeSilentBackgroundPrompt(prompt);
    if (refined == null || refined.trim().isEmpty) return draft;
    if (refined.length > 200) return draft;
    return refined.trim();
  }

  Future<void> fireIfNeeded() async {
    final pick = await pickDeadlineNudge();
    if (pick == null) return;

    String body = pick.body;
    try {
      body = await refineNudgeWithModel(pick.body) ?? pick.body;
    } catch (e) {
      debugPrint('SentinelService: refine failed $e');
    }

    await notifications.notifyNow(title: 'Vyoma', body: body);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_deadlineKey(pick.taskId, DateTime.now()), true);

    try {
      await TemporalBehaviorStore(memory).record(
        kind: 'nudge_sent',
        outcome: body.length > 120 ? '${body.substring(0, 120)}…' : body,
      );
    } catch (_) {}
  }
}
