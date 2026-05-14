import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/vyoma_tokens.dart' show VyType;
import '../../domain/identity_anchor_service.dart';

// Ambient strip rendered on Today above the date. Reads quietly: a small
// gold dot, "BECOMING", the anchor sentence in Cormorant. Tap to edit.
//
// When unset, renders a single-line invitation. Once tapped through and set,
// it becomes the persistent identity reference.
class IdentityAnchorStrip extends StatelessWidget {
  const IdentityAnchorStrip({super.key});

  Future<void> _edit(BuildContext context) async {
    final svc = context.read<IdentityAnchorService>();
    final controller = TextEditingController(text: svc.anchor ?? '');
    final result = await showDialog<String>(
      context: context,
      barrierColor: AppColors.background.withValues(alpha: 0.85),
      builder: (context) => Dialog(
        backgroundColor: AppColors.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('the anchor', style: VyType.heading),
                const SizedBox(height: 4),
                Text(
                  'who are you trying to become\nin the next twelve months?',
                  style: VyType.bodyMuted.copyWith(height: 1.5),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 3,
                  minLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  style: VyType.body,
                  decoration: InputDecoration(
                    hintText: 'a writer who finishes things',
                    hintStyle: VyType.bodyMuted,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      child: Text(
                        'cancel',
                        style: VyType.accent.copyWith(
                          color: AppColors.textMuted,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).pop(controller.text.trim()),
                      child: Text(
                        'anchor',
                        style: VyType.accent.copyWith(letterSpacing: 1.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null) return;
    await svc.setAnchor(result);
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<IdentityAnchorService>();
    if (!svc.isInitialized) return const SizedBox.shrink();

    final hasAnchor = svc.hasAnchor;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _edit(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: hasAnchor ? AppColors.gold : AppColors.borderSubtle,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BECOMING',
                    style: VyType.sectionLabel.copyWith(
                      fontSize: 9,
                      letterSpacing: 2,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasAnchor
                        ? svc.anchor!
                        : 'name who you are becoming.',
                    style: TextStyle(
                      fontFamily: 'CormorantGaramond',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                      color: hasAnchor
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
