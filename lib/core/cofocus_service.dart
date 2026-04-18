import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/pact.dart';

class CoFocusService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  /// Creates a new pact challenge between users
  Future<String?> createPact({
    required String title,
    required int targetMinutes,
    required DateTime deadline,
    required List<String> invitedUids,
  }) async {
    if (_uid == null) return null;

    final pact = Pact(
      id: '',
      creatorUid: _uid!,
      title: title,
      targetMinutes: targetMinutes,
      deadline: deadline,
      participants: [_uid!], // Creator is automatically in
      progressMinutes: {_uid!: 0},
      status: PactStatus.pending,
    );

    try {
      final docRef = await _firestore.collection('pacts').add(pact.toFirestore());
      return docRef.id;
    } catch (e) {
      debugPrint("CoFocusService: Failed to create pact: $e");
      return null;
    }
  }

  /// Accepts an invite to a pact, often coming from a deep link.
  Future<bool> joinPact(String pactId) async {
    if (_uid == null) return false;

    try {
      final pactRef = _firestore.collection('pacts').doc(pactId);
      final doc = await pactRef.get();
      if (!doc.exists) return false;

      final pact = Pact.fromFirestore(doc);
      if (pact.participants.contains(_uid!)) return true; // Already joined

      await pactRef.update({
        'participants': FieldValue.arrayUnion([_uid!]),
        'progressMinutes.$_uid': 0,
        if (pact.status == PactStatus.pending) 'status': PactStatus.active.name, // Switch to active when 2nd person joins
      });
      return true;
    } catch (e) {
      debugPrint("CoFocusService: Failed to join pact: $e");
      return false;
    }
  }

  /// Called by AccountabilityService/TaskService when focus time completes
  Future<void> logFocusProgress(int minutes) async {
    if (_uid == null || minutes <= 0) return;

    try {
      // Find active pacts the user is in
      final snap = await _firestore
          .collection('pacts')
          .where('participants', arrayContains: _uid)
          .where('status', isEqualTo: PactStatus.active.name)
          .get();

      if (snap.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        final pact = Pact.fromFirestore(doc);
        final currentProgress = pact.progressMinutes[_uid!] ?? 0;
        final newProgress = currentProgress + minutes;
        
        batch.update(doc.reference, {
          'progressMinutes.$_uid': newProgress,
        });

        // Auto-complete logic
        if (newProgress >= pact.targetMinutes) {
          // Check if ALL participants have completed
          bool allDone = true;
          pact.progressMinutes.forEach((id, val) {
            if (id == _uid) {
               if (newProgress < pact.targetMinutes) allDone = false;
            } else {
               if (val < pact.targetMinutes) allDone = false;
            }
          });
          
          if (allDone && pact.participants.length > 1) {
             batch.update(doc.reference, {
               'status': PactStatus.completed.name,
             });
          }
        }
      }
      await batch.commit();
    } catch (e) {
      debugPrint("CoFocusService: Failed to log progress: $e");
    }
  }

  /// Streams active pacts for the current user
  Stream<List<Pact>> streamActivePacts() {
    if (_uid == null) return Stream.value([]);
    return _firestore
        .collection('pacts')
        .where('participants', arrayContains: _uid!)
        .where('status', whereIn: [PactStatus.pending.name, PactStatus.active.name])
        .snapshots()
        .map((snap) => snap.docs.map((d) => Pact.fromFirestore(d)).toList());
  }

  /// Deep link router handling
  Future<void> handleDeepLinkInvite(String pactId) async {
    final joined = await joinPact(pactId);
    if (joined) {
      debugPrint("Successfully joined pact from deep link!");
    } else {
      debugPrint("Failed or already joined pact.");
    }
  }
}
