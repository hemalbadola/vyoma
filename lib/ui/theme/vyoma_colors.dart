import 'package:flutter/material.dart';

abstract final class VyomaColors {
  // ── Deep Backgrounds (Midnight / Abyss) ──
  static const Color bgDeep     = Color(0xFF02040A);
  static const Color bgBase     = Color(0xFF060B19);

  // ── Glass Card Surfaces ──
  static const Color bgCard        = Color(0x33060B19); // Glass L1 — 20% midnight
  static const Color bgCardElevated = Color(0x4D060B19); // Glass L2 — 30% midnight
  static const Color bgCardHover   = Color(0x66060B19); // Glass L3 — 40% midnight (hover)

  // ── Frosted Borders ──
  static const Color borderSubtle  = Color(0x1AFFFFFF); // 10% white
  static const Color borderDefault = Color(0x26FFFFFF); // 15% white
  static const Color borderActive  = Color(0x40FFFFFF); // 25% white

  // ── Emerald Accent (replaces all blue/cyan accent) ──
  static const Color accent        = Color(0xFF10B981); // Emerald 500
  static const Color accentMuted   = Color(0x3310B981); // 20% Emerald (tint)
  static const Color accentBright  = Color(0xFF34D399); // Emerald 400 (hover/bright)
  static const Color accentDeep    = Color(0xFF065F46); // Emerald 800 (deep bg tint)
  static const Color accentGlow    = Color(0xFF6EE7B7); // Emerald 300 (glow)

  // ── Text ──
  static const Color textPrimary   = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted     = Color(0xFF475569);
  static const Color textOnAccent  = Color(0xFF022C22);

  // ── Semantic ──
  static const Color success       = Color(0xFF10B981); // same as accent
  static const Color warning       = Color(0xFFF59E0B);
  static const Color warningLight  = Color(0xFFFBBF24);
  static const Color error         = Color(0xFFEF4444);
  static const Color info          = Color(0xFF0EA5E9);
  static const Color neutral       = Color(0xFF64748B);

  // ── Dividers ──
  static const Color divider       = Color(0x1AFFFFFF); // same as borderSubtle
}
