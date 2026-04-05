import 'package:flutter_test/flutter_test.dart';
import 'package:vyoma/core/models/user_preferences.dart';

void main() {
  group('UserPreferences', () {
    test('quiet hours work across midnight window', () {
      final prefs = UserPreferences(
        quietHoursEnabled: true,
        quietStart: '22:00',
        quietEnd: '08:00',
      );

      expect(prefs.isQuietHours(DateTime(2026, 3, 16, 23, 0)), isTrue);
      expect(prefs.isQuietHours(DateTime(2026, 3, 17, 7, 30)), isTrue);
      expect(prefs.isQuietHours(DateTime(2026, 3, 17, 12, 0)), isFalse);
    });

    test('effective review defaults to one hour before sleep', () {
      final prefs = UserPreferences(sleepTime: '23:30');
      expect(prefs.effectiveReviewTime, '22:30');
    });

    test('effective focus end defaults to two hours before sleep', () {
      final prefs = UserPreferences(sleepTime: '01:15');
      expect(prefs.effectiveFocusEnd, '23:15');
    });
  });
}
