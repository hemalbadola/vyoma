import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/council_models.dart';

/// Backend for The Council. v3 ships data plumbing only — UI lands in a
/// later phase once Witnesses retention validates that asymmetric
/// inter-personal contracts hold inside Vyoma.
class CouncilService {
  CouncilService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _members =>
      _firestore.collection('council_members');
  CollectionReference<Map<String, dynamic>> get _queries =>
      _firestore.collection('council_queries');

  Future<String> inviteAdvisor({
    required String advisorUid,
    required String domain,
  }) async {
    final me = _auth.currentUser;
    if (me == null) throw StateError('not signed in');
    if (advisorUid == me.uid) {
      throw ArgumentError('advisor cannot be yourself');
    }
    final member = CouncilMember(
      id: '',
      ownerUid: me.uid,
      advisorUid: advisorUid,
      domain: domain.trim(),
      invitedAt: DateTime.now(),
      status: CouncilStatus.pending,
    );
    final ref = await _members.add(member.toJson());
    return ref.id;
  }

  Future<void> updateStatus(String memberId, CouncilStatus status) async {
    await _members.doc(memberId).update({'status': status.name});
  }

  Stream<List<CouncilMember>> streamMyCouncil() {
    final me = _auth.currentUser;
    if (me == null) return Stream.value(const []);
    return _members
        .where('ownerUid', isEqualTo: me.uid)
        .snapshots()
        .map((snap) => snap.docs.map(CouncilMember.fromDoc).toList());
  }

  Future<String> ask({
    required String question,
    required String context,
    required List<String> advisorUids,
  }) async {
    final me = _auth.currentUser;
    if (me == null) throw StateError('not signed in');
    if (advisorUids.isEmpty) {
      throw ArgumentError('at least one advisor required');
    }
    final query = CouncilQuery(
      id: '',
      ownerUid: me.uid,
      question: question.trim(),
      context: context.trim(),
      advisorUids: advisorUids,
      responses: const {},
      askedAt: DateTime.now(),
    );
    final ref = await _queries.add(query.toJson());
    return ref.id;
  }

  Future<void> respondTo(String queryId, String response) async {
    final me = _auth.currentUser;
    if (me == null) return;
    await _queries.doc(queryId).update({
      'responses.${me.uid}': response.trim(),
    });
  }
}
