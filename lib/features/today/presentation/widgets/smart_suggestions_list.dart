import 'package:flutter/material.dart';

import '../../../../core/models/daily_stats.dart';
import '../../../../core/widgets/vy_list_tile.dart';

class SmartSuggestionsList extends StatelessWidget {
  const SmartSuggestionsList({
    super.key,
    required this.todayStats,
    required this.journalStreak,
    required this.hasCircle,
    required this.tasksCount,
    required this.classesCountThisWeek,
    required this.onOpenVaultOneLine,
    required this.onPlanFocusBlock,
    required this.onOpenCircle,
  });

  final DailyStats todayStats;
  final int journalStreak;
  final bool hasCircle;
  final int tasksCount;
  final int classesCountThisWeek;
  final VoidCallback onOpenVaultOneLine;
  final VoidCallback onPlanFocusBlock;
  final VoidCallback onOpenCircle;

  @override
  Widget build(BuildContext context) {
    final suggestions = <SmartSuggestion>[];

    if (journalStreak == 0 && !todayStats.journaled) {
      suggestions.add(
        SmartSuggestion(
          icon: Icons.edit_note_outlined,
          title: 'Start a journal streak',
          subtitle: 'One line today is enough.',
          onTap: onOpenVaultOneLine,
        ),
      );
    } else if (journalStreak >= 3 && !todayStats.journaled) {
      suggestions.add(
        SmartSuggestion(
          icon: Icons.local_fire_department_outlined,
          title: 'Protect your $journalStreak-day streak',
          subtitle: 'Write today\'s reflection.',
          onTap: onOpenVaultOneLine,
        ),
      );
    }

    if (todayStats.focusMinutes < 50) {
      suggestions.add(
        SmartSuggestion(
          icon: Icons.bolt_outlined,
          title: 'Plan one focus block',
          subtitle: 'Pick a 25-min block from your schedule.',
          onTap: onPlanFocusBlock,
        ),
      );
    }

    if (!hasCircle) {
      suggestions.add(
        SmartSuggestion(
          icon: Icons.people_outline,
          title: 'Build your circle',
          subtitle: 'Invite 1-3 friends for accountability.',
          onTap: onOpenCircle,
        ),
      );
    }

    if (suggestions.isEmpty) {
      suggestions.add(
        SmartSuggestion(
          icon: Icons.task_alt_outlined,
          title: tasksCount > 0 ? 'Finish one open task' : 'Keep momentum',
          subtitle: classesCountThisWeek > 0
              ? 'Stay consistent across classes and reflections.'
              : 'Small consistent wins compound fast.',
          onTap: onPlanFocusBlock,
        ),
      );
    }

    return Column(
      children: suggestions
          .take(3)
          .map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: VyListTile(
                icon: s.icon,
                title: s.title,
                subtitle: s.subtitle,
                onTap: s.onTap,
              ),
            ),
          )
          .toList(),
    );
  }
}

class SmartSuggestion {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  SmartSuggestion({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}
