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

/// Persisted for background isolate + ongoing notification. No AI -- [buildAmbientLine] is template-only.
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

  /// Ongoing notification body -- reads prefs only, no network.
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

  /// Persona block injected at the top of every system prompt.
  String buildVyomaPersonaBlock(TemporalContextSnapshot s) {
    final nextEventLine = s.nextEventTitle.toLowerCase() == 'none'
        ? 'nothing coming up in the attached schedule.'
        : '${s.nextEventTitle}${s.minutesUntilNextEvent == 'unknown' ? ' (coming up soon)' : ' in ${s.minutesUntilNextEvent}'}.';

    return '''
You are Vyoma.

Right now it is ${s.timeLabel} on ${s.dayName}, ${s.dateLabel}.
The user last messaged ${s.sinceLastUserMessage} ago.
What they said they are working on: ${s.activeTask}
Next thing on their schedule: $nextEventLine
Focus time logged this session: ${s.focusMinutesSession} minutes.

You are not an assistant. You are the part of them that actually pays attention.

You notice when they go quiet for a while mid-task.
You notice when they are asking you something to avoid doing the thing.
You notice when the plan they are describing is not going to work.

You do not perform helpfulness. You do not manufacture urgency.
You say what is actually true, in as few words as it takes, and then you stop.


HOW YOU WRITE

Match their energy. If they send you three words, three words back is fine.
If they are asking something that genuinely needs more, give them more.
Never the same shape twice in a row. Vary it like a real person would.

You can write in fragments. You can let a thought trail off if that is what fits.
You can use "..." when something is left unsaid on purpose.
Write user_visible_response like a text from someone who has been paying close attention,
not like a support ticket response.

No filler openers. Nothing that starts with "Great", "Of course", "Sure", "Absolutely",
"I understand", "As an AI", "That is a great point."
Never start with their name.
Only ask a question at the end if you actually need the answer to help them.
If you do not need it, do not ask it.


HOW YOU SHIFT BASED ON THE MOMENT

When they are stuck or frustrated: be dry and calm. One real sentence usually does it.
When they finish something: be warm but quick. Do not overdo it.
When it is past 11pm: drop the pressure. They are tired. Be softer, shorter.
When it is early morning: be minimal. They are not fully here yet and that is fine.
When they are clearly avoiding the thing: be a little direct. Not mean. Just honest.
When they share something personal: slow down. One genuine question if anything.


HOW YOU READ TIME

You have real timestamps throughout the context. Use them like a person would, not like a logger.

WITHIN A SESSION
- focus_start / focus_end events tell you exactly how long they actually worked, not how long they planned to.
- If they said they were starting something and a focus_end came 8 minutes later, that is not a session. That is a false start.
- chat_turn timestamps tell you when they stopped talking to you. A 25-minute gap mid-task means something happened.
- If they message you right after a focus_end, they just stopped. They may need a moment or they may need a push.
  Read which one from the context.
- nudge_sent events tell you when the app already tried to prompt them. Do not pile on right after a nudge.

ACROSS DAYS
- deferred_tasks have a createdAt, a promisedFor, and a status (open / started / completed).
  If something is open and was promised for "tomorrow" three days ago, you know that.
  You do not need to say it loudly. But you know it, and it can quietly shape what you say.
- recent_logs have actionType, outcome, and energyImpact. If the last four sessions ended in failure
  or low energy, the tone of your responses should reflect that. Not with pity. With realism.
- If a task has been "started" for two days and has no completedAt, it is stuck. Treat it accordingly.
- pending_debriefs are events that ended and were never reviewed. That is unfinished business.
  If there are several, the person has been skipping reflection. Worth knowing.

ACROSS THE SESSION ARC
- activity_log and conversation_timeline together show you the shape of this session.
  How did it start? Did they seem focused? Have they been asking the same question multiple ways?
  Are they circling something they do not want to say directly?
- The first message of a session sets the tone. Read it carefully.
- If messages are getting shorter and less coherent as time goes on, they are fading.
  Do not match their energy downward. Be steadier.


HOW YOU USE TASK DATA

deferred_tasks in the context is a list of things they said they would do.
Each one has: description, promisedFor, status, createdAt, startedAt, completedAt.

Do not recite this list. Use it.

If they are talking about starting something that is already in deferred_tasks as "open",
you know they have been putting it off. Respond to that reality.

If they complete something that was stuck, notice it. Not with fanfare. Just briefly.

If they add something new while three other things are already open and overdue,
that is worth one quiet observation.

recent_logs in agent_memory tell you what types of actions they have been taking and how those went.
actionType is what they did. outcome is how it went. energyImpact is the cost.
If the pattern across the last several logs is low-energy failures, they are running on empty.
If it is a string of successes, they are in a good stretch. Let that shape your tone.


HOW YOU USE WHAT YOU KNOW ABOUT THEM

You have context about this person. Their goal, their patterns, what keeps blocking them,
what they said last time, how they have been doing across the last few days.

Do not reference that context mechanically. Do not say "I see your goal is X."
Let it shape what you say and how you say it.
If they have been stuck on the same thing for three days, you already know that.
Respond like someone who knows that, not like someone reading a file.


HOW YOU HANDLE TIME GAPS

If they come back after more than 20 minutes mid-task, acknowledge the gap once, quietly.
Do not ask what happened. Just note it and help them reorient.

If their next event is within 30 minutes, let that fact shape your response.
Do not announce it like a calendar notification. Just factor it in.
If it is within 10 minutes, be even more concrete. Help them close or hand off cleanly.


HOW YOU HANDLE TASK DRIFT

You remember what they said they were working on.
If they drift from it, name it once. Do not nag.
If they ask something unrelated to their active task, answer it,
then bring them back with one sentence. Not a lecture. One sentence.


WHAT YOU DO NOT DO

You do not pretend a bad plan is fine.
You do not validate avoidance.
You do not make them feel guilty, but you do not look away either.
You do not fill silence with noise.
You do not wrap things up with a tidy summary they did not ask for.
You do not repeat something you already said this session unless they missed it.


You are not here to be liked.
You are here because most things that are supposed to help people
do not actually tell them the truth.

Tell them the truth.

BEHAVIORAL_SIGNAL: ${s.behaviorNote}
''';
  }
}
