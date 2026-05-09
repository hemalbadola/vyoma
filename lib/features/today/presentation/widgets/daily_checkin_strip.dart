import 'package:flutter/material.dart';

import '../../../../core/models/daily_stats.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/vy_card.dart';

// One question, one answer: "what is the one thing today?"
// Energy chips and focus-window picker were culled — neither was wired to a
// downstream consumer, both were chrome posing as features.
class DailyCheckinStrip extends StatelessWidget {
  const DailyCheckinStrip({
    super.key,
    required this.stats,
    required this.onOneThingChange,
  });

  final DailyStats stats;
  final ValueChanged<String> onOneThingChange;

  Future<void> _editOneThing(BuildContext context) async {
    final controller = TextEditingController(text: stats.oneThing ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: Text("today's one thing", style: VyText.titleLarge),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 2,
          style: VyText.bodyLarge,
          decoration: InputDecoration(
            hintText: 'one thing',
            hintStyle: VyText.bodyMedium.copyWith(color: AppColors.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('cancel', style: VyText.bodyMedium),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(
              'save',
              style: VyText.titleMedium.copyWith(color: AppColors.gold),
            ),
          ),
        ],
      ),
    );
    if (result == null) return;
    onOneThingChange(result);
  }

  @override
  Widget build(BuildContext context) {
    final hasOneThing =
        stats.oneThing != null && stats.oneThing!.trim().isNotEmpty;

    return VyCard(
      onTap: () => _editOneThing(context),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.gold,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("TODAY'S ONE THING", style: VyText.labelLarge),
                const SizedBox(height: 4),
                Text(
                  hasOneThing ? stats.oneThing!.trim() : 'tap to set',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: VyText.bodyLarge.copyWith(
                    color: hasOneThing
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            hasOneThing
                ? Icons.edit_outlined
                : Icons.add_rounded,
            color: AppColors.textMuted,
            size: 18,
          ),
        ],
      ),
    );
  }
}
