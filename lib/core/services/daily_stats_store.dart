import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_stats.dart';

abstract class DailyStatsStore {
  Future<DailyStats> loadForDate(DateTime date);
  Future<void> save(DailyStats stats);
  Stream<DailyStats> watchForDate(DateTime date);
  Future<int> computeJournalStreakUpTo(DateTime date);
}

class SharedPrefsDailyStatsStore implements DailyStatsStore {
  final Map<String, DailyStats> _cache = <String, DailyStats>{};
  final Map<String, StreamController<DailyStats>> _controllers =
      <String, StreamController<DailyStats>>{};

  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  String _idFromDate(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }

  String _keyForId(String id) => 'daily_stats::$id';

  DailyStats _defaultForId(String id) => DailyStats(id: id);

  @override
  Future<DailyStats> loadForDate(DateTime date) async {
    final id = _idFromDate(date);
    if (_cache.containsKey(id)) return _cache[id]!;

    final prefs = await _getPrefs();
    final raw = prefs.getString(_keyForId(id));
    if (raw == null || raw.trim().isEmpty) {
      final stats = _defaultForId(id);
      _cache[id] = stats;
      return stats;
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final stats = DailyStats.fromJson(decoded);
      _cache[id] = stats.id.isEmpty ? _defaultForId(id) : stats;
      return _cache[id]!;
    } catch (_) {
      final stats = _defaultForId(id);
      _cache[id] = stats;
      return stats;
    }
  }

  @override
  Future<void> save(DailyStats stats) async {
    final prefs = await _getPrefs();
    final normalized = stats.id.isEmpty
        ? _defaultForId(_idFromDate(DateTime.now()))
        : stats;
    _cache[normalized.id] = normalized;
    await prefs.setString(
      _keyForId(normalized.id),
      jsonEncode(normalized.toJson()),
    );

    final controller = _controllers[normalized.id];
    if (controller != null && !controller.isClosed) {
      controller.add(normalized);
    }
  }

  @override
  Stream<DailyStats> watchForDate(DateTime date) {
    final id = _idFromDate(date);
    final controller = _controllers.putIfAbsent(
      id,
      () => StreamController<DailyStats>.broadcast(
        onListen: () async {
          final current = await loadForDate(date);
          _controllers[id]?.add(current);
        },
      ),
    );
    return controller.stream;
  }

  @override
  Future<int> computeJournalStreakUpTo(DateTime date) async {
    var streak = 0;
    var cursor = DateTime(date.year, date.month, date.day);

    while (true) {
      final stats = await loadForDate(cursor);
      if (!stats.journaled) break;
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return streak;
  }
}
