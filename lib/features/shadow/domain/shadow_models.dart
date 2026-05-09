/// A pattern detected by [ShadowService]. v0 only emits one type:
/// a deferral pattern on a single task that has been carried for too long.
///
/// `daysCarried` is the number of days since the task was created (capped at
/// 365). `severity` is a normalized 0..1 score used by the UI to decide
/// whether to surface the pattern at all.
class ShadowPattern {
  const ShadowPattern({
    required this.taskId,
    required this.taskTitle,
    required this.daysCarried,
    required this.daysOverdue,
    required this.severity,
  });

  final String taskId;
  final String taskTitle;
  final int daysCarried;
  final int daysOverdue;
  final double severity;

  /// The framing line the UI surfaces. Tone is intentionally non-confronting:
  /// "want to talk about it?" not "you failed."
  String framing() {
    if (daysOverdue > 0) {
      return "you have carried '$taskTitle' for $daysCarried days, "
          '$daysOverdue past its deadline.';
    }
    return "you have carried '$taskTitle' for $daysCarried days.";
  }
}
