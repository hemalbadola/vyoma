import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'vyoma_tokens.dart';

class VyomaTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: VyColors.background,
      fontFamily: VyType.fontFamily,

      colorScheme: const ColorScheme.dark(
        surface: VyColors.background,
        primary: VyColors.gold,
        secondary: VyColors.goldDim,
        error: VyColors.error,
        onSurface: VyColors.textPrimary,
        onPrimary: VyColors.background,
      ),

      textTheme: const TextTheme(
        displayLarge:  VyType.display,
        titleLarge:    VyType.title,
        titleMedium:   VyType.heading,
        bodyLarge:     VyType.body,
        bodyMedium:    VyType.bodyMuted,
        labelSmall:    VyType.caption,
        labelMedium:   VyType.sectionLabel,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: VyColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: VyType.title,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: VyColors.surface1,
        selectedItemColor: VyColors.gold,
        unselectedItemColor: VyColors.textFaint,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: VyType.accent,
        unselectedLabelStyle: VyType.caption,
      ),

      cardTheme: CardThemeData(
        color: VyColors.surface1,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(VyRadius.md),
          side: const BorderSide(color: VyColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: VyColors.surface1,
        hintStyle: VyType.bodyMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(VyRadius.md),
          borderSide: const BorderSide(color: VyColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(VyRadius.md),
          borderSide: const BorderSide(color: VyColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(VyRadius.md),
          borderSide: const BorderSide(color: VyColors.gold, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: VySpacing.md,
          vertical: VySpacing.md,
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: VyColors.borderSubtle,
        thickness: 1,
        space: 1,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: VyColors.gold,
          foregroundColor: VyColors.background,
          elevation: 0,
          textStyle: VyType.accent,
          padding: const EdgeInsets.symmetric(
            horizontal: VySpacing.lg,
            vertical: VySpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(VyRadius.md),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: VyColors.gold,
          textStyle: VyType.accent,
        ),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS:     CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS:   CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
