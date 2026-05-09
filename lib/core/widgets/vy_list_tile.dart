import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'vy_card.dart';

class VyListTile extends StatelessWidget {
  const VyListTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return VyCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(VyRadius.md),
            ),
            child: Center(
              child: Icon(icon, size: 20, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: VySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: VyText.titleMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: VySpacing.xs),
                  Text(subtitle!, style: VyText.bodyMedium),
                ],
              ],
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.chevron_right,
              color: AppColors.textMuted,
              size: 18,
            ),
        ],
      ),
    );
  }
}
