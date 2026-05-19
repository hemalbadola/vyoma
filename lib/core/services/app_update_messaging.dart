import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../notification_service.dart';
import '../update_service.dart';

/// Subscribes to FCM topic `vyoma_releases` for push when admins publish a version.
class AppUpdateMessaging {
  AppUpdateMessaging(this._notifications);

  final NotificationService _notifications;
  bool _started = false;

  Future<void> start() async {
    if (_started || kIsWeb) return;
    _started = true;

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      await messaging.subscribeToTopic('vyoma_releases');

      FirebaseMessaging.onMessage.listen((message) async {
        await _handle(message, foreground: true);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) async {
        await _handle(message, foreground: false);
        await UpdateService.openUpdateWebsite();
      });

      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        await _handle(initial, foreground: false);
      }
    } catch (e) {
      debugPrint('APP_UPDATE_MESSAGING: $e');
    }
  }

  Future<void> _handle(RemoteMessage message, {required bool foreground}) async {
    final data = message.data;
    if (data['type'] != 'app_update') return;

    final version = data['version'] as String? ?? '';
    final body = message.notification?.body ??
        data['body'] as String? ??
        'Update at vyomai.app';

    if (version.isNotEmpty) {
      await _notifications.notifyAppUpdate(
        version: version,
        body: body,
        updateUrl: AppConfig.updateWebsiteUrl,
      );
    } else if (foreground) {
      await _notifications.notifyNow(
        title: message.notification?.title ?? 'Vyoma update',
        body: body,
      );
    }
  }
}
