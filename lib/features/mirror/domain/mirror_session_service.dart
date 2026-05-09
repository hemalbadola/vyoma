import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/mirror_session_models.dart';

/// CRUD for `mirror_sessions`. v0 is intentionally narrow: invite a single
/// partner, accept or decline, mark show-up and reflect at end.
///
/// What is *not* shipped in v0: chat/call (forbidden by design), batch
/// invites, recurring schedules. Those would dilute the constraint.
class MirrorSessionService {
  MirrorSessionService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('mirror_sessions');

  Future<String> propose({
    required String partnerUid,
    required DateTime scheduledFor,
    required int durationMinutes,
    required String taskType,
  }) async {
    final me = _auth.currentUser;
    if (me == null) throw StateError('not signed in');
    if (partnerUid == me.uid) {
      throw ArgumentError('mirror partner must be someone else');
    }
    if (taskType.trim().isEmpty) {
      throw ArgumentError('taskType must not be empty');
    }
    final session = MirrorSession(
      id: '',
      hostUid: me.uid,
      partnerUid: partnerUid,
      scheduledFor: scheduledFor,
      durationMinutes: durationMinutes,
      taskType: taskType.trim(),
      hostShowedUp: false,
      partnerShowedUp: false,
      hostReflection: '',
      partnerReflection: '',
      status: MirrorStatus.pending,
    );
    final ref = await _col.add(session.toJson());
    return ref.id;
  }

  Future<void> accept(String id) async {
    await _col.doc(id).update({'status': MirrorStatus.accepted.name});
  }

  Future<void> decline(String id) async {
    await _col.doc(id).update({'status': MirrorStatus.declined.name});
  }

  Future<void> markShowedUp(String id) async {
    final me = _auth.currentUser;
    if (me == null) return;
    final ref = _col.doc(id);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final s = MirrorSession.fromDoc(snap);
      if (!s.isMember(me.uid)) return;
      tx.update(ref, {
        if (me.uid == s.hostUid) 'hostShowedUp': true,
        if (me.uid == s.partnerUid) 'partnerShowedUp': true,
      });
    });
  }

  /// Submit your single-sentence reflection. Auto-completes the session if
  /// both reflections are present.
  Future<void> submitReflection(String id, String reflection) async {
    final me = _auth.currentUser;
    if (me == null) return;
    final ref = _col.doc(id);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final s = MirrorSession.fromDoc(snap);
      if (!s.isMember(me.uid)) return;
      final updated = <String, dynamic>{};
      if (me.uid == s.hostUid) {
        updated['hostReflection'] = reflection.trim();
      } else {
        updated['partnerReflection'] = reflection.trim();
      }
      final hostDone = me.uid == s.hostUid
          ? reflection.trim().isNotEmpty
          : s.hostReflection.isNotEmpty;
      final partnerDone = me.uid == s.partnerUid
          ? reflection.trim().isNotEmpty
          : s.partnerReflection.isNotEmpty;
      if (hostDone && partnerDone) {
        updated['status'] = MirrorStatus.completed.name;
      }
      tx.update(ref, updated);
    });
  }

  /// All sessions involving the current user, newest first.
  Stream<List<MirrorSession>> streamMine() {
    final me = _auth.currentUser;
    if (me == null) return Stream.value(const []);
    return _col
        .where('members', arrayContains: me.uid)
        .snapshots()
        .map((snap) => snap.docs.map(MirrorSession.fromDoc).toList()
          ..sort((a, b) => b.scheduledFor.compareTo(a.scheduledFor)));
  }
}
