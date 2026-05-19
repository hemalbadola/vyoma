import 'models/focus_block.dart';
import 'memory_service.dart';
import 'services/subject_color_service.dart';

/// YPT-style focus blocks: what you worked on, start/end, duration (local memory).
class FocusTimelineStore {
  FocusTimelineStore(this._memory);

  final MemoryService _memory;
  static const _kSegment = 'focus_timeline_blocks';
  static const int _maxBlocks = 400;

  List<Map<String, dynamic>> _readRaw() {
    final raw = _memory.getSegment(_kSegment);
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> _writeRaw(List<Map<String, dynamic>> items) async {
    await _memory.updateSegment(_kSegment, items);
  }

  Future<void> recordSession({
    required DateTime start,
    required DateTime end,
    required String task,
    String mode = 'flow',
  }) async {
    if (!end.isAfter(start)) return;
    final label = task.trim().isEmpty ? 'Focus' : task.trim();
    final color = SubjectColorService(_memory).colorValueFor(label);
    final list = _readRaw();
    list.add({
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'task': label,
      'mode': mode,
      'color': color,
    });
    while (list.length > _maxBlocks) {
      list.removeAt(0);
    }
    await _writeRaw(list);
  }

  List<FocusBlock> allBlocks() {
    return _readRaw().map(FocusBlock.fromJson).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  List<FocusBlock> blocksForDay(DateTime day) {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return allBlocks()
        .where(
          (b) =>
              b.end.isAfter(startOfDay) && b.start.isBefore(endOfDay),
        )
        .toList();
  }

  int totalMinutesForDay(DateTime day) {
    var sum = 0;
    for (final b in blocksForDay(day)) {
      sum += b.durationMinutes;
    }
    return sum;
  }

  /// Minutes per task label for today (for breakdown UI).
  Map<String, int> minutesByTaskForDay(DateTime day) {
    final map = <String, int>{};
    for (final b in blocksForDay(day)) {
      map[b.task] = (map[b.task] ?? 0) + b.durationMinutes;
    }
    return map;
  }

  FocusBlock? longestBlockForDay(DateTime day) {
    final blocks = blocksForDay(day);
    if (blocks.isEmpty) return null;
    return blocks.reduce(
      (a, b) => a.durationMinutes >= b.durationMinutes ? a : b,
    );
  }

  /// Recent blocks for LLM (newest first, capped).
  List<Map<String, dynamic>> blocksForPrompt({int limit = 20}) {
    final blocks = allBlocks();
    if (blocks.isEmpty) return const [];
    final tail = blocks.length <= limit
        ? blocks
        : blocks.sublist(blocks.length - limit);
    return tail.reversed.map((b) => b.toJson()).toList();
  }

  /// Human + machine summary for temporal / system blocks.
  String summaryForPrompt({int limit = 12}) {
    final recent = blocksForPrompt(limit: limit);
    if (recent.isEmpty) {
      return 'No recorded focus blocks yet (use /focus start <task> then /focus stop).';
    }
    final buf = StringBuffer('Recent focus blocks (newest first): ');
    for (var i = 0; i < recent.length && i < 8; i++) {
      final e = recent[i];
      final task = e['task'] ?? '?';
      final min = e['duration_min'] ?? 0;
      final mode = e['mode'] ?? 'flow';
      final start = e['start']?.toString() ?? '';
      if (i > 0) buf.write('; ');
      buf.write('$task ${min}m ($mode) @ $start');
    }
    return buf.toString();
  }
}
