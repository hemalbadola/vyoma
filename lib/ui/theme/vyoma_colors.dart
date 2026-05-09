import 'package:flutter/material.dart';

import '../../core/theme/vyoma_tokens.dart';

// Legacy palette aliased to the new gold/warm token system.
// Existing callers keep their imports; values flip globally via VyColors.
abstract final class VyomaColors {
  // ── Backgrounds (warm void) ──
  static const Color bgDeep     = VyColors.background;
  static const Color bgBase     = VyColors.background;

  // ── Card surfaces ──
  static const Color bgCard         = VyColors.surface1;
  static const Color bgCardElevated = VyColors.surface2;
  static const Color bgCardHover    = VyColors.surface2;

  // ── Borders ──
  static const Color borderSubtle  = VyColors.borderSubtle;
  static const Color borderDefault = VyColors.border;
  static const Color borderActive  = VyColors.goldDim;

  // ── Accent (gold — single accent system-wide) ──
  static const Color accent        = VyColors.gold;
  static const Color accentMuted   = VyColors.goldGlow;
  static const Color accentBright  = VyColors.gold;
  static const Color accentDeep    = VyColors.goldDim;
  static const Color accentGlow    = VyColors.goldGlow;

  // ── Text ──
  static const Color textPrimary   = VyColors.textPrimary;
  static const Color textSecondary = VyColors.textMuted;
  static const Color textMuted     = VyColors.textFaint;
  static const Color textOnAccent  = VyColors.background;

  // ── Semantic ──
  static const Color success       = VyColors.success;
  static const Color warning       = VyColors.gold;
  static const Color warningLight  = VyColors.gold;
  static const Color error         = VyColors.error;
  static const Color info          = VyColors.gold;
  static const Color neutral       = VyColors.textMuted;

  // ── Dividers ──
  static const Color divider       = VyColors.borderSubtle;
}
