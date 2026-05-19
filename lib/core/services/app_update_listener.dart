import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/app_config.dart';
import '../notification_service.dart';
import '../update_service.dart';

/// Listens to Firestore `config/app_version` and notifies all signed-in clients.
class AppUpdateListener {
  AppUpdateListener(this._notifications);

  final NotificationService _notifications;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  StreamSubscription<User?>? _authSub;
  String? _lastNotifiedVersion;
  BuildContext? _hostContext;

  void attachHostContext(BuildContext context) {
    _hostContext = context;
  }

  void start() {
    _authSub?.cancel();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _sub?.cancel();
      _sub = null;
      if (user == null) return;
      _sub = FirebaseFirestore.instance
          .collection('config')
          .doc('app_version')
          .snapshots()
          .listen(_onSnapshot, onError: (e) {
        debugPrint('APP_UPDATE_LISTENER: $e');
      });
    });
  }

  void dispose() {
    _authSub?.cancel();
    _sub?.cancel();
    _sub = null;
  }

  Future<void> _onSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) async {
    if (!snap.exists) return;
    final data = snap.data();
    if (data == null) return;

    final latest = (data['latest_version'] as String?)?.trim();
    if (latest == null || latest.isEmpty) return;

    final info = await PackageInfo.fromPlatform();
    final installed = UpdateService.installedVersionLabel(info);
    if (!UpdateService.isNewerVersion(latest, installed)) return;

    if (_lastNotifiedVersion == latest) return;
    _lastNotifiedVersion = latest;

    final notes = (data['release_notes'] as String?)?.trim() ?? '';
    final body = notes.isNotEmpty
        ? notes
        : 'A new version is ready. Open vyomai.app to update.';

    await _notifications.notifyAppUpdate(
      version: latest,
      body: body,
      updateUrl: AppConfig.updateWebsiteUrl,
    );

    final ctx = _hostContext;
    if (ctx != null && ctx.mounted) {
      await UpdateService.checkForUpdates(ctx, force: true);
    }
  }

  /// Call when [HomeScreen] is mounted to show the in-app dialog.
  static Future<void> promptIfNeeded(BuildContext context) async {
    await UpdateService.checkForUpdates(context);
  }
}
