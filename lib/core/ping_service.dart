import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

class PingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _pingSub;
  final DateTime _startupTime = DateTime.now();

  PingService(this._notificationService) {
    final initial = _auth.currentUser;
    if (initial != null) {
      _listenForPings(initial.uid);
    }
    _authSub = _auth.authStateChanges().listen((user) {
      if (user != null) {
        _listenForPings(user.uid);
      } else {
        _pingSub?.cancel();
        _pingSub = null;
      }
    });
  }

  void dispose() {
    _authSub?.cancel();
    _pingSub?.cancel();
  }

  void _listenForPings(String uid) {
    _pingSub?.cancel();
    _pingSub = _firestore
        .collection('pings')
        .where('toUid', isEqualTo: uid)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(_startupTime))
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          final fromName = data['fromName'] ?? 'An agent';
          final taskTitle = data['taskTitle'] ?? 'a task';
          
          _notificationService.notifyNow(
            title: 'Nudge from $fromName',
            body: "Don't forget to finish: $taskTitle",
          );
        }
      }
    }, onError: (e) {
      debugPrint("PingService listener error: $e");
    });
  }

  Future<void> sendPing({
    required String toUid,
    required String taskTitle,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Must be logged in to ping");

    // Fetch sender's profile for the display name
    final doc = await _firestore.collection('users').doc(user.uid).get();
    final fromName = doc.data()?['displayName'] ?? user.displayName ?? 'An agent';

    await _firestore.collection('pings').add({
      'fromUid': user.uid,
      'fromName': fromName,
      'toUid': toUid,
      'taskTitle': taskTitle,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
