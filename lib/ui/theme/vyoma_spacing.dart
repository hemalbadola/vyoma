/// Single source of truth for all Vyoma spacing and border radii.
/// Derived from codebase audit — May 2026.
abstract final class VyomaSpacing {
  // ── Spacing Scale ────────────────────────────────────────────
  static const double xs   =  4.0;
  static const double sm   =  8.0;
  static const double md   = 12.0;
  static const double lg   = 16.0;
  static const double xl   = 24.0;
  static const double xxl  = 32.0;
  static const double xxxl = 48.0;

  // Bottom nav offset — consistent across all scrollable screens.
  // Source: mission_tab, command_center_tab use padding bottom: 120.
  static const double navOffset = 120.0;

  // ── Border Radius Scale ──────────────────────────────────────
  // Minimal rounding (status indicators, tiny pills).
  // Source: chat_sheet:231,385, command_dock:271 (radius: 2).
  static const double radiusXs  =  2.0;

  // Small badges / chips. Source: friends_hub:386,430, preferences:241 (radius: 4).
  static const double radiusSm  =  4.0;

  // Archive-specific (3 uses). Added to avoid magic numbers.
  // Source: archive_tab (radius: 7).
  static const double radius7   =  7.0;

  // Buttons, compact containers. Source: 12+ (radius: 8).
  static const double radiusMd  =  8.0;

  // Medium containers, badges. Source: 12+ (radius: 10).
  static const double radiusLg  = 10.0;

  // Cards, inputs — the dominant radius. Source: 30+ (radius: 12).
  static const double radiusXl  = 12.0;

  // Large cards. Source: 15+ (radius: 14).
  static const double radius14  = 14.0;

  // Modals, large cards. Source: 12+ (radius: 16).
  static const double radiusXxl = 16.0;

  // Chat bubbles. Source: chat_sheet (radius: 18).
  static const double radiusBubble = 18.0;

  // Bottom sheets, large rounded. Source: api_key_manager:17, command_dock:36 (radius: 20).
  static const double radiusSheet = 20.0;

  // Full-round buttons. Source: friends_hub:98, chat_sheet:770 (radius: 24).
  static const double radiusRound = 24.0;

  // Pill / circle shapes. Source: vault_journal (radius: 999).
  static const double radiusFull = 999.0;
}
