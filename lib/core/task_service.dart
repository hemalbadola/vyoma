import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'accountability_service.dart';
import 'cofocus_service.dart';
import 'models/task.dart';

/// Tasks + daily retro metrics.
///
/// **Signed in:** `users/{uid}/tasks/{taskId}` and `users/{uid}/daily_metrics/{yyyy-MM-dd}`
/// are the source of truth (Firestore offline cache applies). Per-uid SharedPreferences
/// mirror reduces flicker and supports faster cold start.
///
/// **Signed out:** Guest-only keys (`*_guest`) — no cloud sync.
class TaskService extends ChangeNotifier {
  static const String _kLegacyTasksKey = 'vyoma_tasks';
  static const String _kLegacyDailyKey = 'vyoma_daily_metrics';
  /// Persisted for [TaskPrefsReader] in Workmanager isolates (no FirebaseAuth there).
  static const String kLastKnownUidKey = 'vyoma_last_known_uid';

  final AccountabilityService? _accountability;
  final CoFocusService? _coFocusService;
  final dynamic _userService;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<VyomaTask> _tasks = [];
  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _tasksSub;
  String? _firestoreUid;
  int _bindGeneration = 0;

  /// Ignores one empty snapshot after uploading local tasks so we don't wipe `_tasks`
  /// before the server snapshot catches up.
  bool _ignoreNextEmptyRemoteSnapshot = false;

  List<VyomaTask> get tasks => List.unmodifiable(_tasks);
  List<VyomaTask> get activeTasks => _tasks.where((t) => !t.completed).toList();
  List<VyomaTask> get completedTasks => _tasks.where((t) => t.completed).toList();
  List<VyomaTask> get overdueTasks => _tasks.where((t) => t.isOverdue).toList();
  List<VyomaTask> get dueTodayTasks =>
      _tasks.where((t) => !t.completed && t.isDueToday).toList();

  TaskService({
    AccountabilityService? accountability,
    CoFocusService? coFocusService,
    dynamic userService,
  })  : _accountability = accountability,
        _coFocusService = coFocusService,
        _userService = userService {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      unawaited(_bindFirestore(FirebaseAuth.instance.currentUser?.uid));
    });
    unawaited(_bindFirestore(FirebaseAuth.instance.currentUser?.uid));
  }

  static String _tasksPrefsKey(String? uid) =>
      uid == null ? 'vyoma_tasks_guest' : 'vyoma_tasks_$uid';

  static String _dailyPrefsKey(String? uid) =>
      uid == null ? 'vyoma_daily_metrics_guest' : 'vyoma_daily_metrics_$uid';

  CollectionReference<Map<String, dynamic>>? _tasksCollection(String? uid) {
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('tasks');
  }

  Future<void> _bindFirestore(String? uid) async {
    final gen = ++_bindGeneration;
    await _tasksSub?.cancel();
    _tasksSub = null;

    _firestoreUid = uid;

    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyPrefsIfNeeded(prefs, uid);
    await _persistLastKnownUid(prefs, boundSessionUid: uid);
    if (gen != _bindGeneration) return;

    await _loadTasksFromPrefs(uid);
    if (gen != _bindGeneration) return;

    notifyListeners();

    if (uid == null) {
      return;
    }

    final col = _tasksCollection(uid)!;
    _tasksSub = col.snapshots().listen(
      (snap) => unawaited(_onTasksSnapshot(snap, uid, gen)),
      onError: (Object e, StackTrace st) {
        debugPrint('TASKS_DEBUG: Firestore tasks listener error: $e\n$st');
      },
    );
  }

  Future<void> _migrateLegacyPrefsIfNeeded(
    SharedPreferences prefs,
    String? uid,
  ) async {
    if (uid != null) {
      final tasksKeyed = _tasksPrefsKey(uid);
      if (prefs.getString(tasksKeyed) == null) {
        final legacy = prefs.getString(_kLegacyTasksKey);
        if (legacy != null) {
          await prefs.setString(tasksKeyed, legacy);
          await prefs.remove(_kLegacyTasksKey);
        }
      }

      final dailyKeyed = _dailyPrefsKey(uid);
      if (prefs.getString(dailyKeyed) == null) {
        final legacyDaily = prefs.getString(_kLegacyDailyKey);
        if (legacyDaily != null) {
          await prefs.setString(dailyKeyed, legacyDaily);
          await prefs.remove(_kLegacyDailyKey);
        }
      }
    } else {
      if (prefs.getString(_tasksPrefsKey(null)) == null) {
        final legacy = prefs.getString(_kLegacyTasksKey);
        if (legacy != null) {
          await prefs.setString(_tasksPrefsKey(null), legacy);
          await prefs.remove(_kLegacyTasksKey);
        }
      }
      if (prefs.getString(_dailyPrefsKey(null)) == null) {
        final legacyDaily = prefs.getString(_kLegacyDailyKey);
        if (legacyDaily != null) {
          await prefs.setString(_dailyPrefsKey(null), legacyDaily);
          await prefs.remove(_kLegacyDailyKey);
        }
      }
    }
  }

  Future<void> _loadTasksFromPrefs(String? uid) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_tasksPrefsKey(uid));
    if (data == null) {
      _tasks = [];
      return;
    }
    try {
      final List<dynamic> jsonList = jsonDecode(data) as List<dynamic>;
      _tasks = jsonList
          .map((e) => VyomaTask.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('TASKS_DEBUG: Failed to load tasks from prefs: $e');
      _tasks = [];
    }
  }

  Future<void> _onTasksSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
    String uid,
    int gen,
  ) async {
    if (gen != _bindGeneration || uid != _firestoreUid) return;

    if (snap.docs.isEmpty &&
        _tasks.isNotEmpty &&
        _ignoreNextEmptyRemoteSnapshot) {
      _ignoreNextEmptyRemoteSnapshot = false;
      return;
    }

    if (snap.docs.isEmpty && _tasks.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final seeded = prefs.getBool('vyoma_cloud_tasks_seeded_$uid') ?? false;
      if (!seeded) {
        final uploaded = await _flushAllTasksToFirestore(uid);
        if (uploaded) {
          await prefs.setBool('vyoma_cloud_tasks_seeded_$uid', true);
          _ignoreNextEmptyRemoteSnapshot = true;
        }
        return;
      }
    }

    if (gen != _bindGeneration) return;

    final remote = snap.docs
        .map(
          (d) =>
              VyomaTask.fromJson(Map<String, dynamic>.from(d.data())),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    _tasks = remote;
    await _persistPrefsOnly();
    notifyListeners();
    _mirrorProfileTitlesBestEffort();
  }

  Future<bool> _flushAllTasksToFirestore(String uid) async {
    final col = _tasksCollection(uid)!;
    final batch = _firestore.batch();
    var n = 0;
    for (final t in _tasks) {
      batch.set(col.doc(t.id), _taskPayload(t));
      n++;
      if (n >= 400) {
        debugPrint(
          'TASKS_DEBUG: Task batch capped at 400 — remaining tasks not seeded',
        );
        break;
      }
    }
    try {
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('TASKS_DEBUG: Batch seed tasks failed: $e');
      return false;
    }
  }

  Map<String, dynamic> _taskPayload(VyomaTask t) => Map<String, dynamic>.from(
        t.toJson(),
      );

  Future<void> _persistPrefsOnly() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _tasksPrefsKey(_firestoreUid),
      jsonEncode(_tasks.map((t) => t.toJson()).toList()),
    );
    await _persistLastKnownUid(prefs);
  }

  Future<void> _persistLastKnownUid(
    SharedPreferences prefs, {
    String? boundSessionUid,
  }) async {
    final uid =
        boundSessionUid ??
        FirebaseAuth.instance.currentUser?.uid ??
        _firestoreUid;
    await prefs.setString(kLastKnownUidKey, uid ?? '');
  }

  Future<void> _persistCloudAndPrefs(VyomaTask? touched) async {
    await _persistPrefsOnly();

    final uid = _firestoreUid;
    if (uid != null && touched != null) {
      try {
        await _tasksCollection(uid)!.doc(touched.id).set(_taskPayload(touched));
      } catch (e) {
        debugPrint('TASKS_DEBUG: Firestore task write failed: $e');
      }
    }

    notifyListeners();
    _mirrorProfileTitlesBestEffort();
  }

  Future<void> _deleteTaskCloud(String taskId) async {
    final uid = _firestoreUid;
    if (uid == null) return;
    try {
      await _tasksCollection(uid)!.doc(taskId).delete();
    } catch (e) {
      debugPrint('TASKS_DEBUG: Firestore task delete failed: $e');
    }
  }

  void _mirrorProfileTitlesBestEffort() {
    if (_userService == null) return;
    try {
      final profile = _userService.profile;
      if (profile == null) return;
      if (profile.shareTasksWithFriends) {
        final toSync = activeTasks.take(3).map((t) => t.title).toList();
        _userService.syncActiveTasks(toSync).catchError((Object e) {
          debugPrint('TASKS_DEBUG: syncActiveTasks failed: $e');
        });
      } else {
        _userService.syncActiveTasks([]).catchError((Object e) {
          debugPrint('TASKS_DEBUG: clear shared tasks failed: $e');
        });
      }
    } catch (e) {
      debugPrint('TASKS_DEBUG: mirror profile tasks skipped: $e');
    }
  }

  // --- CRUD ---

  Future<VyomaTask> addTask({
    required String title,
    String? description,
    String? project,
    DateTime? deadline,
    String priority = 'normal',
  }) async {
    final task = VyomaTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      project: project,
      createdAt: DateTime.now(),
      deadline: deadline,
      priority: priority,
    );
    _tasks = [..._tasks, task];
    await _persistCloudAndPrefs(task);
    return task;
  }

  Future<void> completeTask(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    _tasks[index] = _tasks[index].copyWith(
      completed: true,
      completedAt: DateTime.now(),
    );
    final t = _tasks[index];
    await _persistCloudAndPrefs(t);
    _accountability?.onTaskCompleted(t.title);
  }

  Future<void> uncompleteTask(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    _tasks[index] = _tasks[index].copyWith(completed: false);
    await _persistCloudAndPrefs(_tasks[index]);
  }

  Future<void> deleteTask(String taskId) async {
    _tasks = _tasks.where((t) => t.id != taskId).toList();
    await _deleteTaskCloud(taskId);
    await _persistPrefsOnly();
    notifyListeners();
    _mirrorProfileTitlesBestEffort();
  }

  Future<void> addFocusTime(String taskId, int minutes) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    _tasks[index] = _tasks[index].copyWith(
      focusMinutes: _tasks[index].focusMinutes + minutes,
    );
    final t = _tasks[index];
    await _persistCloudAndPrefs(t);

    _accountability?.onFocusSessionEnded(t.title, minutes);
    _coFocusService?.logFocusProgress(minutes);
  }

  List<VyomaTask> searchTasks(String query) {
    final lower = query.toLowerCase();
    return _tasks.where((t) {
      return t.title.toLowerCase().contains(lower) ||
          (t.description?.toLowerCase().contains(lower) ?? false) ||
          (t.project?.toLowerCase().contains(lower) ?? false);
    }).toList();
  }

  List<VyomaTask> getCarryoverTasks() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _tasks.where((t) {
      if (t.completed) return false;
      return t.createdAt.isBefore(today);
    }).toList();
  }

  Map<String, List<VyomaTask>> getTasksByProject() {
    final grouped = <String, List<VyomaTask>>{};
    for (final task in activeTasks) {
      final project = task.project ?? 'Uncategorized';
      grouped.putIfAbsent(project, () => []).add(task);
    }
    return grouped;
  }

  // --- Daily Metrics ---

  Future<void> saveDailySnapshot({
    required int focusMinutes,
    required int distractionCount,
    required int tasksCompleted,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final key = _dailyPrefsKey(_firestoreUid);
    final existing = prefs.getString(key);
    final Map<String, dynamic> allMetrics =
        existing != null ? jsonDecode(existing) as Map<String, dynamic> : {};

    final entry = <String, dynamic>{
      'focusMinutes': focusMinutes,
      'distractionCount': distractionCount,
      'tasksCompleted': tasksCompleted,
      'activeTasks': activeTasks.length,
      'overdueTasks': overdueTasks.length,
    };
    allMetrics[today] = entry;

    if (allMetrics.length > 90) {
      final sorted = allMetrics.keys.toList()..sort();
      for (final k in sorted.take(allMetrics.length - 90)) {
        allMetrics.remove(k);
      }
    }

    await prefs.setString(key, jsonEncode(allMetrics));

    final uid = _firestoreUid;
    if (uid != null) {
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('daily_metrics')
            .doc(today)
            .set(
              {
                ...entry,
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
      } catch (e) {
        debugPrint('TASKS_DEBUG: Firestore daily_metrics write failed: $e');
      }
    }

    notifyListeners();
  }

  Future<Map<String, Map<String, dynamic>>> getDailyMetrics({
    int days = 14,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _dailyPrefsKey(_firestoreUid);
    final raw = prefs.getString(key);

    final Map<String, Map<String, dynamic>> merged = {};
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in decoded.entries) {
          merged[e.key] = Map<String, dynamic>.from(e.value as Map);
        }
      } catch (e) {
        debugPrint('TASKS_DEBUG: daily metrics prefs corrupt: $e');
      }
    }

    final cutoff = DateTime.now().subtract(Duration(days: days));
    final cutoffStr = cutoff.toIso8601String().substring(0, 10);

    final uid = _firestoreUid;
    if (uid != null) {
      try {
        final qs = await _firestore
            .collection('users')
            .doc(uid)
            .collection('daily_metrics')
            .where(FieldPath.documentId, isGreaterThanOrEqualTo: cutoffStr)
            .get();
        for (final doc in qs.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          data.remove('updatedAt');
          merged[doc.id] = data;
        }
      } catch (e) {
        debugPrint('TASKS_DEBUG: Firestore daily_metrics read failed: $e');
      }
    }

    final result = <String, Map<String, dynamic>>{};
    for (final entry in merged.entries) {
      if (entry.key.compareTo(cutoffStr) >= 0) {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  @override
  void dispose() {
    _tasksSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}
