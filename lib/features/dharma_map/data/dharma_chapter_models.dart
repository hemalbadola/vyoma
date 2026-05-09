/// A three-month chapter of the user's life. Replaces yearly goals with a
/// shorter, narrative-shaped commitment. Each chapter has a single-word
/// theme, one master skill, and three concrete outcomes.
///
/// Chapters are intentionally short (90 days) so closing one is a real event
/// — closing ceremony, then a Bindu-led intent for the next chapter.
class DharmaChapter {
  const DharmaChapter({
    required this.id,
    required this.themeWord,
    required this.masterSkill,
    required this.outcomes,
    required this.startedAt,
    this.closedAt,
  });

  final String id;
  /// Single word capturing the season ("rigor", "softness", "shipping").
  final String themeWord;
  /// One craft to deepen ("writing", "Mandarin", "research").
  final String masterSkill;
  /// Up to three concrete deliverables/states.
  final List<String> outcomes;
  final DateTime startedAt;
  final DateTime? closedAt;

  bool get isOpen => closedAt == null;

  Duration get age => DateTime.now().difference(startedAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'themeWord': themeWord,
        'masterSkill': masterSkill,
        'outcomes': outcomes,
        'startedAt': startedAt.toIso8601String(),
        'closedAt': closedAt?.toIso8601String(),
      };

  factory DharmaChapter.fromJson(Map<String, dynamic> json) {
    return DharmaChapter(
      id: json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      themeWord: json['themeWord'] as String? ?? '',
      masterSkill: json['masterSkill'] as String? ?? '',
      outcomes: (json['outcomes'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ??
          DateTime.now(),
      closedAt: json['closedAt'] != null
          ? DateTime.tryParse(json['closedAt'] as String)
          : null,
    );
  }

  DharmaChapter copyWith({
    String? themeWord,
    String? masterSkill,
    List<String>? outcomes,
    DateTime? closedAt,
  }) {
    return DharmaChapter(
      id: id,
      themeWord: themeWord ?? this.themeWord,
      masterSkill: masterSkill ?? this.masterSkill,
      outcomes: outcomes ?? this.outcomes,
      startedAt: startedAt,
      closedAt: closedAt ?? this.closedAt,
    );
  }
}
