import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/task_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/vyoma_tokens.dart' show VyType;
import '../../domain/cognitive_load_forecaster.dart';

// Shows the next-7-day load forecast as a tiny bar strip with the peak day
// called out. Hidden when there is nothing to forecast — empty state would
// be noise.
class LoadForecastCard extends StatelessWidget {
  const LoadForecastCard({super.key});

  static const _forecaster = CognitiveLoadForecaster();

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TaskService>().tasks;
    final forecast = _forecaster.forecast(tasks);
    if (forecast.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'LOAD AHEAD',
                style: VyType.sectionLabel.copyWith(fontSize: 10),
              ),
              const Spacer(),
              if (forecast.peakLabel.isNotEmpty)
                Text(
                  'peak ${forecast.peakLabel}',
                  style: VyType.caption.copyWith(
                    color: AppColors.gold,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 36,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < forecast.daily.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _Bar(
                        value: forecast.daily[i],
                        isPeak: i == forecast.peakDayIndex,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (int i = 0; i < forecast.daily.length; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      _shortDayLabel(i),
                      style: VyType.caption.copyWith(
                        fontSize: 9,
                        color: i == forecast.peakDayIndex
                            ? AppColors.gold
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _shortDayLabel(int offset) {
    if (offset == 0) return 'TODAY';
    final d = DateTime.now().add(Duration(days: offset));
    switch (d.weekday) {
      case DateTime.monday:
        return 'MON';
      case DateTime.tuesday:
        return 'TUE';
      case DateTime.wednesday:
        return 'WED';
      case DateTime.thursday:
        return 'THU';
      case DateTime.friday:
        return 'FRI';
      case DateTime.saturday:
        return 'SAT';
      case DateTime.sunday:
        return 'SUN';
    }
    return '';
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.isPeak});

  final double value;
  final bool isPeak;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final maxH = constraints.maxHeight;
      final h = (value.clamp(0.0, 1.0)) * maxH;
      return Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: double.infinity,
            height: maxH,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: double.infinity,
            height: h < 2 ? 2 : h,
            decoration: BoxDecoration(
              color: isPeak ? AppColors.gold : AppColors.goldDim,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      );
    });
  }
}
