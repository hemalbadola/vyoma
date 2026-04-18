import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DateTime Validation', () {
    final now = DateTime.parse("2026-03-20T16:43:00+05:30");
    final startDt = DateTime.parse("2026-03-20T05:35:00Z");
    final localStart = startDt.toLocal();

    expect(localStart.hour, 11);
    expect(localStart.minute, 5);
    expect(localStart.isUtc, isFalse);

    final isActive = startDt.isBefore(now) && startDt.add(const Duration(hours: 1)).isAfter(now);
    expect(isActive, isFalse);
  });
}
