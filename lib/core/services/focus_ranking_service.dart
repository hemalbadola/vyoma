import 'dart:async';

import '../models/focus_rank_entry.dart';
import 'daily_stats_store.dart';
import '../friend_service.dart';
import '../user_service.dart';

abstract class FocusRankingService {
  Stream<List<FocusRankEntry>> watchWeeklyRanking();
  Future<int> getSquadAverageFocusMinutesThisWeek();
}

class PreviewFocusRankingService implements FocusRankingService {
  PreviewFocusRankingService({
    this.friendService,
    this.userService,
    required this.dailyStatsStore,
    Stream<List<String>>? friendIdsStream,
    String Function()? currentUserIdGetter,
    String Function()? currentDisplayNameGetter,
    Future<int> Function()? myMinutesLoader,
  }) : _friendIdsStream = friendIdsStream,
       _currentUserIdGetter = currentUserIdGetter,
       _currentDisplayNameGetter = currentDisplayNameGetter,
       _myMinutesLoader = myMinutesLoader;

  final FriendService? friendService;
  final UserService? userService;
  final Stream<List<String>>? _friendIdsStream;
  final String Function()? _currentUserIdGetter;
  final String Function()? _currentDisplayNameGetter;
  final Future<int> Function()? _myMinutesLoader;
  final DailyStatsStore dailyStatsStore;

  Future<int> _myWeeklyMinutes() async {
    if (_myMinutesLoader != null) return _myMinutesLoader();
    final now = DateTime.now();
    var sum = 0;
    for (var i = 0; i < 7; i++) {
      final stats = await dailyStatsStore.loadForDate(
        now.subtract(Duration(days: i)),
      );
      sum += stats.focusMinutes;
    }
    return sum;
  }

  int _previewMinutesForUid(String uid) {
    var hash = 0;
    for (final code in uid.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return 60 + (hash % 181);
  }

  @override
  Stream<List<FocusRankEntry>> watchWeeklyRanking() {
    final source =
        _friendIdsStream ??
        friendService?.getAcceptedFriendUidsStream() ??
        Stream<List<String>>.value(const <String>[]);
    return source.asyncMap((friendUids) async {
      final self = userService?.currentProfile;
      final selfId = _currentUserIdGetter?.call() ?? self?.uid ?? 'me';
      final selfName =
          _currentDisplayNameGetter?.call() ??
          ((self?.displayName.isNotEmpty ?? false)
              ? self!.displayName
              : (self?.username ?? 'You'));
      final myMinutes = await _myWeeklyMinutes();

      final entries = <FocusRankEntry>[
        FocusRankEntry(
          userId: selfId,
          displayName: selfName,
          focusMinutesThisWeek: myMinutes,
        ),
      ];

      for (var i = 0; i < friendUids.length; i++) {
        final uid = friendUids[i];
        entries.add(
          FocusRankEntry(
            userId: uid,
            displayName: 'Friend ${i + 1}',
            focusMinutesThisWeek: _previewMinutesForUid(uid),
            isPreview: true,
          ),
        );
      }

      entries.sort(
        (a, b) => b.focusMinutesThisWeek.compareTo(a.focusMinutesThisWeek),
      );
      return entries;
    });
  }

  @override
  Future<int> getSquadAverageFocusMinutesThisWeek() async {
    final entries = await watchWeeklyRanking().first;
    final selfId =
        _currentUserIdGetter?.call() ?? userService?.currentProfile?.uid;
    final squad = entries.where((e) => e.userId != selfId).toList();
    if (squad.isEmpty) return 0;
    final total = squad.fold<int>(0, (sum, e) => sum + e.focusMinutesThisWeek);
    return (total / squad.length).round();
  }
}
