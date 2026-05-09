class DailyStats {
  final String id;
  final int focusMinutes;
  final int tasksCompleted;
  final bool journaled;
  final String? oneThing;
  final String? energyLevel;

  const DailyStats({
    required this.id,
    this.focusMinutes = 0,
    this.tasksCompleted = 0,
    this.journaled = false,
    this.oneThing,
    this.energyLevel,
  });

  DailyStats copyWith({
    String? id,
    int? focusMinutes,
    int? tasksCompleted,
    bool? journaled,
    String? oneThing,
    bool clearOneThing = false,
    String? energyLevel,
    bool clearEnergyLevel = false,
  }) {
    return DailyStats(
      id: id ?? this.id,
      focusMinutes: focusMinutes ?? this.focusMinutes,
      tasksCompleted: tasksCompleted ?? this.tasksCompleted,
      journaled: journaled ?? this.journaled,
      oneThing: clearOneThing ? null : (oneThing ?? this.oneThing),
      energyLevel: clearEnergyLevel ? null : (energyLevel ?? this.energyLevel),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'focusMinutes': focusMinutes,
      'tasksCompleted': tasksCompleted,
      'journaled': journaled,
      'oneThing': oneThing,
      'energyLevel': energyLevel,
    };
  }

  factory DailyStats.fromJson(Map<String, dynamic> json) {
    return DailyStats(
      id: json['id'] as String? ?? '',
      focusMinutes: json['focusMinutes'] as int? ?? 0,
      tasksCompleted: json['tasksCompleted'] as int? ?? 0,
      journaled: json['journaled'] as bool? ?? false,
      oneThing: json['oneThing'] as String?,
      energyLevel: json['energyLevel'] as String?,
    );
  }
}
