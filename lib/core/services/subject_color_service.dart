import 'package:flutter/material.dart';

import '../memory_service.dart';

/// Stable color per subject/task label (persisted, shared across timeline + clock).
class SubjectColorService {
  SubjectColorService(this._memory);

  final MemoryService _memory;
  static const _kSegment = 'subject_color_map';

  static const List<Color> palette = [
    Color(0xFF3B82F6),
    Color(0xFF06B6D4),
    Color(0xFF8B5CF6),
    Color(0xFF10B981),
    Color(0xFFD4AF72),
    Color(0xFFEC4899),
    Color(0xFFF59E0B),
    Color(0xFF14B8A6),
    Color(0xFF6366F1),
    Color(0xFFE879F9),
    Color(0xFF84CC16),
    Color(0xFFF97316),
  ];

  Map<String, int> _read() {
    final raw = _memory.getSegment(_kSegment);
    if (raw is! Map) return {};
    return raw.map(
      (k, v) => MapEntry(
        k.toString(),
        v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0),
      ),
    );
  }

  Future<void> _save(Map<String, int> map) async {
    await _memory.updateSegment(_kSegment, map);
  }

  static String normalize(String subject) =>
      subject.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  Color colorFor(String subject) {
    final key = normalize(subject);
    if (key.isEmpty) return palette.first;

    final map = _read();
    final existing = map[key];
    if (existing != null && existing != 0) {
      return Color(existing);
    }

    final used = map.values.toSet();
    Color pick = palette[key.hashCode.abs() % palette.length];
    for (final c in palette) {
      if (!used.contains(c.toARGB32())) {
        pick = c;
        break;
      }
    }

    map[key] = pick.toARGB32();
    _save(map);
    return pick;
  }

  int colorValueFor(String subject) => colorFor(subject).toARGB32();

  Color colorForBlock({required String task, int? storedValue}) =>
      resolveColor(task: task, storedValue: storedValue);

  /// Use stored block color when present; otherwise hash fallback (no memory).
  static Color resolveColor({required String task, int? storedValue}) {
    if (storedValue != null && storedValue != 0) {
      return Color(storedValue);
    }
    final key = normalize(task);
    if (key.isEmpty) return palette.first;
    return palette[key.hashCode.abs() % palette.length];
  }

  Map<String, Color> colorsForSubjects(Iterable<String> subjects) {
    final out = <String, Color>{};
    for (final s in subjects) {
      final t = s.trim();
      if (t.isEmpty) continue;
      out[t] = colorFor(t);
    }
    return out;
  }
}
