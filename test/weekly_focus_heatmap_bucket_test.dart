import 'package:flutter_test/flutter_test.dart';
import 'package:vyoma/features/progress/presentation/widgets/weekly_focus_heatmap.dart';

void main() {
  test('bucketForMinutes maps ranges correctly', () {
    expect(bucketForMinutes(0), FocusBucket.none);
    expect(bucketForMinutes(10), FocusBucket.low);
    expect(bucketForMinutes(30), FocusBucket.medium);
    expect(bucketForMinutes(60), FocusBucket.high);
  });
}
