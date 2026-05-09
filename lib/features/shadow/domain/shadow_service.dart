import '../../../core/models/task.dart';
import 'shadow_models.dart';

/// Detects a single "deferral" pattern across the user's active tasks.
///
/// v0 is deliberately narrow: one pattern type, one detector. We need to
/// validate that users find the surface useful and not confronting before
/// expanding to journal-language analysis or completion-rate tracking.
class ShadowService {
  const ShadowService();

  // A task must be at least this old before it counts as "carried."
  // 7 days is the minimum window where carrying is a pattern, not a backlog.
  static const _minDaysCarriedToSurface = 7;

  /// Returns the most concerning deferral pattern, or null if nothing crosses
  /// the threshold. The UI should treat null as "do not surface anything."
  ShadowPattern? topDeferralPattern(
    List<VyomaTask> tasks, {
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    ShadowPattern? best;
    for (final task in tasks) {
      if (task.completed) continue;
      final daysCarried = clock.difference(task.createdAt).inDays;
      if (daysCarried < _minDaysCarriedToSurface) continue;
      final daysOverdue = task.deadline != null
          ? clock.difference(task.deadline!).inDays
          : 0;
      final severity = _severity(daysCarried: daysCarried, daysOverdue: daysOverdue);
      if (severity < 0.3) continue;
      if (best == null || severity > best.severity) {
        best = ShadowPattern(
          taskId: task.id,
          taskTitle: task.title,
          daysCarried: daysCarried > 365 ? 365 : daysCarried,
          daysOverdue: daysOverdue < 0 ? 0 : daysOverdue,
          severity: severity,
        );
      }
    }
    return best;
  }

  /// 0..1 score combining how long the task has been carried and how far
  /// past its deadline it is (if any). Linear weights — v0 is a heuristic.
  double _severity({required int daysCarried, required int daysOverdue}) {
    final carriedScore = (daysCarried.clamp(0, 30)) / 30.0; // saturates at 30d
    final overdueScore = (daysOverdue.clamp(0, 30)) / 30.0;
    final score = (carriedScore * 0.6) + (overdueScore * 0.4);
    return score.clamp(0.0, 1.0);
  }
}
