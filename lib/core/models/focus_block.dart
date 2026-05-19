import 'package:flutter/material.dart';

import '../services/subject_color_service.dart' show SubjectColorService;

/// One completed focus block for timeline UI and AI context.
class FocusBlock {
  const FocusBlock({
    required this.start,
    required this.end,
    required this.task,
    this.mode = 'flow',
    this.colorValue,
  });

  final DateTime start;
  final DateTime end;
  final String task;
  /// flow | pomodoro | ultradian | deep
  final String mode;
  /// ARGB32 subject color (stable across sessions).
  final int? colorValue;

  int get durationSeconds => end.difference(start).inSeconds;

  int get durationMinutes => (durationSeconds / 60).ceil();

  Color get displayColor =>
      SubjectColorService.resolveColor(task: task, storedValue: colorValue);

  Map<String, dynamic> toJson() => {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'task': task,
        'mode': mode,
        'duration_min': durationMinutes,
        if (colorValue != null) 'color': colorValue,
      };

  factory FocusBlock.fromJson(Map<String, dynamic> json) {
    final start = DateTime.tryParse(json['start']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final end = DateTime.tryParse(json['end']?.toString() ?? '') ?? start;
    final colorRaw = json['color'];
    final color = colorRaw is int
        ? colorRaw
        : (colorRaw is num ? colorRaw.toInt() : int.tryParse('$colorRaw'));
    return FocusBlock(
      start: start,
      end: end,
      task: json['task']?.toString() ?? 'Focus',
      mode: json['mode']?.toString() ?? 'flow',
      colorValue: color,
    );
  }
}
