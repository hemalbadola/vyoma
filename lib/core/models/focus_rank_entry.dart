class FocusRankEntry {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int focusMinutesThisWeek;
  final bool isPreview;

  const FocusRankEntry({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.focusMinutesThisWeek,
    this.isPreview = false,
  });
}
