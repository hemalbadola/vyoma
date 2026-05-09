import 'package:cloud_firestore/cloud_firestore.dart';

/// A scheduled "mirror session" between two users — same time window, same
/// task type, no chat, no call. The session ends with one yes/no
/// (did each side show up?) and a single-sentence reflection per side.
///
/// The constraint is the whole point. Parallel presence + asymmetric
/// vulnerability. Borrows from sangha practice without being woo.
class MirrorSession {
  const MirrorSession({
    required this.id,
    required this.hostUid,
    required this.partnerUid,
    required this.scheduledFor,
    required this.durationMinutes,
    required this.taskType,
    required this.hostShowedUp,
    required this.partnerShowedUp,
    required this.hostReflection,
    required this.partnerReflection,
    required this.status,
  });

  final String id;
  final String hostUid;
  final String partnerUid;
  final DateTime scheduledFor;
  final int durationMinutes;
  /// Free-form short label: "writing", "studying", "deep work".
  final String taskType;
  final bool hostShowedUp;
  final bool partnerShowedUp;
  final String hostReflection;
  final String partnerReflection;
  final MirrorStatus status;

  bool isMember(String uid) => uid == hostUid || uid == partnerUid;
  String otherUid(String me) => me == hostUid ? partnerUid : hostUid;

  Map<String, dynamic> toJson() => {
        'hostUid': hostUid,
        'partnerUid': partnerUid,
        'scheduledFor': Timestamp.fromDate(scheduledFor),
        'durationMinutes': durationMinutes,
        'taskType': taskType,
        'hostShowedUp': hostShowedUp,
        'partnerShowedUp': partnerShowedUp,
        'hostReflection': hostReflection,
        'partnerReflection': partnerReflection,
        'status': status.name,
        'members': [hostUid, partnerUid],
      };

  factory MirrorSession.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return MirrorSession(
      id: doc.id,
      hostUid: d['hostUid'] as String? ?? '',
      partnerUid: d['partnerUid'] as String? ?? '',
      scheduledFor: (d['scheduledFor'] as Timestamp?)?.toDate() ?? DateTime.now(),
      durationMinutes: (d['durationMinutes'] as num?)?.toInt() ?? 60,
      taskType: d['taskType'] as String? ?? 'deep work',
      hostShowedUp: d['hostShowedUp'] as bool? ?? false,
      partnerShowedUp: d['partnerShowedUp'] as bool? ?? false,
      hostReflection: d['hostReflection'] as String? ?? '',
      partnerReflection: d['partnerReflection'] as String? ?? '',
      status: MirrorStatus.values.firstWhere(
        (s) => s.name == d['status'],
        orElse: () => MirrorStatus.pending,
      ),
    );
  }
}

enum MirrorStatus { pending, accepted, completed, declined }
