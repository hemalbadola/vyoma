import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/task_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/vyoma_tokens.dart' show VyType;
import '../../../bindu_moment/presentation/screens/bindu_moment_screen.dart';
import '../../domain/shadow_models.dart';
import '../../domain/shadow_service.dart';

// Surfaces the most concerning deferral pattern from the user's task list.
// Renders nothing if no pattern crosses the severity threshold.
//
// The framing line is the differentiator: "want to talk about it?" routes to
// a Bindu Moment, not a productivity nudge. Shadow is a *recognition*, not a
// to-do.
class ShadowPatternCard extends StatelessWidget {
  const ShadowPatternCard({super.key});

  static const _service = ShadowService();

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TaskService>().tasks;
    final pattern = _service.topDeferralPattern(tasks);
    if (pattern == null) return const SizedBox.shrink();
    return _PatternCard(pattern: pattern);
  }
}

class _PatternCard extends StatelessWidget {
  const _PatternCard({required this.pattern});

  final ShadowPattern pattern;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
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
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'THE SHADOW',
                style: VyType.sectionLabel.copyWith(fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            pattern.framing(),
            style: TextStyle(
              fontFamily: 'CormorantGaramond',
              fontSize: 18,
              fontWeight: FontWeight.w400,
              height: 1.4,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (_) => const BinduMomentScreen(),
                    ),
                  );
                },
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: Text(
                  'sit with it',
                  style: VyType.accent.copyWith(letterSpacing: 2),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'or close.',
                style: VyType.caption.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
