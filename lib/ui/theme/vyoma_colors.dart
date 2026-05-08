import 'package:flutter/material.dart';

/// Single source of truth for all Vyoma colors.
/// Derived from codebase audit — May 2026.
///
/// Naming: role-based, not hex-based.
/// Rule: abstract final — never instantiated.
abstract final class VyomaColors {
  // ── Backgrounds ──────────────────────────────────────────────
  // Scaffold / deepest layer. Source: main.dart:222 (0xFF0A0A0F), settings_hub:28.
  static const Color bgPrimary = Color(0xFF0A0A0F);

  // Secondary surface (deep space). Source: main.dart:227 (0xFF0F0F1A), friends_hub:18, profile_setup:72.
  static const Color bgSecondary = Color(0xFF0F0F1A);

  // Card backgrounds. Source: mission_tab:23, intel_tab:16 (0xFF0E1114).
  // Conflict: chat_sheet:217 uses 0xFF111518, friends_hub uses 0xFF1A1A24.
  // Chose 0xFF0E1114 — most consistent with mission/intel tabs (the primary surfaces).
  static const Color bgCard = Color(0xFF0E1114);

  // Elevated card / input fields. Source: pending_action_card:24, chat_sheet:532 (0xFF111518).
  static const Color bgInput = Color(0xFF111518);

  // Chat-specific surfaces (keep as semantic tokens for chat bubble distinction).
  // Source: chat_sheet:126-129.
  static const Color bgChatSurface = Color(0xFF0A0D0F);
  static const Color bgUserBubble = Color(0xFF141A1F);
  static const Color bgVyomaBubble = Color(0xFF0C1214);

  // ── Text ─────────────────────────────────────────────────────
  // Primary text. Source: mission_tab:33, intel_tab:23 (0xFFFFFFFF / Colors.white).
  static const Color textPrimary = Color(0xFFFFFFFF);

  // Secondary text. Source: mission_tab:34, intel_tab:24 (0xFFA3A3A3), vault_journal.
  static const Color textSecondary = Color(0xFFA3A3A3);

  // Muted text / hints. Source: mission_tab:35, intel_tab:25 (0xFF6B7280).
  static const Color textMuted = Color(0xFF6B7280);

  // Hint / placeholder text. Source: vault_journal:239,329,347 (0xFF737373).
  static const Color textHint = Color(0xFF737373);

  // Text on accent-colored backgrounds.
  static const Color textOnAccent = Color(0xFFFFFFFF);

  // ── Accent (Emerald) ─────────────────────────────────────────
  // Primary accent. Source: 26+ occurrences across all files. THE dominant color.
  static const Color accent = Color(0xFF10B981);

  // Lighter accent variant. Source: mission_tab:27, vault_journal (0xFF34D399).
  static const Color accentLight = Color(0xFF34D399);

  // Dimmer accent. Source: chat_sheet:132, mission_tab:28 (0xFF059669).
  static const Color accentDim = Color(0xFF059669);

  // Brighter accent hover. Source: command_dock:184 (0xFF14C88D).
  static const Color accentHover = Color(0xFF14C88D);

  // ── Secondary Accent (Cyan) ──────────────────────────────────
  // Used in profile_setup, settings_hub, friends_hub. Source: 8 occurrences (0xFF06B6D4).
  static const Color cyan = Color(0xFF06B6D4);

  // ── Semantic ─────────────────────────────────────────────────
  // Success — same as accent in this design system.
  static const Color success = Color(0xFF10B981);

  // Warning / amber. Source: mission_tab:29, intel_tab:20 (0xFFF59E0B).
  static const Color warning = Color(0xFFF59E0B);

  // Warning light. Source: mission_tab:30 (0xFFFBBF24).
  static const Color warningLight = Color(0xFFFBBF24);

  // Error / danger. Source: pending_action_card:27 (0xFFEF4444), mission_tab:31 (0xFFF43F5E).
  // Two reds in use: EF4444 (red-500) and F43F5E (rose-500).
  // Chose EF4444 for error (destructive actions), F43F5E for rose (soft danger/overdue).
  static const Color error = Color(0xFFEF4444);

  // Rose — softer danger, used for overdue badges. Source: mission_tab:31 (0xFFF43F5E).
  static const Color rose = Color(0xFFF43F5E);

  // Info / blue. Source: mission_tab:32, intel_tab:22 (0xFF3B82F6).
  static const Color info = Color(0xFF3B82F6);

  // ── Borders / Dividers ───────────────────────────────────────
  // Primary border. Source: mission_tab:25, intel_tab:17 (0xFF1E2430).
  // Conflict: command_dock/glass_card use 0xFF2A2A2A, chat uses 0xFF1E2A33.
  // Chose 0xFF1E2430 — matches the tab surfaces that form the primary UI.
  static const Color border = Color(0xFF1E2430);

  // Chat-specific border. Source: chat_sheet:128 (0xFF1E2A33).
  static const Color borderChat = Color(0xFF1E2A33);

  // Stronger border variant. Source: vault_journal (0xFF2A3442).
  static const Color borderStrong = Color(0xFF2A3442);

  // Divider — subtle. Same as border for now.
  static const Color divider = Color(0xFF1E2430);

  // ── Legacy / Social (used in friends_hub, profile_setup) ─────
  // Violet — used in main.dart colorScheme, friends_hub pact.
  // NOT the primary accent. Retained as a named token for social features.
  static const Color violet = Color(0xFF7C3AED);

  // Indigo — friends_hub pact gradient. Source: friends_hub:210 (0xFF4F46E5).
  static const Color indigo = Color(0xFF4F46E5);

  // Gold / journal highlight. Source: vault_journal:704 (0xFFE5C158).
  static const Color gold = Color(0xFFE5C158);
}
