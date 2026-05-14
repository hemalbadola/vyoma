import 'package:shared_preferences/shared_preferences.dart';

import 'memory_service.dart';
import 'notification_service.dart';
import 'task_prefs_reader.dart';
import 'temporal_behavior_store.dart';

/// Proactive deadline nudges — **zero AI / zero API** (rotating templates only).
class SentinelService {
  SentinelService({
    required this.memory,
    required this.notifications,
  });

  final MemoryService memory;
  final NotificationService notifications;

  static const List<String> _deadlineLines = [
    'You have {task} in {n} minutes.',
    '{task} — {n} minutes left.',
    '{n} minutes to {task}. You set this.',
  ];

  static String _deadlineKey(String taskId, DateTime day) =>
      'vyoma_sentinel_deadline_${taskId}_${day.year}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';

  static String _pickBody(String task, int minutes) {
    final n = minutes < 1 ? 1 : minutes;
    final template =
        _deadlineLines[DateTime.now().minute % _deadlineLines.length];
    return template.replaceAll('{task}', task).replaceAll('{n}', '$n');
  }

  /// First eligible task id + body, or null.
  Future<({String taskId, String body})?> pickDeadlineNudge() async {
    final tasks = await TaskPrefsReader.loadTasks();
    final sorted = tasks.toList()
      ..sort((a, b) {
        final ad = a.deadline;
        final bd = b.deadline;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();

    for (final t in sorted) {
      if (t.completed || t.deadline == null) continue;
      final due = t.deadline!;
      final untilMin = due.difference(now).inMinutes;
      if (untilMin > 45 || untilMin < 0) continue;

      final key = _deadlineKey(t.id, now);
      if (prefs.getBool(key) == true) continue;

      final body = _pickBody(t.title, untilMin);
      return (taskId: t.id, body: body);
    }
    return null;
  }

  Future<void> fireIfNeeded() async {
    final pick = await pickDeadlineNudge();
    if (pick == null) return;

    await notifications.notifyNow(title: 'Vyoma', body: pick.body);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_deadlineKey(pick.taskId, DateTime.now()), true);

    try {
      await TemporalBehaviorStore(memory).record(
        kind: 'nudge_sent',
        outcome:
            pick.body.length > 120 ? '${pick.body.substring(0, 120)}…' : pick.body,
      );
    } catch (_) {}
  }
}
