import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_service.dart';

class TelemetryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  Timer? _heartbeatTimer;
  String? _localDeviceId;
  UserService? _userService;
  
  // Total tracked active milliseconds per session
  int _sessionActiveSeconds = 0; 
  DateTime _sessionStartTime = DateTime.now();

  TelemetryService() {
    _initDevice();
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _startHeartbeat(user.uid);
      } else {
        _stopHeartbeat();
      }
    });
  }

  Future<void> _initDevice() async {
    final prefs = await SharedPreferences.getInstance();
    _localDeviceId = prefs.getString('vyoma_device_id');
    if (_localDeviceId == null) {
      _localDeviceId = 'dev_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('vyoma_device_id', _localDeviceId!);
    }
  }

  String _getPlatform() {
    if (kIsWeb) return 'Web';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  void _startHeartbeat(String uid, {Duration interval = const Duration(seconds: 60)}) {
    _stopHeartbeat();
    
    // Privacy Shield: Only start if telemetry is enabled
    final profile = _userService?.profile;
    if (profile != null && !profile.enableTelemetry) {
      debugPrint("TELEMETRY: Shield Active. Heartbeat blocked.");
      return;
    }

    _sessionStartTime = DateTime.now();

    // Fire immediately upon authorization
    _transmitHeartbeat(uid);
    
    // Pulse based on desired interval (60s foreground, 5m background)
    _heartbeatTimer = Timer.periodic(interval, (timer) {
      _sessionActiveSeconds += interval.inSeconds;
      _transmitHeartbeat(uid);
    });
  }

  /// Injects user service to read privacy toggles
  void setUserService(UserService svc) => _userService = svc;

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _transmitHeartbeat(String uid) async {
    if (_localDeviceId == null) return;
    
    try {
      await _firestore
        .collection('users')
        .doc(uid)
        .collection('devices')
        .doc(_localDeviceId)
        .set({
          'platform': _getPlatform(),
          'lastSeen': FieldValue.serverTimestamp(),
          'isActive': true,       
          'sessionSeconds': _sessionActiveSeconds,
          'sessionStart': Timestamp.fromDate(_sessionStartTime),
        }, SetOptions(merge: true));

      // 2. Relay presence to root UserProfile for friend visibility (Respect Ghost Mode)
      final profile = _userService?.profile;
      if (profile != null && profile.showOnlineStatus) {
        await _firestore.collection('users').doc(uid).update({
          'lastSeenAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint("Telemetry transmission failed: $e");
    }
  }

  /// Called by the UI layer when the app goes into the background
  Future<void> notifyAppBackgrounded() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      // Scale heartbeat to Low Power Mode (5 mins) instead of stopping
      _startHeartbeat(uid, interval: const Duration(minutes: 5));
      
      if (_localDeviceId != null) {
        await _firestore
          .collection('users')
          .doc(uid)
          .collection('devices')
          .doc(_localDeviceId)
          .set({
            'isActive': false, // Still pulsing, but marked as background
            'lastSeen': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      }
    }
  }

  /// Called by the UI layer when the app returns to the foreground
  void notifyAppForegrounded() {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      // Restore High Fidelity Mode (60s)
      _startHeartbeat(uid, interval: const Duration(seconds: 60));
    }
  }

  /// Fetches the raw active device matrix for context passing to the AI
  Future<List<Map<String, dynamic>>> getCrossDeviceMatrix() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    try {
      final snap = await _firestore.collection('users').doc(uid).collection('devices').get();
      final now = DateTime.now();
      
      return snap.docs.map((doc) {
        final data = doc.data();
        final timestamp = (data['lastSeen'] as Timestamp?)?.toDate() ?? now;
        final minutesAgo = now.difference(timestamp).inMinutes;
        
        return {
          'id': doc.id,
          'platform': data['platform'] ?? 'Unknown',
          'isActive': data['isActive'] ?? false,
          'minutesSinceSeen': minutesAgo,
          'sessionTimeMins': (data['sessionSeconds'] ?? 0) ~/ 60,
        };
      }).toList();
    } catch(e) {
      debugPrint("getCrossDeviceMatrix error: $e");
      return [];
    }
  }
}
