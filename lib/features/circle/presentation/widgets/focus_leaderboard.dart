import 'package:flutter/material.dart';

import '../../../../core/models/focus_rank_entry.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/vy_card.dart';

class FocusLeaderboard extends StatelessWidget {
  const FocusLeaderboard({
    super.key,
    required this.entries,
    required this.currentUserId,
  });

  final List<FocusRankEntry> entries;
  final String currentUserId;

  String _durationLabel(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h ${m}m';
  }

  String _medal(int rank) {
    if (rank == 0) return '🥇';
    if (rank == 1) return '🥈';
    if (rank == 2) return '🥉';
    return '${rank + 1}';
  }

  void _showStubSheet(BuildContext context, FocusRankEntry e) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface1,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(VySpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.displayName, style: VyText.titleLarge),
            const SizedBox(height: VySpacing.sm),
            Text(
              'Weekly focus: ${_durationLabel(e.focusMinutesThisWeek)}',
              style: VyText.bodyMedium,
            ),
            const SizedBox(height: VySpacing.sm),
            Text('Coming soon: deeper squad stats', style: VyText.labelSmall),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sorted = List<FocusRankEntry>.from(
      entries,
    )..sort((a, b) => b.focusMinutesThisWeek.compareTo(a.focusMinutesThisWeek));
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...sorted.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isSelf = item.userId == currentUserId;
          final initials = item.displayName.trim().isEmpty
              ? '?'
              : item.displayName.trim().substring(0, 1).toUpperCase();
          return Padding(
            padding: const EdgeInsets.only(bottom: VySpacing.sm),
            child: GestureDetector(
              onTap: () => _showStubSheet(context, item),
              child: AnimatedContainer(
                duration: disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: VyCard(
                  variant: isSelf ? VyCardVariant.hero : VyCardVariant.standard,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(_medal(index), style: VyText.labelSmall),
                      ),
                      const SizedBox(width: VySpacing.md),
                      CircleAvatar(
                        radius: index < 3 ? 16 : 14,
                        backgroundColor: AppColors.surface2,
                        child: Text(
                          initials,
                          style: VyText.labelSmall.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: VySpacing.md),
                      Expanded(
                        child: Text(
                          item.displayName,
                          style: isSelf
                              ? VyText.titleMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                )
                              : VyText.titleMedium,
                        ),
                      ),
                      Text(
                        _durationLabel(item.focusMinutesThisWeek),
                        style: VyText.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        if (sorted.any((e) => e.isPreview))
          Text(
            'Sample data - backend ranking coming soon',
            style: VyText.labelSmall.copyWith(color: AppColors.textMuted),
          ),
      ],
    );
  }
}
