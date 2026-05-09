import 'package:flutter/material.dart';
import '../theme/vyoma_tokens.dart';

class VyEmptyState extends StatelessWidget {
  final String headline;
  final String body;
  final String ctaLabel;
  final VoidCallback onCta;

  const VyEmptyState({
    super.key,
    required this.headline,
    required this.body,
    required this.ctaLabel,
    required this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VySpacing.xl,
        vertical: VySpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Bindu dot — the philosophical center of the empty state
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: VyColors.goldDim,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: VySpacing.lg),
          Text(
            headline,
            style: VyType.heading,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: VySpacing.sm),
          Text(
            body,
            style: VyType.bodyMuted,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: VySpacing.lg),
          TextButton(
            onPressed: onCta,
            child: Text(ctaLabel.toUpperCase(), style: VyType.accent),
          ),
        ],
      ),
    );
  }
}
