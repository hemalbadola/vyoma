import 'package:flutter/material.dart';

import 'vyoma_tokens.dart' as vy;

// Legacy palette aliased to the new gold/warm tokens. Old callers keep
// their `AppColors.*` references; values now point to VyColors.
abstract final class AppColors {
  static const Color background      = vy.VyColors.background;
  static const Color surface1        = vy.VyColors.surface1;
  static const Color surface2        = vy.VyColors.surface2;
  static const Color surface3        = vy.VyColors.surface2;
  static const Color border          = vy.VyColors.border;
  static const Color borderSubtle    = vy.VyColors.borderSubtle;

  static const Color textPrimary     = vy.VyColors.textPrimary;
  static const Color textSecondary   = vy.VyColors.textMuted;
  static const Color textMuted       = vy.VyColors.textFaint;

  static const Color accent          = vy.VyColors.gold;
  static const Color accentDim       = vy.VyColors.goldDim;
  static const Color accentSurface   = vy.VyColors.surface1;

  // Direct gold aliases for code that wants the new names without
  // dual-importing vyoma_tokens (which collides with VySpacing/VyRadius).
  static const Color gold            = vy.VyColors.gold;
  static const Color goldDim         = vy.VyColors.goldDim;
  static const Color goldGlow        = vy.VyColors.goldGlow;
  static const Color goldSurface     = vy.VyColors.surface1;

  static const Color errorColor      = vy.VyColors.error;
  static const Color warningColor    = vy.VyColors.gold;
}

// Legacy spacing — keep double-typed values so callers using
// `EdgeInsets.all(VySpacing.lg)` (which expects double) keep compiling.
abstract final class VySpacing {
  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 12;
  static const double lg   = 16;
  static const double xl   = 24;
  static const double xxl  = 32;
  static const double xxxl = 48;
}

// Legacy radius — double values for `BorderRadius.circular(...)`.
abstract final class VyRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
}

// Legacy text-style class — aliases to the new VyType so existing callers
// (`VyText.titleMedium`, etc.) compile unchanged with new visual identity.
abstract final class VyText {
  static TextStyle get displayLarge  => vy.VyType.display;
  static TextStyle get displayMedium => vy.VyType.title;
  static TextStyle get titleLarge    => vy.VyType.heading;
  static TextStyle get titleMedium   => vy.VyType.heading.copyWith(fontSize: 16);
  static TextStyle get bodyLarge     => vy.VyType.body;
  static TextStyle get bodyMedium    => vy.VyType.bodyMuted;
  static TextStyle get labelLarge    => vy.VyType.sectionLabel;
  static TextStyle get labelSmall    => vy.VyType.caption;
  static TextStyle get navLabel      => vy.VyType.sectionLabel.copyWith(fontSize: 9);
}
