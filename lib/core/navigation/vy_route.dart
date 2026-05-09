import 'package:flutter/material.dart';
import '../theme/vyoma_tokens.dart';

// Vertical fade-slide — content rises from below like ascension
class VyRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  VyRoute({required this.page})
      : super(
          pageBuilder: (_, _, _) => page,
          transitionDuration: VyDuration.normal,
          reverseTransitionDuration: VyDuration.fast,
          transitionsBuilder: (_, animation, _, child) {
            final slide = Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: VyCurves.standard,
            ));
            final fade = Tween<double>(begin: 0, end: 1).animate(
              CurvedAnimation(parent: animation, curve: VyCurves.enter),
            );
            return FadeTransition(
              opacity: fade,
              child: SlideTransition(position: slide, child: child),
            );
          },
        );
}
