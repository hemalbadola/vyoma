import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String username;
  final String displayName;
  final String tagline;
  final int weeklyFocusGoalMinutes;
  final String? currentIntention;
  final DateTime? intentionSetAt;
  final DateTime createdAt;
  final String timezone;
  final List<String> activeTasks;
  final DateTime? lastSeenAt;
  final bool shareTasksWithFriends;
  final bool showOnlineStatus;
  final bool enableTelemetry;
  final bool shareIntention;

  UserProfile({
    required this.uid,
    required this.username,
    required this.displayName,
    this.tagline = '',
    this.weeklyFocusGoalMinutes = 600, // Default 10 hours
    this.currentIntention,
    this.intentionSetAt,
    required this.createdAt,
    required this.timezone,
    this.activeTasks = const [],
    this.lastSeenAt,
    this.shareTasksWithFriends = true,
    this.showOnlineStatus = true,
    this.enableTelemetry = true,
    this.shareIntention = true,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists) throw Exception("User profile does not exist!");
    final data = doc.data() as Map<String, dynamic>;
    
    return UserProfile(
      uid: doc.id,
      username: data['username'] ?? '',
      displayName: data['displayName'] ?? '',
      tagline: data['tagline'] ?? '',
      weeklyFocusGoalMinutes: data['weeklyFocusGoalMinutes'] ?? 600,
      currentIntention: data['currentIntention'],
      intentionSetAt: data['intentionSetAt'] != null 
          ? (data['intentionSetAt'] as Timestamp).toDate() 
          : null,
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      timezone: data['timezone'] ?? 'UTC',
      activeTasks: data['activeTasks'] != null 
          ? List<String>.from(data['activeTasks'])
          : [],
      lastSeenAt: data['lastSeenAt'] != null 
          ? (data['lastSeenAt'] as Timestamp).toDate() 
          : null,
      shareTasksWithFriends: data['shareTasksWithFriends'] ?? true,
      showOnlineStatus: data['showOnlineStatus'] ?? true,
      enableTelemetry: data['enableTelemetry'] ?? true,
      shareIntention: data['shareIntention'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'username': username,
      'uid': uid,
      'displayName': displayName,
      'tagline': tagline,
      'weeklyFocusGoalMinutes': weeklyFocusGoalMinutes,
      if (currentIntention != null) 'currentIntention': currentIntention,
      if (intentionSetAt != null) 'intentionSetAt': Timestamp.fromDate(intentionSetAt!),
      'createdAt': Timestamp.fromDate(createdAt),
      'timezone': timezone,
      'activeTasks': activeTasks,
      if (lastSeenAt != null) 'lastSeenAt': Timestamp.fromDate(lastSeenAt!),
      'shareTasksWithFriends': shareTasksWithFriends,
      'showOnlineStatus': showOnlineStatus,
      'enableTelemetry': enableTelemetry,
      'shareIntention': shareIntention,
      // Used for quick presence/existence checks
      'username_lower': username.toLowerCase(), 
    };
  }

  UserProfile copyWith({
    String? displayName,
    String? tagline,
    int? weeklyFocusGoalMinutes,
    String? currentIntention,
    DateTime? intentionSetAt,
    String? timezone,
    List<String>? activeTasks,
    DateTime? lastSeenAt,
    bool? shareTasksWithFriends,
    bool? showOnlineStatus,
    bool? enableTelemetry,
    bool? shareIntention,
  }) {
    return UserProfile(
      uid: uid,
      username: username,
      displayName: displayName ?? this.displayName,
      tagline: tagline ?? this.tagline,
      weeklyFocusGoalMinutes: weeklyFocusGoalMinutes ?? this.weeklyFocusGoalMinutes,
      currentIntention: currentIntention ?? this.currentIntention,
      intentionSetAt: intentionSetAt ?? this.intentionSetAt,
      createdAt: createdAt,
      timezone: timezone ?? this.timezone,
      activeTasks: activeTasks ?? this.activeTasks,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      shareTasksWithFriends: shareTasksWithFriends ?? this.shareTasksWithFriends,
      showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
      enableTelemetry: enableTelemetry ?? this.enableTelemetry,
      shareIntention: shareIntention ?? this.shareIntention,
    );
  }
}
