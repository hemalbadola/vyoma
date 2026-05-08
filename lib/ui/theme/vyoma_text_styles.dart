import 'package:flutter/material.dart';
import 'vyoma_colors.dart';

/// Single source of truth for all Vyoma text styles.
/// Derived from codebase audit — May 2026.
///
/// Font family note: Inter is the dominant font (155 uses).
/// GoogleFonts.inter() cannot be used in const constructors,
/// so these are plain TextStyle with the default font.
/// Apply GoogleFonts.inter() at the ThemeData level via textTheme,
/// or use VyomaTextStyles.withInter() extension at call sites.
///
/// JetBrains Mono (63 uses) is handled via the [mono] token.
/// DM Sans (7 uses), Outfit (13 uses) are per-screen overrides
/// that will be addressed in Task 002 migration.
abstract final class VyomaTextStyles {
  // ── Display ──────────────────────────────────────────────────
  // Hero / splash text. Source: vault_journal:252 (fontSize: 34, w600).
  static const TextStyle displayLarge = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: VyomaColors.textPrimary,
  );

  // Large screen headers. Source: wakeup:146, memory_vault:77 (fontSize: 24, bold).
  static const TextStyle displayMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.3,
    color: VyomaColors.textPrimary,
  );

  // ── Headings ─────────────────────────────────────────────────
  // Section headings. Source: chat_sheet:789 (fontSize: 18, w600).
  static const TextStyle headingLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: VyomaColors.textPrimary,
  );

  // Card / subsection headings. Source: friends_hub:220 (fontSize: 16, bold).
  static const TextStyle headingMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: VyomaColors.textPrimary,
  );

  // Small headings / emphasized labels. Source: chat_sheet:475 (fontSize: 14, w500).
  static const TextStyle headingSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: VyomaColors.textPrimary,
  );

  // ── Body ─────────────────────────────────────────────────────
  // Large body text. Source: chat_sheet:484 (fontSize: 15, normal) — chat messages.
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.normal,
    height: 1.5,
    color: VyomaColors.textPrimary,
  );

  // Standard body text. Source: chat_sheet:1057 (fontSize: 14, height: 1.6).
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    height: 1.6,
    color: VyomaColors.textPrimary,
  );

  // Smaller body text. Source: vault_journal:294 (fontSize: 13).
  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    color: VyomaColors.textSecondary,
  );

  // ── Labels & Captions ────────────────────────────────────────
  // Section label (e.g., "TASKS", "YOUR SCHEDULE"). Source: 20+ (fontSize: 10-11, w600, letterSpacing).
  static const TextStyle label = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,
    color: VyomaColors.textMuted,
  );

  // Caption / metadata. Source: 30+ (fontSize: 12, normal-w500).
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: VyomaColors.textSecondary,
  );

  // ── Button ───────────────────────────────────────────────────
  // Button text. Source: derived from dominant fontSize: 14, w600.
  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    color: VyomaColors.textOnAccent,
  );

  // Small button / chip text. Source: fontSize: 12, w600.
  static const TextStyle buttonSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: VyomaColors.textOnAccent,
  );

  // ── Monospace ────────────────────────────────────────────────
  // Monospace text (timestamps, codes). Uses JetBrains Mono via GoogleFonts at call site.
  // Source: 63 uses of jetBrainsMono. Default fontSize: 11.
  static const TextStyle mono = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    fontFamily: 'monospace',
    color: VyomaColors.textSecondary,
  );
}
