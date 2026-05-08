import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'vyoma_colors.dart';
import 'vyoma_text_styles.dart';

/// Assembles ThemeData from Vyoma design tokens.
/// Wired in main.dart: `theme: VyomaTheme.dark`.
class VyomaTheme {
  VyomaTheme._();

  static ThemeData get dark => ThemeData.dark().copyWith(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: VyomaColors.bgPrimary,
    colorScheme: const ColorScheme.dark(
      primary:   VyomaColors.accent,
      secondary: VyomaColors.cyan,
      tertiary:  VyomaColors.accentLight,
      surface:   VyomaColors.bgSecondary,
      error:     VyomaColors.error,
      onSurface: VyomaColors.textPrimary,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge:  VyomaTextStyles.displayLarge,
      displayMedium: VyomaTextStyles.displayMedium,
      headlineLarge: VyomaTextStyles.headingLarge,
      headlineMedium: VyomaTextStyles.headingMedium,
      headlineSmall: VyomaTextStyles.headingSmall,
      bodyLarge:     VyomaTextStyles.bodyLarge,
      bodyMedium:    VyomaTextStyles.bodyMedium,
      bodySmall:     VyomaTextStyles.bodySmall,
      labelLarge:    VyomaTextStyles.button,
      labelMedium:   VyomaTextStyles.label,
      labelSmall:    VyomaTextStyles.caption,
    ),
    dividerColor: VyomaColors.divider,
    cardColor:    VyomaColors.bgCard,
  );
}
