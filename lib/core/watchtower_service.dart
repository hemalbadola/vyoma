import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_service.dart';
import 'memory_service.dart';
import 'notification_service.dart';
import 'temporal_behavior_store.dart';

/// Post-calendar debriefs: act on elapsed time, not only restoring scheduled toasts.
class WatchtowerService {
  WatchtowerService({
    required this.memory,
    required this.notifications,
  });

  final MemoryService memory;
  final NotificationService notifications;

  static String _sentKey(String eventId) => 'vyoma_watchtower_debrief_$eventId';

  /// Fire at most one debrief nudge per tick (oldest eligible).
  Future<void> tick() async {
    await memory.init();
    final pending = memory.getPendingDebriefs();
    if (pending.isEmpty) return;

    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();

    pending.sort((a, b) => a.endTime.compareTo(b.endTime));

    for (final d in pending) {
      final elapsed = now.difference(d.endTime);
      if (elapsed.isNegative) continue;
      if (elapsed.inMinutes < 3) continue;
      if (elapsed.inHours > 6) continue;
      if (prefs.getBool(_sentKey(d.eventId)) == true) continue;

      var body =
          '${d.title} ended ${elapsed.inMinutes}m ago. One line: what actually happened before you move on?';

      try {
        final prompt = '''
Vyoma watchtower: calendar block just ended.
Event: ${d.title}
Minutes since end: ${elapsed.inMinutes}
Write ONE short push notification (max 120 chars), calm, no guilt. Plain text only.
''';
        final refined = await AIService.executeSilentBackgroundPrompt(prompt);
        if (refined != null &&
            refined.trim().isNotEmpty &&
            refined.length < 200) {
          body = refined.trim();
        }
      } catch (e) {
        debugPrint('WatchtowerService: LLM debrief failed $e');
      }

      await notifications.notifyNow(title: 'Vyoma', body: body);
      await prefs.setBool(_sentKey(d.eventId), true);

      try {
        await TemporalBehaviorStore(memory).record(
          kind: 'nudge_sent',
          taskTitle: d.title,
          outcome: 'calendar_debrief',
        );
      } catch (_) {}

      return;
    }
  }
}
