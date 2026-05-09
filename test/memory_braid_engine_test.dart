import 'package:flutter_test/flutter_test.dart';
import 'package:vyoma/core/logic/memory_braid_engine.dart';
import 'package:vyoma/core/memory_service.dart';

JournalEntry _entry({
  required String id,
  required String text,
  required DateTime when,
}) {
  return JournalEntry(
    id: id,
    timestamp: when,
    text: text,
    mood: 'neutral',
    tags: const [],
    actionableCount: 0,
    acceptedInsights: const [],
  );
}

void main() {
  const engine = MemoryBraidEngine();
  final now = DateTime(2026, 5, 9, 12, 0);

  test('returns null when no entries match', () {
    final result = engine.braid(
      intent: 'finish chapter 3 draft',
      entries: [
        _entry(
          id: '1',
          text: 'went for a run by the river',
          when: now.subtract(const Duration(days: 30)),
        ),
      ],
      now: now,
    );
    expect(result, isNull);
  });

  test('returns null when intent is empty', () {
    final result = engine.braid(intent: '', entries: const [], now: now);
    expect(result, isNull);
  });

  test('skips entries that are too recent', () {
    final result = engine.braid(
      intent: 'finish chapter draft',
      entries: [
        _entry(
          id: 'recent',
          text: 'finish chapter draft tomorrow',
          when: now.subtract(const Duration(days: 1)),
        ),
      ],
      now: now,
    );
    expect(result, isNull,
        reason: 'entries within minAgeDays should not surface');
  });

  test('picks highest keyword overlap when both eligible', () {
    final weak = _entry(
      id: 'weak',
      text: 'going to write something today',
      when: now.subtract(const Duration(days: 14)),
    );
    final strong = _entry(
      id: 'strong',
      text: 'stuck on chapter 3 introduction paragraphs again',
      when: now.subtract(const Duration(days: 21)),
    );
    final result = engine.braid(
      intent: 'finish chapter 3 introduction',
      entries: [weak, strong],
      now: now,
    );
    expect(result?.id, 'strong');
  });

  test('prefers more recent entry when overlap is equal', () {
    final older = _entry(
      id: 'older',
      text: 'thesis introduction needs work',
      when: now.subtract(const Duration(days: 200)),
    );
    final newer = _entry(
      id: 'newer',
      text: 'thesis introduction needs work',
      when: now.subtract(const Duration(days: 30)),
    );
    final result = engine.braid(
      intent: 'finish thesis introduction',
      entries: [older, newer],
      now: now,
    );
    expect(result?.id, 'newer');
  });

  test('ignores stopwords-only intent', () {
    final result = engine.braid(
      intent: 'the and a one',
      entries: [
        _entry(
          id: '1',
          text: 'meaningful entry about real work',
          when: now.subtract(const Duration(days: 10)),
        ),
      ],
      now: now,
    );
    expect(result, isNull);
  });
}
