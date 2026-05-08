import 'package:flutter/material.dart';
import '../vyoma_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import '../../core/calendar_service.dart';
import '../../core/memory_service.dart';
import '../../core/task_service.dart';
import '../../core/timetable_service.dart';
import '../../core/models/timetable.dart';
import '../../ui/war_room_viewmodel.dart';
import '../../ui/widgets/debrief_card.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import '../../ui/widgets/chat_sheet.dart';
import '../../ui/screens/memory_vault_screen.dart';
import '../../ui/screens/timetable_screen.dart';

class CommandCenterTab extends StatelessWidget {
  const CommandCenterTab({super.key});


  // --- Energy State Derivation ---
  _EnergyState _deriveEnergyState(WarRoomViewModel vm) {
    final hour = DateTime.now().hour;
    final focusHours = vm.currentMetrics.focusMinutes / 60;

    // Sleep-based: if user was active very late (wakeup protocol data)
    // or early morning hours — they're likely tired
    if (hour >= 0 && hour < 6) {
      return _EnergyState(
        level: 'low',
        label: 'Rest mode',
        suggestion: 'You should be sleeping. Rest is the best productivity hack.',
        gradient: [const Color(0xFF051A14), const Color(0xFF030F0A)],
        icon: Icons.bedtime_rounded,
      );
    }
    if (hour >= 6 && hour < 9) {
      return _EnergyState(
        level: 'rising',
        label: 'Morning warmup',
        suggestion: 'Your brain is waking up — light tasks first, deep work after 10.',
        gradient: [const Color(0xFF0A1E18), const Color(0xFF081510)],
        icon: Icons.wb_twilight_rounded,
      );
    }
    if (hour >= 9 && hour < 13) {
      return _EnergyState(
        level: 'peak',
        label: 'Peak focus window',
        suggestion: focusHours > 0.5
            ? 'You\'re locked in — ${focusHours.toStringAsFixed(1)}h focused today. Keep going.'
            : 'This is your best window for deep work. Start a focus session now.',
        gradient: [const Color(0xFF052E16), const Color(0xFF042818)],
        icon: Icons.bolt_rounded,
      );
    }
    if (hour >= 13 && hour < 15) {
      return _EnergyState(
        level: 'dip',
        label: 'Post-lunch dip',
        suggestion: 'Energy naturally dips now. Take a walk, then tackle lighter tasks.',
        gradient: [const Color(0xFF0F1E18), const Color(0xFF0A1510)],
        icon: Icons.coffee_rounded,
      );
    }
    if (hour >= 15 && hour < 18) {
      return _EnergyState(
        level: 'second_wind',
        label: 'Second wind',
        suggestion: focusHours > 2
            ? 'Solid ${focusHours.toStringAsFixed(1)}h today. One more sprint before evening?'
            : 'Afternoon energy is back. Good time for creative or review work.',
        gradient: [const Color(0xFF0A1A15), const Color(0xFF081210)],
        icon: Icons.trending_up_rounded,
      );
    }
    if (hour >= 18 && hour < 21) {
      return _EnergyState(
        level: 'winding',
        label: 'Evening wind-down',
        suggestion: 'Start wrapping up. Journal your wins and plan tomorrow.',
        gradient: [const Color(0xFF0D1A16), const Color(0xFF0A1410)],
        icon: Icons.nights_stay_rounded,
      );
    }
    return _EnergyState(
      level: 'low',
      label: 'Night mode',
      suggestion: 'Time to rest. Your sleep quality affects tomorrow\'s focus.',
      gradient: [const Color(0xFF071210), const Color(0xFF050A08)],
      icon: Icons.dark_mode_rounded,
    );
  }

  // --- Contextual Suggestions ---
  List<_Suggestion> _getContextualSuggestions(WarRoomViewModel vm, MemoryService memory) {
    final hour = DateTime.now().hour;
    final hasFocus = vm.isFocusSessionActive;
    final focusHours = vm.currentMetrics.focusMinutes / 60;
    final facts = memory.getFacts();
    final hasGoal = (memory.getSegment('protocol') as Map?)?.containsKey('goal') ?? false;

    final suggestions = <_Suggestion>[];

    // Context-aware suggestions based on time and state
    if (hasFocus) {
      if (vm.currentMetrics.focusMinutes > 45) {
        suggestions.add(_Suggestion(
          icon: Icons.self_improvement_rounded,
          title: 'Take a break',
          subtitle: 'You\'ve been focused for ${(vm.currentMetrics.focusMinutes).toInt()}min. Move, hydrate.',
          action: '/focus stop',
          color: VyomaColors.warning,
        ));
      }
    } else if (hour >= 6 && hour < 12 && focusHours < 0.5) {
      suggestions.add(_Suggestion(
        icon: Icons.center_focus_strong_rounded,
        title: 'Start deep work',
        subtitle: 'Morning focus window is open. What are you working on?',
        action: 'start_focus',
        color: VyomaColors.accent,
      ));
    }

    if (hour >= 18 && hour < 23) {
      suggestions.add(_Suggestion(
        icon: Icons.edit_note_rounded,
        title: 'Journal today',
        subtitle: 'Capture wins, blockers, and tomorrow\'s plan.',
        action: 'journal',
        color: VyomaColors.info,
      ));
    }

    if (hour >= 7 && hour < 10 && !hasGoal) {
      suggestions.add(_Suggestion(
        icon: Icons.flag_rounded,
        title: 'Set your goal',
        subtitle: 'What\'s the #1 thing to accomplish today?',
        action: 'set_goal',
        color: VyomaColors.warning,
      ));
    }

    if (facts.isEmpty) {
      suggestions.add(_Suggestion(
        icon: Icons.psychology_rounded,
        title: 'Teach me about you',
        subtitle: 'Tell Vyoma about your exams, routines, or preferences.',
        action: 'chat',
        color: VyomaColors.accentBright,
      ));
    }

    // Always show a chat option if we have room
    if (suggestions.length < 3) {
      suggestions.add(_Suggestion(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Chat with Vyoma',
        subtitle: 'Plan, brainstorm, or just think out loud.',
        action: 'chat',
        color: VyomaColors.accent,
      ));
    }

    return suggestions.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 120),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Consumer2<WarRoomViewModel, MemoryService>(
                builder: (context, vm, memory, _) {
                  final energy = _deriveEnergyState(vm);
                  final suggestions = _getContextualSuggestions(vm, memory);
                  final taskService = Provider.of<TaskService>(context);
                  final timetableService = Provider.of<TimetableService>(context);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context, vm),
                      _buildEnergyHero(context, energy, vm),
                      _buildNextClass(context, timetableService),
                      _buildTaskBriefing(context, taskService),
                      _buildNextUp(context),
                      _buildSuggestions(context, suggestions, vm),
                      _buildSmartRecap(context, memory),
                      _buildDebriefSection(context),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WarRoomViewModel vm) {
    final now = DateTime.now();
    final greeting = _getGreeting();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: GoogleFonts.inter(
                  color: VyomaColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('EEEE, MMMM d').format(now),
                style: GoogleFonts.inter(
                  color: VyomaColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          // Focus hours badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: VyomaColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: VyomaColors.accent.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, color: VyomaColors.accentBright, size: 14),
                const SizedBox(width: 5),
                Text(
                  '${(vm.currentMetrics.focusMinutes / 60).toStringAsFixed(1)}h',
                  style: GoogleFonts.jetBrainsMono(
                    color: VyomaColors.accentBright,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildEnergyHero(BuildContext context, _EnergyState energy, WarRoomViewModel vm) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: energy.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(energy.icon, color: Colors.white.withValues(alpha: 0.8), size: 18),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      energy.label.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Energy: ${energy.level.replaceAll('_', ' ')}',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              energy.suggestion,
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 100.ms).slideY(begin: 0.05);
  }

  // --- Schedule & Next Class ---
  Widget _buildNextClass(BuildContext context, TimetableService timetableService) {
    final slots = timetableService.slots;
    final now = DateTime.now();
    
    TimetableSlot? nextSlot;
    if (slots.isNotEmpty) {
      final todaySlots = slots.where((s) {
        final weekday = _dayNameToWeekday(s.dayOfWeek);
        return weekday == now.weekday;
      }).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

      for (final slot in todaySlots) {
        final parts = slot.startTime.split(':');
        final slotTime = DateTime(now.year, now.month, now.day,
            int.parse(parts[0]), int.parse(parts[1]));
        if (slotTime.isAfter(now)) {
          nextSlot = slot;
          break;
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'YOUR SCHEDULE',
                style: GoogleFonts.jetBrainsMono(
                  color: VyomaColors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TimetableScreen()
                      )
                    );
                  },
                  child: Row(
                    children: [
                      Text(
                        'View Grid',
                        style: GoogleFonts.inter(
                          color: VyomaColors.textMuted, 
                          fontSize: 11, 
                          fontWeight: FontWeight.w500
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded, color: VyomaColors.textMuted, size: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (nextSlot == null)
            Text(
              "Your schedule is clear for the rest of the day.",
              style: GoogleFonts.inter(color: VyomaColors.textMuted.withValues(alpha: 0.8), fontSize: 13),
            )
          else
            _buildNextSlotCard(nextSlot, now),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 150.ms).slideX(begin: 0.03);
  }

  Widget _buildNextSlotCard(TimetableSlot nextSlot, DateTime now) {
    final startParts = nextSlot.startTime.split(':');
    final startTime = DateTime(now.year, now.month, now.day,
        int.parse(startParts[0]), int.parse(startParts[1]));
    final minsUntil = startTime.difference(now).inMinutes;
    final countdown = minsUntil < 60 
        ? '${minsUntil}min' 
        : '${(minsUntil / 60).toStringAsFixed(0)}h ${minsUntil % 60}m';

    final isImminent = minsUntil <= 15;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isImminent ? VyomaColors.warning.withValues(alpha: 0.06) : VyomaColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isImminent ? VyomaColors.warning.withValues(alpha: 0.25) : VyomaColors.borderSubtle,
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
              isImminent ? Icons.directions_run_rounded : Icons.school_rounded,
              color: isImminent ? VyomaColors.warning : VyomaColors.accentDeep,
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
                  style: GoogleFonts.inter(
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
                  style: GoogleFonts.inter(color: VyomaColors.textMuted, fontSize: 12),
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
              style: GoogleFonts.jetBrainsMono(
                color: isImminent ? VyomaColors.warningLight : VyomaColors.accentBright,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Task Briefing (Carryover + Due Today) ---
  Widget _buildTaskBriefing(BuildContext context, TaskService taskService) {
    final overdue = taskService.overdueTasks;
    final dueToday = taskService.dueTodayTasks;
    final carryover = taskService.getCarryoverTasks()
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
                style: GoogleFonts.inter(
                  color: VyomaColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 8),
              if (overdue.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: VyomaColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${overdue.length} overdue',
                    style: GoogleFonts.inter(
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                            style: GoogleFonts.inter(
                              color: VyomaColors.textPrimary.withValues(alpha: 0.9),
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
                              style: GoogleFonts.inter(
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
                        style: GoogleFonts.jetBrainsMono(
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
            )).animate(delay: (60 * entry.key).ms).fadeIn().slideX(begin: 0.03);
          }),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  int _dayNameToWeekday(String dayName) {
    switch (dayName.toLowerCase()) {
      case 'monday': return DateTime.monday;
      case 'tuesday': return DateTime.tuesday;
      case 'wednesday': return DateTime.wednesday;
      case 'thursday': return DateTime.thursday;
      case 'friday': return DateTime.friday;
      case 'saturday': return DateTime.saturday;
      case 'sunday': return DateTime.sunday;
      default: return -1;
    }
  }

  Widget _buildNextUp(BuildContext context) {
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
                style: GoogleFonts.inter(
                  color: VyomaColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                DateFormat('EEE, MMM d').format(DateTime.now()).toUpperCase(),
                style: GoogleFonts.inter(
                  color: VyomaColors.textMuted,
                  fontSize: 10,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SyncEventsWrapper(
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptySchedule();
              }

              final now = DateTime.now();
              // Sort by start time, show upcoming + currently active
              final events = snapshot.data!
                  .where((e) => e.start?.dateTime != null)
                  .where((e) {
                    final end = e.end?.dateTime ?? e.start!.dateTime!.add(const Duration(hours: 1));
                    final startLocal = e.start!.dateTime!.toLocal();
                    final endLocal = end.toLocal();
                    
                    final isStartToday = startLocal.year == now.year && startLocal.month == now.month && startLocal.day == now.day;
                    final isEndToday = endLocal.year == now.year && endLocal.month == now.month && endLocal.day == now.day;
                    
                    return (isStartToday || isEndToday) && end.isAfter(now); // Strictly show today's remaining active + future events
                  })
                  .toList()
                ..sort((a, b) => (a.start!.dateTime!).compareTo(b.start!.dateTime!));

              if (events.isEmpty) return _buildEmptySchedule();

              return Column(
                children: events.take(4).toList().asMap().entries.map((e) {
                  final event = e.value;
                  final isActive = event.start!.dateTime!.isBefore(now) &&
                      (event.end?.dateTime?.isAfter(now) ?? false);
                  final isNext = !isActive && e.key == 0 || 
                      (!isActive && e.key > 0 && events.take(e.key).every(
                        (prev) => prev.end?.dateTime?.isBefore(now) ?? true));

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildTimelineEvent(event, isActive: isActive, isNext: isNext),
                  ).animate(delay: (80 * e.key).ms).fadeIn().slideX(begin: 0.04);
                }).toList(),
              );
            },
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildTimelineEvent(calendar.Event event, {
    required bool isActive,
    required bool isNext,
  }) {
    final startDt = event.start?.dateTime;
    final endDt = event.end?.dateTime;
    final now = DateTime.now();

    // Progress for active events
    double progress = 0;
    if (isActive && startDt != null && endDt != null) {
      final total = endDt.difference(startDt).inMinutes;
      final elapsed = now.difference(startDt).inMinutes;
      progress = total > 0 ? (elapsed / total).clamp(0.0, 1.0) : 0;
    }

    // Countdown for next event
    String? countdown;
    if (isNext && startDt != null) {
      final mins = startDt.difference(now).inMinutes;
      if (mins > 0 && mins < 120) {
        countdown = 'in ${mins}min';
      } else if (mins >= 120) {
        countdown = 'in ${(mins / 60).toStringAsFixed(0)}h';
      }
    }

    final borderColor = isActive
        ? VyomaColors.accent.withValues(alpha: 0.3)
        : isNext
            ? VyomaColors.warning.withValues(alpha: 0.2)
            : VyomaColors.borderSubtle;
    final bgColor = isActive
        ? VyomaColors.accent.withValues(alpha: 0.04)
        : isNext
            ? VyomaColors.warning.withValues(alpha: 0.03)
            : VyomaColors.bgCard;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: isActive ? 1 : 0.5),
      ),
      child: Row(
        children: [
          // Time column
          SizedBox(
            width: 52,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatTime(startDt),
                  style: GoogleFonts.jetBrainsMono(
                    color: isActive ? VyomaColors.accentBright : VyomaColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: VyomaColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'NOW',
                      style: GoogleFonts.inter(
                        color: VyomaColors.accentBright,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
                if (countdown != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    countdown,
                    style: GoogleFonts.inter(
                      color: VyomaColors.warning.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Timeline dot + line
          Container(
            width: 1,
            height: isActive ? 44 : 36,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isActive ? VyomaColors.accent.withValues(alpha: 0.3) : VyomaColors.borderSubtle,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.summary ?? 'Untitled',
                  style: GoogleFonts.inter(
                    color: VyomaColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (isActive && progress > 0)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation(VyomaColors.accent.withValues(alpha: 0.6)),
                      minHeight: 3,
                    ),
                  )
                else
                  Text(
                    '${_formatTime(startDt)} → ${_formatTime(endDt)}',
                    style: GoogleFonts.inter(
                      color: VyomaColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
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
            child: Icon(Icons.calendar_today_rounded, color: VyomaColors.accentDeep, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No events coming up',
                  style: GoogleFonts.inter(
                    color: VyomaColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Chat with Vyoma to plan your day',
                  style: GoogleFonts.inter(color: VyomaColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions(BuildContext context, List<_Suggestion> suggestions, WarRoomViewModel vm) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SUGGESTED',
            style: GoogleFonts.inter(
              color: VyomaColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          ...suggestions.asMap().entries.map((e) {
            final s = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  splashColor: s.color.withValues(alpha: 0.06),
                  onTap: () => _handleSuggestion(context, s.action, vm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: VyomaColors.bgCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: VyomaColors.borderSubtle, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: s.color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(s.icon, color: s.color.withValues(alpha: 0.7), size: 18),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.title,
                                style: GoogleFonts.inter(
                                  color: VyomaColors.textPrimary.withValues(alpha: 0.9),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                s.subtitle,
                                style: GoogleFonts.inter(
                                  color: VyomaColors.textMuted,
                                  fontSize: 11.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, color: Colors.white12, size: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ).animate(delay: (80 * e.key).ms).fadeIn().slideX(begin: 0.04);
          }),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

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
                child: Icon(Icons.lightbulb_outline_rounded, color: VyomaColors.accentDeep, size: 14),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayKey,
                      style: GoogleFonts.inter(
                        color: VyomaColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: GoogleFonts.inter(
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
                style: GoogleFonts.inter(
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
                    MaterialPageRoute(builder: (_) => const MemoryVaultScreen()),
                  ),
                  child: Text(
                    'See all →',
                    style: GoogleFonts.inter(
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
          ...recapItems.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: e.value,
          ).animate(delay: (60 * e.key).ms).fadeIn()),
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
              final warRoom = Provider.of<WarRoomViewModel>(context, listen: false);
              await memory.removePendingDebrief(debrief.eventId);
              if (context.mounted) {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const ChatSheet(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return SlideTransition(
                        position: animation.drive(
                          Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
                            .chain(CurveTween(curve: Curves.easeOutQuart))
                        ),
                        child: child,
                      );
                    },
                  ),
                );
                Future.delayed(const Duration(milliseconds: 500), () {
                  warRoom.submitCommand("I am reporting for debrief on: '${debrief.title}'");
                });
              }
            },
          ),
        );
      },
    );
  }

  void _handleSuggestion(BuildContext context, String action, WarRoomViewModel vm) {
    switch (action) {
      case 'chat':
      case 'start_focus':
        _openChat(context);
        break;
      case 'journal':
        // Switch to vault tab via parent
        break;
      case 'set_goal':
        _openChat(context);
        Future.delayed(const Duration(milliseconds: 500), () {
          vm.submitCommand('/goal ');
        });
        break;
    }
  }

  void _openChat(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const ChatSheet(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: animation.drive(
              Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeOutQuart))
            ),
            child: child,
          );
        },
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Good night';
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '--:--';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// --- Data Models ---

class _EnergyState {
  final String level;
  final String label;
  final String suggestion;
  final List<Color> gradient;
  final IconData icon;

  const _EnergyState({
    required this.level,
    required this.label,
    required this.suggestion,
    required this.gradient,
    required this.icon,
  });
}

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


class _SyncEventsWrapper extends StatefulWidget {
  final Widget Function(BuildContext, AsyncSnapshot<List<calendar.Event>>) builder;
  const _SyncEventsWrapper({required this.builder});

  @override
  State<_SyncEventsWrapper> createState() => _SyncEventsWrapperState();
}

class _SyncEventsWrapperState extends State<_SyncEventsWrapper> {
  late Future<List<calendar.Event>> _future;

  @override
  void initState() {
    super.initState();
    _future = Provider.of<CalendarService>(context, listen: false).syncEvents();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<calendar.Event>>(
      future: _future,
      builder: widget.builder,
    );
  }
}
