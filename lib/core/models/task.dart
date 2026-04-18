class VyomaTask {
  final String id;
  final String title;
  final String? description;
  final String? project; // Goal bucket: "Academics", "Product", etc.
  final DateTime createdAt;
  final DateTime? deadline;
  final bool completed;
  final DateTime? completedAt;
  final int focusMinutes; // Accumulated focus time on this task
  final String priority; // "high", "normal", "low"

  VyomaTask({
    required this.id,
    required this.title,
    this.description,
    this.project,
    required this.createdAt,
    this.deadline,
    this.completed = false,
    this.completedAt,
    this.focusMinutes = 0,
    this.priority = 'normal',
  });

  VyomaTask copyWith({
    String? title,
    String? description,
    String? project,
    DateTime? deadline,
    bool? completed,
    DateTime? completedAt,
    int? focusMinutes,
    String? priority,
  }) {
    return VyomaTask(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      project: project ?? this.project,
      createdAt: createdAt,
      deadline: deadline ?? this.deadline,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
      focusMinutes: focusMinutes ?? this.focusMinutes,
      priority: priority ?? this.priority,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'project': project,
    'createdAt': createdAt.toIso8601String(),
    'deadline': deadline?.toIso8601String(),
    'completed': completed,
    'completedAt': completedAt?.toIso8601String(),
    'focusMinutes': focusMinutes,
    'priority': priority,
  };

  factory VyomaTask.fromJson(Map<String, dynamic> json) {
    return VyomaTask(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      project: json['project'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      deadline: json['deadline'] != null ? DateTime.tryParse(json['deadline']) : null,
      completed: json['completed'] ?? false,
      completedAt: json['completedAt'] != null ? DateTime.tryParse(json['completedAt']) : null,
      focusMinutes: json['focusMinutes'] ?? 0,
      priority: json['priority'] ?? 'normal',
    );
  }

  /// True if deadline is today or already passed
  bool get isOverdue {
    if (deadline == null || completed) return false;
    return deadline!.isBefore(DateTime.now());
  }

  /// True if deadline is today
  bool get isDueToday {
    if (deadline == null) return false;
    final now = DateTime.now();
    return deadline!.year == now.year && deadline!.month == now.month && deadline!.day == now.day;
  }

  /// Days until deadline (negative if overdue)
  int? get daysUntilDeadline {
    if (deadline == null) return null;
    final now = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final due = DateTime(deadline!.year, deadline!.month, deadline!.day);
    return due.difference(now).inDays;
  }
}
