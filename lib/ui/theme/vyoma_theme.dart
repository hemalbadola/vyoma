import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'vyoma_colors.dart';
import 'vyoma_text_styles.dart';

class VyomaTheme {
  static ThemeData get dark => ThemeData.dark().copyWith(
    scaffoldBackgroundColor: VyomaColors.bgBase,
    colorScheme: const ColorScheme.dark(
      primary:    VyomaColors.accent,
      secondary:  VyomaColors.accentBright,
      tertiary:   VyomaColors.accentGlow,
      surface:    VyomaColors.bgCard,
      onSurface:  VyomaColors.textPrimary,
      error:      VyomaColors.error,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor:    VyomaColors.textPrimary,
      displayColor: VyomaColors.textPrimary,
    ),
    dividerColor: VyomaColors.divider,
    cardColor:    VyomaColors.bgCard,
  );
}
