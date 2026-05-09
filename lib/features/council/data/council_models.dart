import 'package:cloud_firestore/cloud_firestore.dart';

/// A specific friend invited to be an advisor for a domain (career, health,
/// creative work). Inspired by Marcus Aurelius's mental council and modern
/// peer-mentorship structures.
///
/// v3 ships only the data model + minimal service. UI lands in a later
/// phase once Witnesses retention is proven.
class CouncilMember {
  const CouncilMember({
    required this.id,
    required this.ownerUid,
    required this.advisorUid,
    required this.domain,
    required this.invitedAt,
    required this.status,
  });

  final String id;
  final String ownerUid;
  final String advisorUid;
  /// Free-text domain label: "career", "health", "creative work".
  final String domain;
  final DateTime invitedAt;
  final CouncilStatus status;

  Map<String, dynamic> toJson() => {
        'ownerUid': ownerUid,
        'advisorUid': advisorUid,
        'domain': domain,
        'invitedAt': Timestamp.fromDate(invitedAt),
        'status': status.name,
      };

  factory CouncilMember.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return CouncilMember(
      id: doc.id,
      ownerUid: d['ownerUid'] as String? ?? '',
      advisorUid: d['advisorUid'] as String? ?? '',
      domain: d['domain'] as String? ?? '',
      invitedAt: (d['invitedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: CouncilStatus.values.firstWhere(
        (s) => s.name == d['status'],
        orElse: () => CouncilStatus.pending,
      ),
    );
  }
}

enum CouncilStatus { pending, accepted, declined, ended }

/// A question put to one or more council members. Each addressed advisor
/// returns a single short paragraph; Vyoma synthesizes themes for the user.
class CouncilQuery {
  const CouncilQuery({
    required this.id,
    required this.ownerUid,
    required this.question,
    required this.context,
    required this.advisorUids,
    required this.responses,
    required this.askedAt,
  });

  final String id;
  final String ownerUid;
  final String question;
  /// Brief reflection or framing the user includes alongside the question.
  final String context;
  final List<String> advisorUids;
  /// Map of advisorUid -> response paragraph (empty until they reply).
  final Map<String, String> responses;
  final DateTime askedAt;

  Map<String, dynamic> toJson() => {
        'ownerUid': ownerUid,
        'question': question,
        'context': context,
        'advisorUids': advisorUids,
        'responses': responses,
        'askedAt': Timestamp.fromDate(askedAt),
      };

  factory CouncilQuery.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final rawResponses = d['responses'] as Map<String, dynamic>? ?? const {};
    return CouncilQuery(
      id: doc.id,
      ownerUid: d['ownerUid'] as String? ?? '',
      question: d['question'] as String? ?? '',
      context: d['context'] as String? ?? '',
      advisorUids: (d['advisorUids'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      responses:
          rawResponses.map((k, v) => MapEntry(k, v.toString())),
      askedAt: (d['askedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
