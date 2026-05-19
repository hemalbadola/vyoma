import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/models/focus_block.dart';
import '../../../../core/services/subject_color_service.dart';

/// 24h analog clock: 00:00 at top, clockwise.
double minutesToRadians(int minutesSinceMidnight) {
  return (minutesSinceMidnight / 1440.0) * 2 * math.pi - math.pi / 2;
}

int minutesSinceMidnight(DateTime dt) => dt.hour * 60 + dt.minute;

Color colorForTask(String task, {SubjectColorService? colors}) {
  if (colors != null) return colors.colorFor(task);
  return SubjectColorService.resolveColor(task: task, storedValue: null);
}

class FocusClockArc {
  const FocusClockArc({
    required this.startMinutes,
    required this.endMinutes,
    required this.color,
    this.label,
    this.isLive = false,
  });

  final int startMinutes;
  final int endMinutes;
  final Color color;
  final String? label;
  final bool isLive;
}

List<FocusClockArc> arcsFromBlocks(
  List<FocusBlock> blocks,
  DateTime day, {
  SubjectColorService? colors,
}) {
  final dayStart = DateTime(day.year, day.month, day.day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  final out = <FocusClockArc>[];

  for (final b in blocks) {
    var start = b.start.isBefore(dayStart) ? dayStart : b.start;
    var end = b.end.isAfter(dayEnd) ? dayEnd : b.end;
    if (!end.isAfter(start)) continue;
    out.add(
      FocusClockArc(
        startMinutes: minutesSinceMidnight(start),
        endMinutes: minutesSinceMidnight(end),
        color: colors?.colorForBlock(
              task: b.task,
              storedValue: b.colorValue,
            ) ??
            b.displayColor,
        label: b.task,
      ),
    );
  }
  return out;
}

FocusClockArc? liveArc({
  required DateTime sessionStart,
  required String task,
  required DateTime day,
  SubjectColorService? colors,
}) {
  final dayStart = DateTime(day.year, day.month, day.day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  var start = sessionStart.isBefore(dayStart) ? dayStart : sessionStart;
  final now = DateTime.now();
  var end = now.isAfter(dayEnd) ? dayEnd : now;
  if (!end.isAfter(start)) return null;
  return FocusClockArc(
    startMinutes: minutesSinceMidnight(start),
    endMinutes: minutesSinceMidnight(end),
    color: colors?.colorFor(task) ?? colorForTask(task),
    label: task,
    isLive: true,
  );
}
