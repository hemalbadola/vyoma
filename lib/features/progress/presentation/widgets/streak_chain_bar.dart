import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/vy_card.dart';
import '../../../../core/widgets/vy_section_label.dart';

class StreakChainBar extends StatelessWidget {
  const StreakChainBar({
    super.key,
    required this.currentStreak,
    required this.bestStreak,
  });

  final int currentStreak;
  final int bestStreak;

  @override
  Widget build(BuildContext context) {
    final maxBase = bestStreak <= 0 ? 1 : bestStreak;
    final ratio = (currentStreak / maxBase).clamp(0.0, 1.0);
    return VyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const VySectionLabel('STREAK'),
          Container(
            height: 10,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: ratio,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      colors: [AppColors.accentDim, AppColors.accent],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: VySpacing.sm),
          Row(
            children: [
              Text('Current: $currentStreak days', style: VyText.bodyMedium),
              const Spacer(),
              Text('Best: $bestStreak days', style: VyText.bodyMedium),
            ],
          ),
        ],
      ),
    );
  }
}
