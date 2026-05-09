import 'package:flutter_test/flutter_test.dart';
import 'package:vyoma/core/logic/next_up_engine.dart';
import 'package:vyoma/core/models/daily_stats.dart';

void main() {
  const engine = NextUpEngine();

  test('prefers class session within 15 minutes', () {
    final now = DateTime(2026, 5, 9, 9, 50);
    final suggestion = engine.compute(
      now: now,
      todayStats: const DailyStats(id: '2026-05-09'),
      classesToday: [
        ClassSlot(
          id: 'c1',
          name: 'PCS 693',
          venue: 'CR 206',
          startTime: DateTime(2026, 5, 9, 10, 0),
          endTime: DateTime(2026, 5, 9, 11, 0),
        ),
      ],
      tasks: const [Task(id: 't1', title: 'Read notes')],
    );

    expect(suggestion, isNotNull);
    expect(suggestion!.kind, NextUpKind.classSession);
  });

  test('suggests focus block for low focus with open tasks', () {
    final now = DateTime(2026, 5, 9, 11, 0);
    final suggestion = engine.compute(
      now: now,
      todayStats: const DailyStats(id: '2026-05-09', focusMinutes: 20),
      classesToday: const [],
      tasks: const [Task(id: 't1', title: 'Assignment')],
    );

    expect(suggestion, isNotNull);
    expect(suggestion!.kind, NextUpKind.focusBlock);
    expect(suggestion.title, contains('25-min focus'));
  });

  test('suggests reflection in evening when not journaled', () {
    final now = DateTime(2026, 5, 9, 21, 0);
    final suggestion = engine.compute(
      now: now,
      todayStats: const DailyStats(id: '2026-05-09', journaled: false),
      classesToday: const [],
      tasks: const [],
    );

    expect(suggestion, isNotNull);
    expect(suggestion!.kind, NextUpKind.reflection);
  });

  test('suggests rest when already focused 120+ minutes', () {
    final now = DateTime(2026, 5, 9, 16, 0);
    final suggestion = engine.compute(
      now: now,
      todayStats: const DailyStats(id: '2026-05-09', focusMinutes: 140),
      classesToday: const [],
      tasks: const [],
    );

    expect(suggestion, isNotNull);
    expect(suggestion!.kind, NextUpKind.rest);
  });
}
