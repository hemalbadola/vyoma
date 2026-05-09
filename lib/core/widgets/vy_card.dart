import 'package:flutter/material.dart';
import '../theme/vyoma_tokens.dart';

enum VyCardVariant { standard, hero, ghost }

class VyCard extends StatelessWidget {
  final Widget child;
  final VyCardVariant variant;
  final EdgeInsets? padding;
  final VoidCallback? onTap;

  const VyCard({
    super.key,
    required this.child,
    this.variant = VyCardVariant.standard,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = switch (variant) {
      VyCardVariant.hero    => VyColors.goldDim,
      VyCardVariant.ghost   => Colors.transparent,
      VyCardVariant.standard => VyColors.border,
    };
    final bgColor = switch (variant) {
      VyCardVariant.ghost   => Colors.transparent,
      _                      => VyColors.surface1,
    };

    return AnimatedContainer(
      duration: VyDuration.fast,
      curve: VyCurves.standard,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.all(VyRadius.md),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.all(VyRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.all(VyRadius.md),
          splashColor: VyColors.goldGlow,
          highlightColor: VyColors.goldGlow,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(VySpacing.md),
            child: child,
          ),
        ),
      ),
    );
  }
}
