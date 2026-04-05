import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PendingNotification {
  final int id;
  final String title;
  final String body;
  final DateTime when;

  _PendingNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.when,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'when': when.toIso8601String(),
      };

  factory _PendingNotification.fromJson(Map<String, dynamic> json) {
    return _PendingNotification(
      id: json['id'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
      when: DateTime.parse(json['when'] as String),
    );
  }
}

class NotificationRecord {
  final String title;
  final String body;
  final DateTime sentAt;

  NotificationRecord({
    required this.title,
    required this.body,
    required this.sentAt,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
        'sentAt': sentAt.toIso8601String(),
      };

  factory NotificationRecord.fromJson(Map<String, dynamic> json) {
    return NotificationRecord(
      title: json['title'] as String,
      body: json['body'] as String,
      sentAt: DateTime.parse(json['sentAt'] as String),
    );
  }
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  int _idSeed = 2000;
  static const String _pendingKey = 'vyoma_pending_notifications';
  static const String _historyKey = 'vyoma_notification_history';

  Future<void> ensureInitialized() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(initSettings);

    final android =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    final ios =
        _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    final macos =
        _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
    await macos?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  Future<void> notifyNow({required String title, required String body}) async {
    await ensureInitialized();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'vyoma_ai_messages',
        'Vyoma AI Messages',
        channelDescription: 'AI-generated reminders and proactive nudges',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.show(_nextId(), title, body, details);
    await _appendHistory(
      NotificationRecord(title: title, body: body, sentAt: DateTime.now()),
    );
  }

  Future<List<NotificationRecord>> getHistory({int limit = 100}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_historyKey) ?? <String>[];
    final list = raw
        .map((e) => NotificationRecord.fromJson(
            Map<String, dynamic>.from(jsonDecode(e) as Map)))
        .toList();
    list.sort((a, b) => b.sentAt.compareTo(a.sentAt));
    if (list.length <= limit) return list;
    return list.sublist(0, limit);
  }

  Future<void> scheduleInApp(
      {required String title,
      required String body,
      required DateTime when,
      required VoidCallback onDispatch}) async {
    final pending = _PendingNotification(
      id: _nextId(),
      title: title,
      body: body,
      when: when,
    );

    await _savePending(pending);

    final delay = when.difference(DateTime.now());
    if (delay.isNegative || delay == Duration.zero) {
      await notifyNow(title: title, body: body);
      await _removePending(pending.id);
      onDispatch();
      return;
    }

    Future.delayed(delay, () async {
      await notifyNow(title: title, body: body);
      await _removePending(pending.id);
      onDispatch();
    });
  }

  Future<void> restorePending({void Function(String body)? onDispatch}) async {
    final items = await _loadPending();
    if (items.isEmpty) return;

    for (final item in items) {
      final delay = item.when.difference(DateTime.now());
      if (delay.isNegative || delay == Duration.zero) {
        await notifyNow(title: item.title, body: item.body);
        await _removePending(item.id);
        onDispatch?.call(item.body);
        continue;
      }

      Future.delayed(delay, () async {
        await notifyNow(title: item.title, body: item.body);
        await _removePending(item.id);
        onDispatch?.call(item.body);
      });
    }
  }

  Future<List<_PendingNotification>> _loadPending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_pendingKey) ?? <String>[];
    return raw
      .map((e) => _PendingNotification.fromJson(
        Map<String, dynamic>.from(jsonDecode(e) as Map)))
        .toList();
  }

  Future<void> _savePending(_PendingNotification pending) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await _loadPending();
    items.add(pending);
    final encoded = items.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_pendingKey, encoded);
  }

  Future<void> _removePending(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await _loadPending();
    items.removeWhere((e) => e.id == id);
    final encoded = items.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_pendingKey, encoded);
  }

  Future<void> _appendHistory(NotificationRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_historyKey) ?? <String>[];
    existing.add(jsonEncode(record.toJson()));
    if (existing.length > 300) {
      existing.removeRange(0, existing.length - 300);
    }
    await prefs.setStringList(_historyKey, existing);
  }

  int _nextId() {
    _idSeed += 1;
    return _idSeed;
  }
}