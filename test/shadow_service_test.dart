import 'package:flutter_test/flutter_test.dart';
import 'package:vyoma/core/models/task.dart';
import 'package:vyoma/features/shadow/domain/shadow_service.dart';

VyomaTask _task({
  required String id,
  required String title,
  required DateTime created,
  bool completed = false,
  DateTime? deadline,
}) {
  return VyomaTask(
    id: id,
    title: title,
    createdAt: created,
    deadline: deadline,
    completed: completed,
  );
}

void main() {
  const service = ShadowService();
  final now = DateTime(2026, 5, 9, 12, 0);

  test('returns null when nothing carried long enough', () {
    final p = service.topDeferralPattern(
      [
        _task(
          id: '1',
          title: 'recent task',
          created: now.subtract(const Duration(days: 2)),
        ),
      ],
      now: now,
    );
    expect(p, isNull);
  });

  test('skips completed tasks', () {
    final p = service.topDeferralPattern(
      [
        _task(
          id: '1',
          title: 'old but done',
          created: now.subtract(const Duration(days: 30)),
          completed: true,
        ),
      ],
      now: now,
    );
    expect(p, isNull);
  });

  test('picks the most-overdue task when multiple qualify', () {
    final mild = _task(
      id: 'mild',
      title: 'mild carry',
      created: now.subtract(const Duration(days: 8)),
    );
    final severe = _task(
      id: 'severe',
      title: 'thesis intro',
      created: now.subtract(const Duration(days: 25)),
      deadline: now.subtract(const Duration(days: 10)),
    );
    final p = service.topDeferralPattern([mild, severe], now: now);
    expect(p?.taskId, 'severe');
    expect(p!.daysOverdue, 10);
    expect(p.daysCarried, 25);
  });

  test('framing line mentions overdue when applicable', () {
    final t = _task(
      id: 'x',
      title: 'finish chapter 3',
      created: now.subtract(const Duration(days: 21)),
      deadline: now.subtract(const Duration(days: 5)),
    );
    final p = service.topDeferralPattern([t], now: now);
    expect(p, isNotNull);
    expect(p!.framing(), contains('finish chapter 3'));
    expect(p.framing(), contains('21'));
    expect(p.framing(), contains('5 past'));
  });

  test('does not surface low-severity carries', () {
    final t = _task(
      id: 'low',
      title: 'small thing',
      created: now.subtract(const Duration(days: 7)),
    );
    final p = service.topDeferralPattern([t], now: now);
    expect(p, isNull,
        reason: 'severity at the floor should not surface');
  });
}
