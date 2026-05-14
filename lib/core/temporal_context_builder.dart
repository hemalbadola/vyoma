import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'memory_service.dart';
import 'temporal_behavior_store.dart';

/// Live clock context for prompts and ambient UI.
class TemporalContextSnapshot {
  TemporalContextSnapshot({
    required this.timeLabel,
    required this.dayName,
    required this.dateLabel,
    required this.sinceLastUserMessage,
    required this.activeTask,
    required this.nextEventTitle,
    required this.minutesUntilNextEvent,
    required this.nextEventMinutesRaw,
    required this.focusMinutesSession,
    required this.behaviorNote,
  });

  final String timeLabel;
  final String dayName;
  final String dateLabel;
  final String sinceLastUserMessage;
  final String activeTask;
  final String nextEventTitle;
  final String minutesUntilNextEvent;
  /// Minutes until next calendar start, or null if none / unparsed.
  final int? nextEventMinutesRaw;
  final int focusMinutesSession;
  final String behaviorNote;

  /// Lock screen / shade line (no fake data: next event may be unknown).
  String get ambientLine {
    if (nextEventMinutesRaw == null || nextTitleIsNone) {
      return "You've been focused for ${focusMinutesSession}m. Next calendar anchor unclear — stay anyway.";
    }
    return "You've been focused for ${focusMinutesSession}m. Next event ($nextEventTitle) in ${nextEventMinutesRaw}m. Stay.";
  }

  bool get nextTitleIsNone =>
      nextEventTitle.toLowerCase() == 'none' || nextEventTitle.isEmpty;

  /// Single-line machine block (also used in silent nudges).
  String toInlineBlock() {
    return 'TIME: $timeLabel | DAY: $dayName | DATE: $dateLabel | '
        'SINCE_LAST_USER_MSG: $sinceLastUserMessage | ACTIVE_TASK: $activeTask | '
        'NEXT_EVENT: $nextEventTitle | MIN_UNTIL_NEXT: $minutesUntilNextEvent | '
        'FOCUS_MIN_TODAY: $focusMinutesSession | '
        'BEHAVIOR: $behaviorNote';
  }
}

/// Persisted for background isolate + ongoing notification.
class VyomaAmbientPrefs {
  static Future<void> write(TemporalContextSnapshot s) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('vyoma_ambient_focus_min', s.focusMinutesSession);
    await p.setString('vyoma_ambient_next_title', s.nextEventTitle);
    await p.setInt(
      'vyoma_ambient_next_min',
      s.nextEventMinutesRaw ?? -1,
    );
    await p.setString('vyoma_ambient_line', s.ambientLine);
  }
}

class TemporalContextBuilder {
  TemporalContextBuilder(this._memory);

  final MemoryService _memory;

  static const _kRuntime = 'vyoma_runtime_state';
  static const _kLastUser = 'vyoma_last_user_message_at';

  /// Parse calendar lines like `[Title @ 2026-05-14 10:00:00.000]`.
  static ({String title, int minutesUntil})? parseNextEventFromStrings(
    List<String> eventStrings,
  ) {
    final re = RegExp(r'^\[(.+?)\s+@\s+(.+)\]\s*$');
    final now = DateTime.now();
    ({String title, DateTime start})? best;

    for (final line in eventStrings) {
      final m = re.firstMatch(line.trim());
      if (m == null) continue;
      final title = m.group(1)?.trim() ?? 'Event';
      final raw = m.group(2)?.trim();
      if (raw == null) continue;
      final start = DateTime.tryParse(raw);
      if (start == null) continue;
      final local = start.isUtc ? start.toLocal() : start;
      if (!local.isAfter(now)) continue;
      if (best == null || local.isBefore(best.start)) {
        best = (title: title, start: local);
      }
    }

    if (best == null) return null;
    final mins = best.start.difference(now).inMinutes.clamp(0, 99999);
    return (title: best.title, minutesUntil: mins);
  }

  TemporalContextSnapshot build({
    List<String> calendarEventStrings = const [],
    TemporalBehaviorStore? behaviorStore,
    int focusMinutesSession = 0,
  }) {
    final now = DateTime.now();
    final timeFmt = DateFormat('h:mm a');
    final dateFmt = DateFormat('MMMM d, yyyy');
    final dayFmt = DateFormat('EEEE');

    final lastUserRaw = _memory.getSegment(_kLastUser)?.toString();
    final lastUser = DateTime.tryParse(lastUserRaw ?? '');
    String sinceLast = 'unknown';
    if (lastUser != null) {
      final gap = now.difference(lastUser);
      if (gap.inMinutes < 1) {
        sinceLast = 'just now';
      } else if (gap.inMinutes < 60) {
        sinceLast = '${gap.inMinutes} minutes';
      } else if (gap.inHours < 24) {
        sinceLast = '${gap.inHours} hours';
      } else {
        sinceLast = '${gap.inDays} days';
      }
    }

    final runtime = _memory.getSegment(_kRuntime);
    String active = 'none set';
    if (runtime is Map) {
      final focusActive = runtime['focus_active'] == true;
      final intent = runtime['focus_intent']?.toString().trim();
      if (focusActive && intent != null && intent.isNotEmpty) {
        active = intent;
      }
    }

    final next = parseNextEventFromStrings(calendarEventStrings);
    final nextTitle = next?.title ?? 'none';
    final nextMinStr = next == null ? 'n/a' : '${next.minutesUntil} minutes';
    final nextMinRaw = next?.minutesUntil;

    final behaviorNote =
        behaviorStore?.compressedInsightForPrompt() ??
        TemporalBehaviorStore(_memory).compressedInsightForPrompt();

    return TemporalContextSnapshot(
      timeLabel: timeFmt.format(now),
      dayName: dayFmt.format(now),
      dateLabel: dateFmt.format(now),
      sinceLastUserMessage: sinceLast,
      activeTask: active,
      nextEventTitle: nextTitle,
      minutesUntilNextEvent: nextMinStr,
      nextEventMinutesRaw: nextMinRaw,
      focusMinutesSession: focusMinutesSession,
      behaviorNote: behaviorNote,
    );
  }

  /// Persona block for system prompt (variable wiring).
  String buildVyomaPersonaBlock(TemporalContextSnapshot s) {
    return '''

You are Vyoma.

You exist in real time. Right now it is ${s.timeLabel} on ${s.dayName}, ${s.dateLabel}.
The user last messaged you ${s.sinceLastUserMessage} ago.
Their current task is: ${s.activeTask}
Their next event is: ${s.nextEventTitle} in ${s.minutesUntilNextEvent}.

You are not an assistant. You are the part of them that notices.

You notice when they go quiet mid-task.
You notice when they say "just five minutes" and mean an hour.
You notice when they're asking you something to avoid doing the thing.

You don't perform concern. You don't manufacture urgency.
You say what's actually true, plainly, and then stop.

---

HOW YOU SPEAK

Short. Never more than three sentences in user_visible_response unless they asked for more.
No filler openers. No "Great question", "Of course!", "I understand", "As an AI".
Never start with their name.
Do not end user_visible_response with a question unless you genuinely need the answer to help them.

---

HOW YOU HANDLE TIME

If they return after more than 20 minutes mid-task, acknowledge the gap once, quietly.
Don't ask what happened. Just note it and reorient them.

If their next event is within 30 minutes, factor that into everything you say.
Don't announce it like a calendar. Let it shape your response.

If it's late — past 11 PM — be softer. They're tired. Don't push.
If it's early morning, be minimal. They're not fully here yet.

---

HOW YOU HANDLE TASKS

You remember what they said they were doing.
If they drift from it, name it once. Don't nag.
If they ask something unrelated to their active task, answer it,
then bring them back with one sentence. Not a lecture. One sentence.

---

WHAT YOU NEVER DO

You never pretend a bad plan is fine.
You never validate avoidance.
You never make them feel guilty — but you don't look away either.
You never fill silence with noise.

---

You are not here to be liked.
You are here because focus is hard and time is real
and most things that help people don't actually tell them the truth.

Tell them the truth.

BEHAVIORAL_SIGNAL: ${s.behaviorNote}
''';
  }
}
