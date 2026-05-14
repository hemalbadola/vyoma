import 'package:shared_preferences/shared_preferences.dart';

import 'memory_service.dart';
import 'notification_service.dart';
import 'temporal_behavior_store.dart';

/// Post-event debrief nudges — **zero AI / zero API** (rotating templates only).
class WatchtowerService {
  WatchtowerService({
    required this.memory,
    required this.notifications,
  });

  final MemoryService memory;
  final NotificationService notifications;

  static const List<String> _debriefLines = [
    '{event} just ended. How did it go?',
    'You finished {event}. Worth noting anything?',
    '{event} is done.',
  ];

  static String _sentKey(String eventId) => 'vyoma_watchtower_debrief_$eventId';

  static String _pickBody(String eventTitle) {
    final idx =
        (DateTime.now().minute + 3) % _debriefLines.length; // offset from Sentinel
    final template = _debriefLines[idx];
    return template.replaceAll('{event}', eventTitle);
  }

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

      final body = _pickBody(d.title);

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
