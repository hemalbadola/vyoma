import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';

class BackgroundMesh extends StatelessWidget {
  const BackgroundMesh({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF000000), // Pure black
      child: Stack(
        children: [
          // 1. Very subtle emerald glow (top-left)
          Positioned(
            top: -200,
            left: -150,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF059669).withValues(alpha: 0.04),
                    const Color(0xFF059669).withValues(alpha: 0.01),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
             .scaleXY(begin: 1.0, end: 1.1, duration: 12.seconds, curve: Curves.easeInOut),
          ),

          // 2. Very subtle burgundy glow (bottom-right)
          Positioned(
            bottom: -150,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8B0A1A).withValues(alpha: 0.03),
                    const Color(0xFF8B0A1A).withValues(alpha: 0.008),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
             .scaleXY(begin: 1.0, end: 1.15, duration: 15.seconds, curve: Curves.easeInOut),
          ),

          // 3. Subtle blur
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(color: Colors.transparent),
          ),
        ],
      ),
    );
  }
}
