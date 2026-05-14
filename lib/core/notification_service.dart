import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'temporal_context_builder.dart';

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
  final String id;
  final String title;
  final String body;
  final DateTime sentAt;
  final bool isRead;
  final bool isDismissed;
  final DateTime? readAt;

  NotificationRecord({
    required this.id,
    required this.title,
    required this.body,
    required this.sentAt,
    this.isRead = false,
    this.isDismissed = false,
    this.readAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'sentAt': sentAt.toIso8601String(),
        'isRead': isRead,
        'isDismissed': isDismissed,
        'readAt': readAt?.toIso8601String(),
      };

  factory NotificationRecord.fromJson(Map<String, dynamic> json) {
    final sentAtRaw = (json['sentAt'] ?? '').toString();
    final sentAt = DateTime.tryParse(sentAtRaw) ?? DateTime.now();
    final fallbackId =
        '${sentAt.millisecondsSinceEpoch}_${(json['title'] ?? '').toString().hashCode}';
    return NotificationRecord(
      id: (json['id'] as String?)?.trim().isNotEmpty == true
          ? json['id'] as String
          : fallbackId,
      title: json['title'] as String,
      body: json['body'] as String,
      sentAt: sentAt,
      isRead: json['isRead'] as bool? ?? false,
      isDismissed: json['isDismissed'] as bool? ?? false,
      readAt: (json['readAt'] as String?) != null
          ? DateTime.tryParse(json['readAt'] as String)
          : null,
    );
  }

  NotificationRecord copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? sentAt,
    bool? isRead,
    bool? isDismissed,
    DateTime? readAt,
  }) {
    return NotificationRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      sentAt: sentAt ?? this.sentAt,
      isRead: isRead ?? this.isRead,
      isDismissed: isDismissed ?? this.isDismissed,
      readAt: readAt ?? this.readAt,
    );
  }
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  int _idSeed = 2000;
  static const int _ambientNotificationId = 91001;
  static const String _pendingKey = 'vyoma_pending_notifications';
  static const String _historyKey = 'vyoma_notification_history';
  final StreamController<int> _unreadCountController = StreamController<int>.broadcast();
  Stream<int> get unreadCount => _unreadCountController.stream;

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
      NotificationRecord(
        id: _nextRecordId(),
        title: title,
        body: body,
        sentAt: DateTime.now(),
      ),
    );
  }

  /// Persistent low-priority shade / lock-screen line (updated by app + background ticks).
  Future<void> showAmbientOngoing(String body) async {
    await ensureInitialized();
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'vyoma_ambient',
        'Vyoma rhythm',
        channelDescription: 'Focus minutes and next calendar anchor',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        onlyAlertOnce: true,
        showWhen: false,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      ),
    );

    await _plugin.show(
      _ambientNotificationId,
      'Vyoma',
      trimmed,
      details,
    );
  }

  /// Rebuild ambient line from prefs (zero network) and update ongoing notification.
  Future<void> refreshAmbientFromPrefs() async {
    final line = await VyomaAmbientPrefs.buildAmbientLine();
    if (line.trim().isEmpty) return;
    await showAmbientOngoing(line);
  }

  Future<List<NotificationRecord>> getHistory({int limit = 100}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_historyKey) ?? <String>[];
    final list = raw
        .map((e) => NotificationRecord.fromJson(
            Map<String, dynamic>.from(jsonDecode(e) as Map)))
        .where((e) => !e.isDismissed)
        .toList();
    list.sort((a, b) => b.sentAt.compareTo(a.sentAt));
    if (list.length <= limit) return list;
    return list.sublist(0, limit);
  }

  Future<void> markRead(String id) async {
    final all = await _loadAllHistory();
    final updated = all.map((entry) {
      if (entry.id != id || entry.isRead) return entry;
      return entry.copyWith(isRead: true, readAt: DateTime.now());
    }).toList();
    await _saveAllHistory(updated);
  }

  Future<void> markAllRead() async {
    final all = await _loadAllHistory();
    final now = DateTime.now();
    final updated = all.map((entry) {
      if (entry.isRead || entry.isDismissed) return entry;
      return entry.copyWith(isRead: true, readAt: now);
    }).toList();
    await _saveAllHistory(updated);
  }

  Future<void> dismiss(String id) async {
    final all = await _loadAllHistory();
    final updated = all.map((entry) {
      if (entry.id != id) return entry;
      return entry.copyWith(isDismissed: true);
    }).toList();
    await _saveAllHistory(updated);
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
    final existing = await _loadAllHistory();
    existing.add(record);
    await _saveAllHistory(existing);
  }

  Future<List<NotificationRecord>> _loadAllHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_historyKey) ?? <String>[];
    return raw
        .map((e) => NotificationRecord.fromJson(
            Map<String, dynamic>.from(jsonDecode(e) as Map)))
        .toList();
  }

  Future<void> _saveAllHistory(List<NotificationRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = records.toList()
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
    if (normalized.length > 300) {
      normalized.removeRange(0, normalized.length - 300);
    }
    final encoded = normalized.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_historyKey, encoded);
    await _emitUnreadCount(normalized);
  }

  Future<void> _emitUnreadCount([List<NotificationRecord>? cached]) async {
    final records = cached ?? await _loadAllHistory();
    final count = records.where((r) => !r.isDismissed && !r.isRead).length;
    if (!_unreadCountController.isClosed) {
      _unreadCountController.add(count);
    }
  }

  String _nextRecordId() {
    final millis = DateTime.now().millisecondsSinceEpoch;
    return 'n_${millis}_${_nextId()}';
  }

  int _nextId() {
    _idSeed += 1;
    return _idSeed;
  }

  void dispose() {
    _unreadCountController.close();
  }
}