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

  /// Single-line machine block (also used in silent nudges).
  String toInlineBlock() {
    return 'TIME: $timeLabel | DAY: $dayName | DATE: $dateLabel | '
        'SINCE_LAST_USER_MSG: $sinceLastUserMessage | ACTIVE_TASK: $activeTask | '
        'NEXT_EVENT: $nextEventTitle | MIN_UNTIL_NEXT: $minutesUntilNextEvent | '
        'FOCUS_MIN_TODAY: $focusMinutesSession | '
        'BEHAVIOR: $behaviorNote';
  }
}

/// Next calendar anchor for ambient line (prefs only; zero network).
class AmbientNextEvent {
  AmbientNextEvent(this.title, {this.minutesUntil});

  final String title;
  /// Minutes until start when known; null when we only have a title (non-ISO time, etc.).
  final int? minutesUntil;
}

/// Persisted for background isolate + ongoing notification. No AI — [buildAmbientLine] is template-only.
class VyomaAmbientPrefs {
  static const _kActiveTask = 'vyoma_ambient_active_task';
  static const _kFocusMin = 'vyoma_ambient_focus_min';
  static const _kNextTitle = 'vyoma_ambient_next_title';
  static const _kNextMin = 'vyoma_ambient_next_min';

  /// No upcoming event stored.
  static const int _kNextMinNone = -1;

  /// Title present but minutes not parsed (degraded display).
  static const int _kNextMinUnknown = -2;

  static Future<void> writeFromSnapshot(TemporalContextSnapshot s) async {
    final p = await SharedPreferences.getInstance();
    final raw = s.activeTask.trim();
    final lower = raw.toLowerCase();
    final task = raw.isEmpty || lower == 'none set' || lower == 'none'
        ? ''
        : raw;
    await p.setString(_kActiveTask, task);
    await p.setInt(_kFocusMin, s.focusMinutesSession);
    final nt = s.nextEventTitle.trim();
    final none = nt.isEmpty || nt.toLowerCase() == 'none';
    await p.setString(_kNextTitle, none ? '' : nt);
    if (none) {
      await p.setInt(_kNextMin, _kNextMinNone);
    } else if (s.nextEventMinutesRaw == null) {
      await p.setInt(_kNextMin, _kNextMinUnknown);
    } else {
      await p.setInt(_kNextMin, s.nextEventMinutesRaw!);
    }
  }

  /// Updates active task + focus minutes only (leaves next-event prefs intact). No network.
  static Future<void> patchQuickAmbientState({
    String? activeTask,
    required int focusMinutesToday,
  }) async {
    final p = await SharedPreferences.getInstance();
    final t = activeTask?.trim();
    await p.setString(_kActiveTask, (t == null || t.isEmpty) ? '' : t);
    await p.setInt(_kFocusMin, focusMinutesToday < 0 ? 0 : focusMinutesToday);
  }

  static Future<String?> getActiveTask() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_kActiveTask);
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  }

  static Future<AmbientNextEvent?> getNextEvent() async {
    final p = await SharedPreferences.getInstance();
    final title = p.getString(_kNextTitle);
    if (title == null || title.trim().isEmpty) return null;
    if (title.toLowerCase() == 'none') return null;
    final min = p.getInt(_kNextMin) ?? _kNextMinNone;
    if (min == _kNextMinNone) return null;
    if (min == _kNextMinUnknown) {
      return AmbientNextEvent(title.trim(), minutesUntil: null);
    }
    return AmbientNextEvent(title.trim(), minutesUntil: min);
  }

  static Future<int> getFocusMinutes() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kFocusMin) ?? 0;
  }

  /// Ongoing notification body — reads prefs only, no network.
  static Future<String> buildAmbientLine() async {
    final task = (await getActiveTask()) ?? 'nothing set';
    final nextEvent = await getNextEvent();
    final focusMinutes = await getFocusMinutes();
    final hour = DateTime.now().hour;

    if (focusMinutes > 0) {
      return 'Focused $focusMinutes min today · $task';
    }
    if (nextEvent != null) {
      if (nextEvent.minutesUntil != null) {
        return '$task · ${nextEvent.title} soon';
      }
      return '$task · ${nextEvent.title} (soon)';
    }
    if (hour < 10) {
      return 'Morning. What are you working on?';
    }
    if (hour > 22) {
      return 'Late. Wrap up $task or drop it.';
    }
    return 'Current: $task';
  }
}

class TemporalContextBuilder {
  TemporalContextBuilder(this._memory);

  final MemoryService _memory;

  static const _kRuntime = 'vyoma_runtime_state';
  static const _kLastUser = 'vyoma_last_user_message_at';

  /// Parse calendar lines like `[Title @ 2026-05-14 10:00:00.000]`.
  ///
  /// If the time segment is missing or not ISO-parsable, returns the title with
  /// [minutesUntil] null so callers can show a degraded "(soon)" line instead of dropping it.
  static ({String title, int? minutesUntil})? parseNextEventFromStrings(
    List<String> eventStrings,
  ) {
    final re = RegExp(r'^\[(.+?)\s+@\s+(.+)\]\s*$');
    final now = DateTime.now();
    ({String title, DateTime start})? bestParsed;
    String? looseTitle;

    for (final line in eventStrings) {
      final m = re.firstMatch(line.trim());
      if (m == null) continue;
      final title = m.group(1)?.trim() ?? 'Event';
      final raw = m.group(2)?.trim();
      if (raw == null || raw.isEmpty) {
        looseTitle ??= title;
        continue;
      }
      final start = DateTime.tryParse(raw);
      if (start == null) {
        looseTitle ??= title;
        continue;
      }
      final local = start.isUtc ? start.toLocal() : start;
      if (!local.isAfter(now)) continue;
      if (bestParsed == null || local.isBefore(bestParsed.start)) {
        bestParsed = (title: title, start: local);
      }
    }

    if (bestParsed != null) {
      final mins = bestParsed.start.difference(now).inMinutes.clamp(0, 99999);
      return (title: bestParsed.title, minutesUntil: mins);
    }
    if (looseTitle != null &&
        looseTitle.isNotEmpty &&
        looseTitle.toLowerCase() != 'none') {
      return (title: looseTitle, minutesUntil: null);
    }
    return null;
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
    final nextMinStr = next == null
        ? 'n/a'
        : (next.minutesUntil == null ? 'unknown' : '${next.minutesUntil} minutes');
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
Their next event is: ${s.nextEventTitle.toLowerCase() == 'none' ? 'none (no upcoming event in the attached list).' : '${s.nextEventTitle}${s.minutesUntilNextEvent == 'unknown' ? ' (soon)' : ' in ${s.minutesUntilNextEvent}'}.'}

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
