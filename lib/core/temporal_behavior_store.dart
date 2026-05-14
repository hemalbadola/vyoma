import 'memory_service.dart';

/// Lightweight local telemetry for a personal "time fingerprint" (no cloud required).
class TemporalBehaviorStore {
  TemporalBehaviorStore(this._memory);

  final MemoryService _memory;
  static const _kLog = 'temporal_behavior_events';
  static const int _maxEvents = 500;

  List<Map<String, dynamic>> _readLog() {
    final raw = _memory.getSegment(_kLog);
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> _writeLog(List<Map<String, dynamic>> items) async {
    await _memory.updateSegment(_kLog, items);
  }

  /// [kind]: chat_turn | focus_end | focus_start | nudge_sent
  Future<void> record({
    required String kind,
    String? taskTitle,
    String? outcome,
    int? durationSeconds,
    int? sessionLengthChars,
  }) async {
    final list = _readLog();
    list.add({
      'ts': DateTime.now().toIso8601String(),
      'kind': kind,
      'task': taskTitle,
      'outcome': outcome,
      'duration_sec': durationSeconds,
      'session_len': sessionLengthChars,
    }..removeWhere((k, v) => v == null));
    while (list.length > _maxEvents) {
      list.removeAt(0);
    }
    await _writeLog(list);
  }

  /// Compressed line for system prompt (local-only moat).
  String compressedInsightForPrompt() {
    final list = _readLog();
    if (list.length < 8) {
      return 'Behavior fingerprint: still collecting baseline.';
    }

    final byWeekday = <int, int>{};
    var focusEnds = 0;
    var sumFocusMin = 0;
    for (final e in list) {
      final ts = DateTime.tryParse(e['ts']?.toString() ?? '');
      if (ts != null) {
        byWeekday[ts.weekday] = (byWeekday[ts.weekday] ?? 0) + 1;
      }
      if (e['kind'] == 'focus_end') {
        focusEnds++;
        final d = e['duration_sec'];
        if (d is int) sumFocusMin += d ~/ 60;
      }
    }

    final peakDay = byWeekday.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final peak = peakDay.isEmpty ? '?' : '${peakDay.first.key}';

    final avgFocusMin =
        focusEnds == 0 ? 0 : (sumFocusMin / focusEnds).round();

    return 'Behavior fingerprint: n=${list.length} '
        'peak_weekday=$peak '
        'avg_focus_session_min=$avgFocusMin '
        '(local log, private).';
  }
}
