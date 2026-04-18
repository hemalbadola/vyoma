import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/user_profile.dart';

class UserService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  UserProfile? _currentProfile;
  UserProfile? get currentProfile => _currentProfile;

  bool _isProfileLoaded = false;
  bool get isProfileLoaded => _isProfileLoaded;
  bool get hasProfile => _currentProfile != null;
  UserProfile? get profile => _currentProfile;

  UserService() {
    // Listen to Firebase Auth state
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _listenToProfile(user.uid);
      } else {
        _currentProfile = null;
        _isProfileLoaded = true;
        notifyListeners();
      }
    });
  }

  void _listenToProfile(String uid) {
    _firestore.collection('users').doc(uid).snapshots().listen((doc) {
      if (doc.exists) {
        _currentProfile = UserProfile.fromFirestore(doc);
      } else {
        _currentProfile = null;
      }
      _isProfileLoaded = true;
      notifyListeners();
    }, onError: (e) {
      debugPrint("UserService snapshot error: $e");
      _isProfileLoaded = true;
      _currentProfile = null;
      notifyListeners();
    });
  }

  /// Checks the isolated 'usernames' collection for O(1) existence check
  Future<bool> isUsernameAvailable(String username) async {
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.isEmpty || cleanUsername.length < 3) return false;

    final query = await _firestore.collection('usernames').doc(cleanUsername).get();
    return !query.exists;
  }

  /// Generates the initial profile and registers the username globally
  Future<void> createProfile({
    required String username,
    required String tagline,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Not authenticated with Firebase");

    final cleanUsername = username.trim();
    if (cleanUsername.isEmpty) throw Exception("Username cannot be empty");

    final available = await isUsernameAvailable(cleanUsername);
    if (!available) throw Exception("Username '$cleanUsername' is already taken.");

    final batch = _firestore.batch();
    
    // 1. Write the main User Profile
    final userRef = _firestore.collection('users').doc(user.uid);
    final profile = UserProfile(
      uid: user.uid,
      username: cleanUsername,
      displayName: user.displayName ?? cleanUsername,
      tagline: tagline.trim(),
      createdAt: DateTime.now(),
      timezone: DateTime.now().timeZoneName,
    );
    batch.set(userRef, profile.toFirestore());

    // 2. Lock the username in the global index
    final usernameRef = _firestore.collection('usernames').doc(cleanUsername.toLowerCase());
    batch.set(usernameRef, {
      'uid': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Sets the daily public "intention" broadcast to friends
  Future<void> setIntention(String intention) async {
    final user = _auth.currentUser;
    if (user == null || !hasProfile) return;

    await _firestore.collection('users').doc(user.uid).update({
      'currentIntention': intention.trim(),
      'intentionSetAt': FieldValue.serverTimestamp(),
    });
  }

  /// Syncs top active task string titles up to the user's public profile
  Future<void> syncActiveTasks(List<String> tasks) async {
    final user = _auth.currentUser;
    if (user == null || !hasProfile) return;

    await _firestore.collection('users').doc(user.uid).update({
      'activeTasks': tasks,
    });
  }

  /// Updates granular sharing preferences
  Future<void> updatePrivacySetting({
    bool? shareTasks,
    bool? showOnline,
    bool? telemetry,
    bool? intention,
  }) async {
    final user = _auth.currentUser;
    if (user == null || !hasProfile) return;

    final Map<String, dynamic> updates = {};
    if (shareTasks != null) updates['shareTasksWithFriends'] = shareTasks;
    if (showOnline != null) updates['showOnlineStatus'] = showOnline;
    if (telemetry != null) updates['enableTelemetry'] = telemetry;
    if (intention != null) updates['shareIntention'] = intention;

    if (updates.isNotEmpty) {
      await _firestore.collection('users').doc(user.uid).update(updates);
    }
  }
}
