import 'package:flutter/material.dart';
import '../theme/vyoma_colors.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/memory_service.dart';
import '../../core/task_service.dart';
import '../../core/timetable_service.dart';
import '../../core/models/timetable.dart';
import '../../core/logic/next_up_engine.dart';
import '../../core/models/daily_stats.dart';
import '../../core/services/daily_stats_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/vy_card.dart';
import '../../core/friend_service.dart';
import '../../ui/war_room_viewmodel.dart';
import '../../ui/widgets/debrief_card.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import '../../ui/widgets/chat_sheet.dart';
import '../../ui/screens/memory_vault_screen.dart';
import '../../ui/widgets/vault_journal_view.dart';
import '../../ui/screens/friends_hub_screen.dart';
import '../../ui/screens/timetable_screen.dart';
import '../../tutorial/tutorial_keys.dart';
import '../../core/app_trace.dart';
import '../../features/dharma_map/presentation/widgets/current_chapter_strip.dart';
import '../../features/identity/presentation/widgets/identity_anchor_strip.dart';
import '../../features/today/presentation/widgets/memory_braid_card.dart';
import '../../features/today/presentation/widgets/one_thing_hero.dart';
import '../../features/today/presentation/widgets/smart_suggestions_list.dart';

class MissionTab extends StatelessWidget {
  const MissionTab({super.key});
  static const NextUpEngine _nextUpEngine = NextUpEngine();

  // --- Contextual Suggestions ---
  List<_Suggestion> _getContextualSuggestions(
    WarRoomViewModel vm,
    MemoryService memory,
  ) {
    final hour = DateTime.now().hour;
    final hasFocus = vm.isFocusSessionActive;
    final focusHours = vm.currentMetrics.focusMinutes / 60;
    final facts = memory.getFacts();
    final hasGoal =
        (memory.getSegment('protocol') as Map?)?.containsKey('goal') ?? false;

    final suggestions = <_Suggestion>[];

    // Context-aware suggestions based on time and state
    if (hasFocus) {
      if (vm.currentMetrics.focusMinutes > 45) {
        suggestions.add(
          _Suggestion(
            icon: Icons.self_improvement_rounded,
            title: 'Take a break',
            subtitle:
                'You\'ve been focused for ${(vm.currentMetrics.focusMinutes).toInt()}min. Move, hydrate.',
            action: '/focus stop',
            color: VyomaColors.warning,
          ),
        );
      }
    } else if (hour >= 6 && hour < 12 && focusHours < 0.5) {
      suggestions.add(
        _Suggestion(
          icon: Icons.center_focus_strong_rounded,
          title: 'Start deep work',
          subtitle: 'Morning focus window is open. What are you working on?',
          action: 'start_focus',
          color: VyomaColors.accent,
        ),
      );
    }

    if (hour >= 18 && hour < 23) {
      suggestions.add(
        _Suggestion(
          icon: Icons.edit_note_rounded,
          title: 'Journal today',
          subtitle: 'Capture wins, blockers, and tomorrow\'s plan.',
          action: 'journal',
          color: VyomaColors.info,
        ),
      );
    }

    if (hour >= 7 && hour < 10 && !hasGoal) {
      suggestions.add(
        _Suggestion(
          icon: Icons.flag_rounded,
          title: 'Set your goal',
          subtitle: 'What\'s the #1 thing to accomplish today?',
          action: 'set_goal',
          color: VyomaColors.warning,
        ),
      );
    }

    if (facts.isEmpty) {
      suggestions.add(
        _Suggestion(
          icon: Icons.psychology_rounded,
          title: 'Teach me about you',
          subtitle: 'Tell Vyoma about your exams, routines, or preferences.',
          action: 'chat',
          color: VyomaColors.accentBright,
        ),
      );
    }

    // Always show a chat option if we have room
    if (suggestions.length < 3) {
      suggestions.add(
        _Suggestion(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Chat with Vyoma',
          subtitle: 'Plan, brainstorm, or just think out loud.',
          action: 'chat',
          color: VyomaColors.accent,
        ),
      );
    }

    return suggestions.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    traceDebug('UI_DEBUG: MissionTab build() entered');
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 160),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Consumer2<WarRoomViewModel, MemoryService>(
                builder: (context, vm, memory, _) {
                  traceDebug(
                    'UI_DEBUG: MissionTab consumer build | focusMin=${vm.currentMetrics.focusMinutes} tasksDone=${vm.currentMetrics.tasksCompleted} facts=${memory.getFacts().length}',
                  );
                  final suggestions = _getContextualSuggestions(vm, memory);
                  final taskService = Provider.of<TaskService>(context);
                  final timetableService = Provider.of<TimetableService>(
                    context,
                  );
                  final dailyStatsStore = context.read<DailyStatsStore>();
                  final today = DateTime.now();

                  return StreamBuilder<DailyStats>(
                    stream: dailyStatsStore.watchForDate(today),
                    builder: (context, snapshot) {
                      final statsRaw =
                          snapshot.data ??
                          DailyStats(
                            id: '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
                          );
                      final stats = statsRaw.copyWith(
                        focusMinutes: vm.currentMetrics.focusMinutes,
                        tasksCompleted: vm.currentMetrics.tasksCompleted,
                      );
                      final isEvening = today.hour >= 20;
                      final shouldShowReflection =
                          isEvening && !stats.journaled;
                      final classesToday = NextUpEngine.classSlotsForToday(
                        now: today,
                        timetableSlots: timetableService.slots,
                      );
                      final tasks = NextUpEngine.tasksFromVyomaTasks(
                        taskService.activeTasks,
                      );
                      final nextUpSuggestion = _nextUpEngine.compute(
                        now: today,
                        todayStats: stats,
                        classesToday: classesToday,
                        tasks: tasks,
                      );

                      // The wedge: the screen IS the question when unset.
                      // Secondary content earns its place by supporting the one-thing.
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const IdentityAnchorStrip(),
                          const CurrentChapterStrip(),
                          _buildAmbientHeader(context, vm),
                          OneThingHero(
                            stats: stats,
                            onChange: (value) => _saveTodayStats(
                              context,
                              stats.copyWith(
                                oneThing: value.isEmpty ? null : value,
                                clearOneThing: value.isEmpty,
                                focusMinutes: vm.currentMetrics.focusMinutes,
                                tasksCompleted:
                                    vm.currentMetrics.tasksCompleted,
                              ),
                            ),
                          ),
                          MemoryBraidCard(
                            stats: stats,
                            onOpenEntry: (entry) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const VaultJournalView(
                                    embedded: false,
                                    oneLineMode: false,
                                  ),
                                ),
                              );
                            },
                          ),
                          // Below-the-fold content is supporting context only.
                          _buildNextClass(context, timetableService),
                          _buildNextUp(
                            context,
                            suggestion: nextUpSuggestion,
                            hasTasks: tasks.isNotEmpty,
                          ),
                          if (shouldShowReflection) _buildEndOfDayCard(context),
                          _buildSuggestions(
                            context,
                            suggestions,
                            vm,
                            stats: stats,
                            tasksCount: tasks.length,
                            classesCountThisWeek: timetableService.slots.length,
                          ),
                          _buildDebriefSection(context),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Ambient header: just the date in muted Cormorant. The focus-hours badge
  // moved to Progress where retrospective metrics belong. Today is for intent,
  // not score.
  Widget _buildAmbientHeader(BuildContext context, WarRoomViewModel vm) {
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
      child: Text(
        DateFormat('EEEE, MMMM d').format(now).toLowerCase(),
        style: TextStyle(
          fontFamily: 'CormorantGaramond',
          color: VyomaColors.textMuted,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.5,
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  // --- Next Class from Timetable ---
  Widget _buildNextClass(
    BuildContext context,
    TimetableService timetableService,
  ) {
    final slots = timetableService.slots;
    if (slots.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    final todaySlots = slots.where((s) {
      final weekday = _dayNameToWeekday(s.dayOfWeek);
      return weekday == now.weekday;
    }).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (todaySlots.isEmpty) return const SizedBox.shrink();

    // Find next upcoming slot
    TimetableSlot? nextSlot;
    for (final slot in todaySlots) {
      final parts = slot.startTime.split(':');
      final slotTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      if (slotTime.isAfter(now)) {
        nextSlot = slot;
        break;
      }
    }

    if (nextSlot == null) return const SizedBox.shrink();

    final startParts = nextSlot.startTime.split(':');
    final startTime = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(startParts[0]),
      int.parse(startParts[1]),
    );
    final minsUntil = startTime.difference(now).inMinutes;
    final countdown = minsUntil < 60
        ? '${minsUntil}min'
        : '${(minsUntil / 60).toStringAsFixed(0)}h ${minsUntil % 60}m';

    final isImminent = minsUntil <= 15;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isImminent
              ? VyomaColors.warning.withValues(alpha: 0.06)
              : VyomaColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isImminent
                ? VyomaColors.warning.withValues(alpha: 0.25)
                : VyomaColors.borderSubtle,
            width: isImminent ? 1 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isImminent
                    ? VyomaColors.warning.withValues(alpha: 0.12)
                    : VyomaColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isImminent
                    ? Icons.directions_run_rounded
                    : Icons.school_rounded,
                color: isImminent
                    ? VyomaColors.warning
                    : VyomaColors.accentMuted,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nextSlot.subject,
                    style: TextStyle(
                      color: VyomaColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${nextSlot.venue} · ${nextSlot.startTime}–${nextSlot.endTime}',
                    style: TextStyle(
                      color: VyomaColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isImminent
                    ? VyomaColors.warning.withValues(alpha: 0.15)
                    : VyomaColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'in $countdown',
                style: TextStyle(fontFeatures: const [FontFeature.tabularFigures()],
                  color: isImminent
                      ? VyomaColors.warningLight
                      : VyomaColors.accentBright,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 150.ms).slideX(begin: 0.03);
  }

  // --- Task Briefing (Carryover + Due Today) ---
  // ignore: unused_element
  Widget _buildTaskBriefing(BuildContext context, TaskService taskService) {
    final overdue = taskService.overdueTasks;
    final dueToday = taskService.dueTodayTasks;
    final carryover = taskService
        .getCarryoverTasks()
        .where((t) => !t.isOverdue && !t.isDueToday) // Don't double-count
        .take(3)
        .toList();

    if (overdue.isEmpty && dueToday.isEmpty && carryover.isEmpty) {
      return const SizedBox.shrink();
    }

    final allItems = [...overdue, ...dueToday, ...carryover];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'TASKS',
                style: TextStyle(
                  color: VyomaColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 8),
              if (overdue.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: VyomaColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${overdue.length} overdue',
                    style: TextStyle(
                      color: VyomaColors.error,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...allItems.take(5).toList().asMap().entries.map((entry) {
            final task = entry.value;
            final isOverdue = task.isOverdue;
            final isDue = task.isDueToday;
            final daysLeft = task.daysUntilDeadline;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  taskService.completeTask(task.id);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isOverdue
                        ? VyomaColors.error.withValues(alpha: 0.04)
                        : VyomaColors.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isOverdue
                          ? VyomaColors.error.withValues(alpha: 0.2)
                          : isDue
                          ? VyomaColors.warning.withValues(alpha: 0.15)
                          : VyomaColors.borderSubtle,
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: task.priority == 'high'
                              ? VyomaColors.error
                              : task.priority == 'low'
                              ? VyomaColors.textMuted
                              : VyomaColors.accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: TextStyle(
                                color: VyomaColors.textPrimary.withValues(
                                  alpha: 0.9,
                                ),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (task.project != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                task.project!,
                                style: TextStyle(
                                  color: VyomaColors.textMuted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (daysLeft != null)
                        Text(
                          isOverdue
                              ? '${(-daysLeft)}d late'
                              : isDue
                              ? 'today'
                              : '${daysLeft}d',
                          style: TextStyle(fontFeatures: const [FontFeature.tabularFigures()],
                            color: isOverdue
                                ? VyomaColors.error
                                : isDue
                                ? VyomaColors.warning
                                : VyomaColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ).animate(delay: (60 * entry.key).ms).fadeIn().slideX(begin: 0.03);
          }),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  int _dayNameToWeekday(String dayName) {
    switch (dayName.toLowerCase()) {
      case 'monday':
        return DateTime.monday;
      case 'tuesday':
        return DateTime.tuesday;
      case 'wednesday':
        return DateTime.wednesday;
      case 'thursday':
        return DateTime.thursday;
      case 'friday':
        return DateTime.friday;
      case 'saturday':
        return DateTime.saturday;
      case 'sunday':
        return DateTime.sunday;
      default:
        return -1;
    }
  }

  Widget _buildNextUp(
    BuildContext context, {
    required NextUpSuggestion? suggestion,
    required bool hasTasks,
  }) {
    IconData iconForKind(NextUpKind kind) {
      switch (kind) {
        case NextUpKind.focusBlock:
          return Icons.bolt_rounded;
        case NextUpKind.classSession:
          return Icons.calendar_today_outlined;
        case NextUpKind.task:
          return Icons.checklist_rounded;
        case NextUpKind.reflection:
          return Icons.edit_outlined;
        case NextUpKind.rest:
          return Icons.coffee_outlined;
      }
    }

    void onSuggestionTap() {
      if (suggestion == null) return;
      switch (suggestion.kind) {
        case NextUpKind.classSession:
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const TimetableScreen()));
          break;
        case NextUpKind.focusBlock:
        case NextUpKind.task:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Focus timer coming in next update.')),
          );
          break;
        case NextUpKind.reflection:
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  const VaultJournalView(embedded: false, oneLineMode: true),
            ),
          );
          break;
        case NextUpKind.rest:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Good call. Short breaks improve focus.'),
            ),
          );
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'NEXT UP',
                style: TextStyle(
                  color: VyomaColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                DateFormat('EEE, MMM d').format(DateTime.now()).toUpperCase(),
                style: TextStyle(
                  color: VyomaColors.textMuted,
                  fontSize: 10,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (suggestion == null)
            _buildEmptySchedule()
          else
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: VyomaTutorialKeys.calendarGrid,
                onTap: onSuggestionTap,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: VyomaColors.bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: VyomaColors.borderSubtle,
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: VyomaColors.accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          iconForKind(suggestion.kind),
                          color: VyomaColors.accentMuted,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              suggestion.title,
                              style: TextStyle(
                                color: VyomaColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              suggestion.subtitle,
                              style: TextStyle(
                                color: VyomaColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (suggestion?.kind == NextUpKind.classSession && !hasTasks) ...[
            const SizedBox(height: 10),
            _buildEmptySchedule(),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildEmptySchedule() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: VyomaColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VyomaColors.borderSubtle, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: VyomaColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.calendar_today_rounded,
              color: VyomaColors.accentMuted,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No events coming up',
                  style: TextStyle(
                    color: VyomaColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Chat with Vyoma to plan your day',
                  style: TextStyle(
                    color: VyomaColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions(
    BuildContext context,
    List<_Suggestion> suggestions,
    WarRoomViewModel vm, {
    required DailyStats stats,
    required int tasksCount,
    required int classesCountThisWeek,
  }) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SUGGESTED',
            style: TextStyle(
              color: VyomaColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          FutureBuilder<int>(
            future: context.read<DailyStatsStore>().computeJournalStreakUpTo(
              DateTime.now(),
            ),
            builder: (context, streakSnapshot) {
              return StreamBuilder<List<String>>(
                stream: context
                    .read<FriendService>()
                    .getAcceptedFriendUidsStream(),
                builder: (context, friendsSnapshot) {
                  return SmartSuggestionsList(
                    todayStats: stats,
                    journalStreak: streakSnapshot.data ?? 0,
                    hasCircle:
                        (friendsSnapshot.data ?? const <String>[]).isNotEmpty,
                    tasksCount: tasksCount,
                    classesCountThisWeek: classesCountThisWeek,
                    onOpenVaultOneLine: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const VaultJournalView(
                            embedded: false,
                            oneLineMode: true,
                          ),
                        ),
                      );
                    },
                    onPlanFocusBlock: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Focus planner improves in next update.',
                          ),
                        ),
                      );
                    },
                    onOpenCircle: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const FriendsHubScreen(),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  // ignore: unused_element
  Widget _buildSmartRecap(BuildContext context, MemoryService memory) {
    final facts = memory.getFacts();
    if (facts.isEmpty) return const SizedBox.shrink();

    // Find deadline-type memories and show countdowns
    final recapItems = <Widget>[];

    for (final entry in facts.entries.take(3)) {
      final key = entry.key;
      final value = entry.value.toString();
      final displayKey = key.replaceAll('_', ' ');

      recapItems.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: VyomaColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: VyomaColors.borderSubtle, width: 0.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: VyomaColors.accent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  Icons.lightbulb_outline_rounded,
                  color: VyomaColors.accentMuted,
                  size: 14,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayKey,
                      style: TextStyle(
                        color: VyomaColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: TextStyle(
                        color: VyomaColors.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MEMORY',
                style: TextStyle(
                  color: VyomaColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MemoryVaultScreen(),
                    ),
                  ),
                  child: Text(
                    'See all →',
                    style: TextStyle(
                      color: VyomaColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...recapItems.asMap().entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: e.value,
            ).animate(delay: (60 * e.key).ms).fadeIn(),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildDebriefSection(BuildContext context) {
    return Consumer<MemoryService>(
      builder: (context, memory, _) {
        final pending = memory.getPendingDebriefs();
        if (pending.isEmpty) return const SizedBox.shrink();

        final debrief = pending.first;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: DebriefCard(
            title: debrief.title,
            eventId: debrief.eventId,
            onReport: () async {
              final warRoom = Provider.of<WarRoomViewModel>(
                context,
                listen: false,
              );
              await memory.removePendingDebrief(debrief.eventId);
              if (context.mounted) {
                Navigator.of(context).push(ChatSheet.slideUpRoute());
                Future.delayed(const Duration(milliseconds: 500), () {
                  warRoom.submitCommand(
                    "I am reporting for debrief on: '${debrief.title}'",
                  );
                });
              }
            },
          ),
        );
      },
    );
  }

  Future<void> _saveTodayStats(BuildContext context, DailyStats stats) async {
    final store = context.read<DailyStatsStore>();
    await store.save(stats);
  }

  Widget _buildEndOfDayCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: VyCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('End your day with Vyoma', style: VyText.titleLarge),
            const SizedBox(height: VySpacing.sm),
            Text(
              'Write one line about today and protect your streak.',
              style: VyText.bodyMedium,
            ),
            const SizedBox(height: VySpacing.md),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const VaultJournalView(
                      embedded: false,
                      oneLineMode: true,
                    ),
                  ),
                );
              },
              child: const Text('Open Vault'),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Good night';
  }
}

// --- Data Models ---

class _Suggestion {
  final IconData icon;
  final String title;
  final String subtitle;
  final String action;
  final Color color;

  const _Suggestion({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.color,
  });
}
