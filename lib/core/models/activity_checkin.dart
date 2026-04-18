import 'package:cloud_firestore/cloud_firestore.dart';

enum ActivityType {
  taskCompleted,
  focusSession,
  timetableBlock,
  intentionSet,
}

class ActivityCheckin {
  final String id;
  final String userId;
  final ActivityType type;
  final String label;
  final int durationMinutes;
  final int points;
  final DateTime timestamp;
  final String visibility; // 'public' or 'private'

  ActivityCheckin({
    required this.id,
    required this.userId,
    required this.type,
    required this.label,
    this.durationMinutes = 0,
    required this.points,
    required this.timestamp,
    this.visibility = 'public',
  });

  factory ActivityCheckin.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ActivityCheckin(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: _parseType(data['type'] ?? ''),
      label: data['label'] ?? '',
      durationMinutes: data['durationMinutes'] ?? 0,
      points: data['points'] ?? 0,
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      visibility: data['visibility'] ?? 'public',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type.name,
      'label': label,
      'durationMinutes': durationMinutes,
      'points': points,
      'timestamp': Timestamp.fromDate(timestamp),
      'visibility': visibility,
    };
  }

  static ActivityType _parseType(String raw) {
    switch (raw) {
      case 'taskCompleted':
        return ActivityType.taskCompleted;
      case 'focusSession':
        return ActivityType.focusSession;
      case 'timetableBlock':
        return ActivityType.timetableBlock;
      case 'intentionSet':
        return ActivityType.intentionSet;
      default:
        return ActivityType.taskCompleted;
    }
  }

  /// Point rules:
  /// - Task completed: 10 pts flat
  /// - Focus session: 1 pt per minute
  /// - Timetable block adhered: 20 pts flat
  /// - Intention set: 5 pts flat
  static int computePoints(ActivityType type, {int durationMinutes = 0}) {
    switch (type) {
      case ActivityType.taskCompleted:
        return 10;
      case ActivityType.focusSession:
        return durationMinutes.clamp(0, 480); // 1pt/min, max 8hr
      case ActivityType.timetableBlock:
        return 20;
      case ActivityType.intentionSet:
        return 5;
    }
  }
}
