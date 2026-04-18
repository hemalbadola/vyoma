import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/user_profile.dart';

class FriendService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Generates the composite ID safely based on chronological sorting
  String _getFriendshipId(String uid1, String uid2) {
    final list = [uid1, uid2]..sort();
    return "${list[0]}_${list[1]}";
  }

  /// Sends a friend invite to the target UID
  Future<void> sendInvite(String targetUid) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid == targetUid) return;

    final id = _getFriendshipId(currentUser.uid, targetUid);
    
    await _firestore.collection('friendships').doc(id).set({
      'users': [currentUser.uid, targetUid],
      'status': 'pending',
      'requesterId': currentUser.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Accepts a pending invite
  Future<void> acceptInvite(String targetUid) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final id = _getFriendshipId(currentUser.uid, targetUid);
    
    await _firestore.collection('friendships').doc(id).update({
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Decline or remove a friend
  Future<void> removeFriend(String targetUid) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    
    final id = _getFriendshipId(currentUser.uid, targetUid);
    await _firestore.collection('friendships').doc(id).delete();
  }

  /// Get stream of accepted friends' UIDs for mapping to progress updates
  Stream<List<String>> getAcceptedFriendUidsStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('friendships')
        .where('users', arrayContains: currentUser.uid)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final users = List<String>.from(doc['users']);
        return users.firstWhere((uid) => uid != currentUser.uid);
      }).toList();
    });
  }

  /// Get Future list of accepted friends' UIDs for one-time fetch (like AI context)
  Future<List<String>> getAcceptedFriendUids() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    final snap = await _firestore
        .collection('friendships')
        .where('users', arrayContains: currentUser.uid)
        .where('status', isEqualTo: 'accepted')
        .get();

    return snap.docs.map((doc) {
      final users = List<String>.from(doc['users']);
      return users.firstWhere((uid) => uid != currentUser.uid);
    }).toList();
  }

  /// Maps an active UID list directly to real-time UserProfile objects
  Stream<List<UserProfile>> streamProfiles(List<String> uids) {
    if (uids.isEmpty) return Stream.value([]);
    
    // Firestore 'whereIn' is strictly capped at 30 constraints natively
    final safeUids = uids.take(30).toList();
    
    return _firestore
        .collection('users')
        .where(FieldPath.documentId, whereIn: safeUids)
        .snapshots()
        .map((snap) => snap.docs.map((d) => UserProfile.fromFirestore(d)).toList());
  }

  /// Retrieve incoming invites to render UI badges
  Stream<List<String>> getIncomingInvitesStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('friendships')
        .where('users', arrayContains: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      // Only return invites where we are not the requester
      return snapshot.docs
          .where((doc) => doc['requesterId'] != currentUser.uid)
          .map((doc) {
            final users = List<String>.from(doc['users']);
            return users.firstWhere((uid) => uid != currentUser.uid);
          })
          .toList();
    });
  }

  /// Looks up a UID from a username safely (flat collection)
  Future<String?> resolveUsernameToUid(String username) async {
    final query = await _firestore.collection('usernames').doc(username.trim().toLowerCase()).get();
    if (query.exists) {
      return query.data()?['uid'] as String?;
    }
    return null;
  }
}
