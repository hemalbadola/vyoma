import '../../../core/models/task.dart';

/// Predicted cognitive load across the next N days, normalized 0..1.
class LoadForecast {
  const LoadForecast({
    required this.daily,
    required this.peakDayIndex,
    required this.peakLabel,
  });

  /// One entry per day starting from today (index 0). Each value 0..1.
  final List<double> daily;
  /// Index into [daily] for the peak load day, or -1 if all-zero.
  final int peakDayIndex;
  /// Short caption for the peak day (e.g. "thursday").
  final String peakLabel;

  bool get isEmpty => peakDayIndex < 0;
}

/// v0 forecast: pure heuristic on task deadlines + age. No calendar yet.
///
/// We're solving a cold-start problem here: real predictive value requires
/// 60+ days of data. The shipped v0 is honest about its scope — it's a
/// "deadline density visualizer", and it ships now to validate the surface.
class CognitiveLoadForecaster {
  const CognitiveLoadForecaster();

  static const _horizonDays = 7;

  LoadForecast forecast(List<VyomaTask> tasks, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    final today = DateTime(clock.year, clock.month, clock.day);
    final daily = List<double>.filled(_horizonDays, 0);

    int overdueCount = 0;
    for (final t in tasks) {
      if (t.completed) continue;
      final deadline = t.deadline;
      if (deadline == null) continue;
      final dayOfDeadline =
          DateTime(deadline.year, deadline.month, deadline.day);
      final delta = dayOfDeadline.difference(today).inDays;
      if (delta < 0) {
        overdueCount++;
        continue;
      }
      if (delta >= _horizonDays) continue;
      daily[delta] += 1;
    }

    // Each task on a day contributes a base 0.25; overdue adds a flat
    // 0.10 to every day for the next 3 days (the cost of carry).
    for (int i = 0; i < daily.length; i++) {
      daily[i] *= 0.25;
      if (i < 3) daily[i] += overdueCount * 0.04;
    }

    // Normalize to 0..1 — saturate at 1.0 (anything >= 1.0 is "stop adding").
    for (int i = 0; i < daily.length; i++) {
      if (daily[i] > 1.0) daily[i] = 1.0;
    }

    int peakIdx = -1;
    double peak = 0;
    for (int i = 0; i < daily.length; i++) {
      if (daily[i] > peak + 0.001) {
        peak = daily[i];
        peakIdx = i;
      }
    }
    String peakLabel = '';
    if (peakIdx >= 0) {
      final peakDay = today.add(Duration(days: peakIdx));
      peakLabel = _weekday(peakDay.weekday);
    }
    return LoadForecast(
      daily: daily,
      peakDayIndex: peakIdx,
      peakLabel: peakLabel,
    );
  }

  String _weekday(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'monday';
      case DateTime.tuesday:
        return 'tuesday';
      case DateTime.wednesday:
        return 'wednesday';
      case DateTime.thursday:
        return 'thursday';
      case DateTime.friday:
        return 'friday';
      case DateTime.saturday:
        return 'saturday';
      case DateTime.sunday:
        return 'sunday';
    }
    return '';
  }
}
