import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DateTime Validation', () {
    final now = DateTime.parse("2026-03-20T16:43:00+05:30");
    // Assume an event was stored in Google Calendar at 11:05 local time.
    // If it was submitted as UTC, it would be "2026-03-20T05:35:00Z".
    final startDt = DateTime.parse("2026-03-20T05:35:00Z");
    
    // Check what toLocal() does:
    print("now: \${now}");
    print("startDt UTC: \${startDt}");
    print("startDt Local: \${startDt.toLocal()}");
    
    final isActive = startDt.isBefore(now) && startDt.add(const Duration(hours: 1)).isAfter(now);
    print("isActive: \$isActive");
  });
}
