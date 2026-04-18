import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/activity_checkin.dart';

/// Centralized service responsible for recording all accountability events
/// to Firestore. Other services (TaskService, TimetableService) call into
/// this after their local mutations succeed.
class AccountabilityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  /// Records a single activity checkin to the global `activities` collection.
  Future<void> recordCheckin({
    required ActivityType type,
    required String label,
    int durationMinutes = 0,
    String visibility = 'public',
  }) async {
    if (_uid == null) return;

    final points = ActivityCheckin.computePoints(type, durationMinutes: durationMinutes);

    final checkin = ActivityCheckin(
      id: '', // Firestore auto-generates
      userId: _uid!,
      type: type,
      label: label,
      durationMinutes: durationMinutes,
      points: points,
      timestamp: DateTime.now(),
      visibility: visibility,
    );

    try {
      await _firestore.collection('activities').add(checkin.toFirestore());
      debugPrint('AccountabilityService: Recorded ${type.name} → $points pts');
    } catch (e) {
      debugPrint('AccountabilityService: Failed to record checkin: $e');
    }
  }

  /// Convenience: task completed → 10 pts
  Future<void> onTaskCompleted(String taskTitle) async {
    await recordCheckin(
      type: ActivityType.taskCompleted,
      label: taskTitle,
    );
  }

  /// Convenience: focus session ended → 1 pt/min
  Future<void> onFocusSessionEnded(String taskTitle, int minutes) async {
    await recordCheckin(
      type: ActivityType.focusSession,
      label: taskTitle,
      durationMinutes: minutes,
    );
  }

  /// Convenience: timetable block adhered → 20 pts
  Future<void> onTimetableBlockAdhered(String subject) async {
    await recordCheckin(
      type: ActivityType.timetableBlock,
      label: subject,
    );
  }

  /// Convenience: intention set → 5 pts
  Future<void> onIntentionSet(String intention) async {
    await recordCheckin(
      type: ActivityType.intentionSet,
      label: intention,
    );
  }

  /// Retrieves checkins for a list of UIDs within a time window.
  /// Used by AI context injection and leaderboard calculations.
  Stream<List<ActivityCheckin>> streamActivitiesForUsers(
    List<String> uids, {
    Duration window = const Duration(hours: 24),
  }) {
    if (uids.isEmpty) return Stream.value([]);

    final cutoff = DateTime.now().subtract(window);
    final safeUids = uids.take(30).toList();

    return _firestore
        .collection('activities')
        .where('userId', whereIn: safeUids)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(cutoff))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ActivityCheckin.fromFirestore(d)).toList());
  }

  /// Fetch a one-shot list of checkins for weekly leaderboard computation.
  Future<List<ActivityCheckin>> getWeeklyActivitiesForUsers(List<String> uids) async {
    if (uids.isEmpty) return [];
    
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final safeUids = uids.take(30).toList();
    
    final snap = await _firestore
        .collection('activities')
        .where('userId', whereIn: safeUids)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(weekAgo))
        .orderBy('timestamp', descending: true)
        .get();
    
    return snap.docs.map((d) => ActivityCheckin.fromFirestore(d)).toList();
  }

  /// Builds a summary string of friend activities for AI prompt injection.
  /// Returns a compact JSON-like string the AI can parse.
  Future<String> buildFriendActivitySummary(List<String> friendUids) async {
    if (friendUids.isEmpty) return '[]';

    try {
      final cutoff = DateTime.now().subtract(const Duration(hours: 24));
      final safeUids = friendUids.take(10).toList();

      final snap = await _firestore
          .collection('activities')
          .where('userId', whereIn: safeUids)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(cutoff))
          .where('visibility', isEqualTo: 'public')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      if (snap.docs.isEmpty) return '[]';

      final items = snap.docs.map((d) {
        final data = d.data();
        return {
          'user': data['userId'],
          'type': data['type'],
          'label': data['label'],
          'points': data['points'],
          'minutes_ago': DateTime.now()
              .difference((data['timestamp'] as Timestamp).toDate())
              .inMinutes,
        };
      }).toList();

      return items.toString();
    } catch (e) {
      debugPrint('AccountabilityService: Failed to build friend summary: $e');
      return '[]';
    }
  }
}
