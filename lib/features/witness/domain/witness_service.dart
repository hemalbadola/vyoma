import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/witness_models.dart';

/// CRUD over `vows` collection. v0 holds at most one active vow per owner —
/// the UI enforces that, but the service does not block multiple. The single
/// active vow makes the value of asymmetric binding clear before we open up
/// to multiple parallel commitments.
class WitnessService {
  WitnessService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('vows');

  /// Creates a vow held by the current user, witnessed by [witnessUid].
  /// Returns the vow id.
  Future<String> createVow({
    required String witnessUid,
    required String vowText,
    required int durationDays,
  }) async {
    final me = _auth.currentUser;
    if (me == null) throw StateError('not signed in');
    if (witnessUid == me.uid) {
      throw ArgumentError('a witness cannot be yourself');
    }
    if (vowText.trim().isEmpty) {
      throw ArgumentError('vow text must not be empty');
    }
    if (durationDays < 1 || durationDays > 365) {
      throw ArgumentError('durationDays must be 1-365');
    }
    final now = DateTime.now();
    final vow = WitnessVow(
      id: '',
      ownerUid: me.uid,
      witnessUid: witnessUid,
      vowText: vowText.trim(),
      durationDays: durationDays,
      startedAt: now,
      expiresAt: now.add(Duration(days: durationDays)),
      checkIns: const <String>[],
      status: VowStatus.active,
    );
    final ref = await _col.add(vow.toJson());
    return ref.id;
  }

  /// Records a check-in for today. Idempotent — calling twice on the same
  /// day is a no-op. Auto-completes the vow if duration is reached.
  Future<void> checkInToday(String vowId) async {
    final me = _auth.currentUser;
    if (me == null) throw StateError('not signed in');
    final today = _dateKey(DateTime.now());
    final docRef = _col.doc(vowId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return;
      final vow = WitnessVow.fromDoc(snap);
      if (vow.ownerUid != me.uid) {
        throw StateError('only the owner can check in');
      }
      if (vow.status != VowStatus.active) return;
      if (vow.checkIns.contains(today)) return;
      final updated = [...vow.checkIns, today];
      final shouldComplete = updated.length >= vow.durationDays;
      tx.update(docRef, {
        'checkIns': updated,
        if (shouldComplete) 'status': VowStatus.completed.name,
      });
    });
  }

  /// Marks a vow as broken — owner explicitly walks away. The witness sees
  /// this in their list with full context.
  Future<void> breakVow(String vowId) async {
    final me = _auth.currentUser;
    if (me == null) return;
    await _col.doc(vowId).update({'status': VowStatus.broken.name});
  }

  /// Stream of vows owned by the current user, newest first.
  Stream<List<WitnessVow>> streamMyVows() {
    final me = _auth.currentUser;
    if (me == null) return Stream.value(const []);
    return _col
        .where('ownerUid', isEqualTo: me.uid)
        .snapshots()
        .map((snap) => snap.docs.map(WitnessVow.fromDoc).toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt)));
  }

  /// Stream of vows the current user is witnessing (held by others).
  Stream<List<WitnessVow>> streamVowsImWitnessing() {
    final me = _auth.currentUser;
    if (me == null) return Stream.value(const []);
    return _col
        .where('witnessUid', isEqualTo: me.uid)
        .snapshots()
        .map((snap) => snap.docs.map(WitnessVow.fromDoc).toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt)));
  }

  /// The single currently-active vow for the user, if any.
  Stream<WitnessVow?> streamActiveVow() {
    return streamMyVows().map((all) {
      for (final v in all) {
        if (v.status == VowStatus.active) return v;
      }
      return null;
    });
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
