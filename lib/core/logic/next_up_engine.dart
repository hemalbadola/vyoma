import '../models/daily_stats.dart';
import '../models/task.dart';
import '../models/timetable.dart';

enum NextUpKind { focusBlock, classSession, task, reflection, rest }

class NextUpSuggestion {
  final NextUpKind kind;
  final String title;
  final String subtitle;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? relatedId;

  const NextUpSuggestion({
    required this.kind,
    required this.title,
    required this.subtitle,
    this.startTime,
    this.endTime,
    this.relatedId,
  });
}

class ClassSlot {
  final String id;
  final String name;
  final String venue;
  final DateTime startTime;
  final DateTime endTime;

  const ClassSlot({
    required this.id,
    required this.name,
    required this.venue,
    required this.startTime,
    required this.endTime,
  });
}

class Task {
  final String id;
  final String title;
  final DateTime? deadline;

  const Task({required this.id, required this.title, this.deadline});
}

class NextUpEngine {
  const NextUpEngine();

  NextUpSuggestion? compute({
    required DateTime now,
    required DailyStats todayStats,
    required List<ClassSlot> classesToday,
    required List<Task> tasks,
  }) {
    ClassSlot? upcomingClass;
    var nearestMinutes = 1 << 30;
    for (final slot in classesToday) {
      final mins = slot.startTime.difference(now).inMinutes;
      if (mins >= 0 && mins <= 15 && mins < nearestMinutes) {
        nearestMinutes = mins;
        upcomingClass = slot;
      }
    }
    if (upcomingClass != null) {
      return NextUpSuggestion(
        kind: NextUpKind.classSession,
        title: upcomingClass.name,
        subtitle:
            'Starts at ${_hhmm(upcomingClass.startTime)} • ${upcomingClass.venue}',
        startTime: upcomingClass.startTime,
        endTime: upcomingClass.endTime,
        relatedId: upcomingClass.id,
      );
    }

    final openTasks = _sortByDeadline(tasks);
    final isDayWindow = now.hour >= 8 && now.hour < 20;
    if (todayStats.focusMinutes < 50 && isDayWindow && openTasks.isNotEmpty) {
      final task = openTasks.first;
      return NextUpSuggestion(
        kind: NextUpKind.focusBlock,
        title: '25-min focus: ${task.title}',
        subtitle: 'Based on your low focus time today',
        relatedId: task.id,
      );
    }

    if (now.hour >= 20 && !todayStats.journaled) {
      return const NextUpSuggestion(
        kind: NextUpKind.reflection,
        title: 'One-line reflection',
        subtitle: 'Protect your journal streak',
      );
    }

    if (todayStats.focusMinutes >= 120) {
      return NextUpSuggestion(
        kind: NextUpKind.rest,
        title: 'Take a short break',
        subtitle:
            'You’ve already focused for ${todayStats.focusMinutes ~/ 60}h today',
      );
    }

    if (openTasks.isNotEmpty) {
      final task = openTasks.first;
      return NextUpSuggestion(
        kind: NextUpKind.task,
        title: 'Quick win: ${task.title}',
        subtitle: 'Finish a small task to keep momentum',
        relatedId: task.id,
      );
    }

    return null;
  }

  static List<ClassSlot> classSlotsForToday({
    required DateTime now,
    required List<TimetableSlot> timetableSlots,
  }) {
    final out = <ClassSlot>[];
    for (final slot in timetableSlots) {
      if (!_matchesWeekday(slot.dayOfWeek, now.weekday)) continue;
      final start = _toDateTime(now, slot.startTime);
      var end = _toDateTime(now, slot.endTime);
      if (end.isBefore(start)) {
        end = end.add(const Duration(days: 1));
      }
      out.add(
        ClassSlot(
          id: '${slot.subject}_${slot.startTime}_${slot.dayOfWeek}',
          name: slot.subject,
          venue: slot.venue,
          startTime: start,
          endTime: end,
        ),
      );
    }
    return out;
  }

  static List<Task> tasksFromVyomaTasks(List<VyomaTask> tasks) {
    return tasks
        .where((t) => !t.completed)
        .map((t) => Task(id: t.id, title: t.title, deadline: t.deadline))
        .toList();
  }

  static List<Task> _sortByDeadline(List<Task> tasks) {
    final copy = List<Task>.from(tasks);
    copy.sort((a, b) {
      final ad = a.deadline;
      final bd = b.deadline;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    });
    return copy;
  }

  static String _hhmm(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static DateTime _toDateTime(DateTime base, String hhmm) {
    final parts = hhmm.split(':');
    final h = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(base.year, base.month, base.day, h, m);
  }

  static bool _matchesWeekday(String dayOfWeek, int weekday) {
    const map = <String, int>{
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };
    return map[dayOfWeek.toLowerCase()] == weekday;
  }
}
