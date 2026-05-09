import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/vy_card.dart';

class YouVsSquadBar extends StatelessWidget {
  const YouVsSquadBar({
    super.key,
    required this.yourMinutes,
    required this.squadAverageMinutes,
  });

  final int yourMinutes;
  final int squadAverageMinutes;

  @override
  Widget build(BuildContext context) {
    final maxBase = [
      yourMinutes,
      squadAverageMinutes,
      10,
    ].reduce((a, b) => a > b ? a : b);
    final youRatio = yourMinutes / maxBase;
    final squadRatio = squadAverageMinutes / maxBase;

    Widget bar({
      required String label,
      required int minutes,
      required double ratio,
      required Color color,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: VyText.bodyMedium),
              const Spacer(),
              Text(
                '${(minutes / 60).toStringAsFixed(1)}h',
                style: VyText.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: VySpacing.xs),
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
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return VyCard(
      child: Column(
        children: [
          bar(
            label: 'You',
            minutes: yourMinutes,
            ratio: youRatio,
            color: AppColors.accent,
          ),
          const SizedBox(height: VySpacing.md),
          bar(
            label: 'Squad avg',
            minutes: squadAverageMinutes,
            ratio: squadRatio,
            color: const Color(0xFF4D7A6B),
          ),
        ],
      ),
    );
  }
}
