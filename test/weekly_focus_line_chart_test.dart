import 'package:flutter_test/flutter_test.dart';
import 'package:vyoma/core/models/daily_stats.dart';
import 'package:vyoma/features/progress/presentation/widgets/weekly_focus_line_chart.dart';

void main() {
  test('orderedLast14Days keeps oldest to newest', () {
    final input = [
      const DailyStats(id: '2026-05-05'),
      const DailyStats(id: '2026-05-03'),
      const DailyStats(id: '2026-05-04'),
    ];
    final ordered = orderedLast14Days(input);
    expect(ordered.map((e) => e.id).toList(), [
      '2026-05-03',
      '2026-05-04',
      '2026-05-05',
    ]);
  });
}
