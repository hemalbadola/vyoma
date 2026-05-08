import 'dart:ui';
import 'package:flutter/material.dart';
import '../vyoma_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double blur;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final bool showGlow;
  final Color? glowColor;

  const GlassCard({
    super.key, 
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.blur = 6,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 12,
    this.showGlow = false,
    this.glowColor,
  });


  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? VyomaColors.bgCard;
    final border = borderColor ?? VyomaColors.borderSubtle;
    final glow = glowColor ?? VyomaColors.accent;
    
    Widget card = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: showGlow ? BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.12),
            blurRadius: 20,
            spreadRadius: -6,
          ),
        ],
      ) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: border, width: 0.5),
            ),
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: card),
      );
    }
    return card;
  }
}
