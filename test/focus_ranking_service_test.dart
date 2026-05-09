import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyoma/core/models/daily_stats.dart';
import 'package:vyoma/core/services/daily_stats_store.dart';
import 'package:vyoma/core/services/focus_ranking_service.dart';

class _FakeDailyStatsStore implements DailyStatsStore {
  @override
  Future<int> computeJournalStreakUpTo(DateTime date) async => 0;

  @override
  Future<DailyStats> loadForDate(DateTime date) async {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return DailyStats(id: '${date.year}-$mm-$dd', focusMinutes: 30);
  }

  @override
  Future<void> save(DailyStats stats) async {}

  @override
  Stream<DailyStats> watchForDate(DateTime date) => const Stream.empty();
}

void main() {
  test('ranking fallback returns only self when no friends', () async {
    final service = PreviewFocusRankingService(
      dailyStatsStore: _FakeDailyStatsStore(),
      friendIdsStream: Stream<List<String>>.value(const <String>[]),
      currentUserIdGetter: () => 'me',
      currentDisplayNameGetter: () => 'You',
      myMinutesLoader: () async => 120,
    );

    final entries = await service.watchWeeklyRanking().first;
    expect(entries.length, 1);
    expect(entries.first.userId, 'me');
    expect(entries.first.focusMinutesThisWeek, 120);
  });

  test('ranking includes preview friend entries', () async {
    final controller = StreamController<List<String>>();
    final service = PreviewFocusRankingService(
      dailyStatsStore: _FakeDailyStatsStore(),
      friendIdsStream: controller.stream,
      currentUserIdGetter: () => 'me',
      currentDisplayNameGetter: () => 'You',
      myMinutesLoader: () async => 100,
    );

    controller.add(const ['f1', 'f2']);
    final entries = await service.watchWeeklyRanking().first;
    expect(entries.where((e) => e.isPreview).length, 2);
    await controller.close();
  });
}
