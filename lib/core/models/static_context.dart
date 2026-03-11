class StaticContext {
  final String mainGoal;
  final List<String> fixedTimetable;

  StaticContext({
    required this.mainGoal,
    required this.fixedTimetable,
  });

  // Default empty context for initialization
  factory StaticContext.initial() {
    return StaticContext(
      mainGoal: "Clear 11 Backlogs", // Default hardcoded as per mission parameters
      fixedTimetable: [], // Empty for now, to be filled by user later
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'main_goal': mainGoal,
      'timetable': fixedTimetable,
    };
  }
}
