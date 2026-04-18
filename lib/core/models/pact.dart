import 'package:cloud_firestore/cloud_firestore.dart';

enum PactStatus { pending, active, completed, failed }

class Pact {
  final String id;
  final String creatorUid;
  final String title;
  final int targetMinutes;
  final DateTime deadline;
  final PactStatus status;
  final List<String> participants;
  final Map<String, int> progressMinutes; // UID -> minutes

  Pact({
    required this.id,
    required this.creatorUid,
    required this.title,
    required this.targetMinutes,
    required this.deadline,
    this.status = PactStatus.pending,
    required this.participants,
    required this.progressMinutes,
  });

  factory Pact.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Pact(
      id: doc.id,
      creatorUid: data['creatorUid'] ?? '',
      title: data['title'] ?? '',
      targetMinutes: data['targetMinutes'] ?? 0,
      deadline: data['deadline'] != null 
          ? (data['deadline'] as Timestamp).toDate() 
          : DateTime.now(),
      status: _parseStatus(data['status']),
      participants: List<String>.from(data['participants'] ?? []),
      progressMinutes: Map<String, int>.from(data['progressMinutes'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'creatorUid': creatorUid,
      'title': title,
      'targetMinutes': targetMinutes,
      'deadline': Timestamp.fromDate(deadline),
      'status': status.name,
      'participants': participants,
      'progressMinutes': progressMinutes,
    };
  }

  static PactStatus _parseStatus(String? raw) {
    switch (raw) {
      case 'active': return PactStatus.active;
      case 'completed': return PactStatus.completed;
      case 'failed': return PactStatus.failed;
      case 'pending': 
      default:
        return PactStatus.pending;
    }
  }
}
