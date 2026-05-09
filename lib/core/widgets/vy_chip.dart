import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

class VyChip extends StatelessWidget {
  const VyChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final targetScale = selected ? 1.03 : 1.0;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap?.call();
              },
        child: Center(
          child: AnimatedScale(
            scale: disableAnimations ? 1.0 : targetScale,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(
                vertical: VySpacing.sm,
                horizontal: VySpacing.md,
              ),
              decoration: BoxDecoration(
                color: selected ? AppColors.accentSurface : AppColors.surface2,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? AppColors.accent.withValues(alpha: 0.4)
                      : AppColors.border,
                ),
              ),
              child: Text(
                label,
                style: selected
                    ? VyText.bodyMedium.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w500,
                      )
                    : VyText.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
