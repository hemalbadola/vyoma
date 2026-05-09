import 'package:flutter/material.dart';

class VyColors {
  // Surfaces
  static const background     = Color(0xFF0D0D0B); // warm void black
  static const surface1       = Color(0xFF151513); // main cards
  static const surface2       = Color(0xFF1C1C1A); // nested cards / overlays
  static const border         = Color(0xFF2A2820); // card borders
  static const borderSubtle   = Color(0xFF222220); // dividers

  // Text
  static const textPrimary    = Color(0xFFE8E4DC); // warm white
  static const textMuted      = Color(0xFF8A8780); // secondary text
  static const textFaint      = Color(0xFF5C5A55); // metadata / timestamps

  // Gold — the only accent
  static const gold           = Color(0xFFD4AF72); // primary accent
  static const goldDim        = Color(0xFF8A7248); // inactive/muted gold
  static const goldGlow       = Color(0x26D4AF72); // gold at 15% opacity for glows

  // Semantic
  static const error          = Color(0xFF8B3A3A);
  static const success        = Color(0xFF3A6B4A);
}

class VyType {
  static const fontFamily = 'CormorantGaramond';

  // Display — used for screen titles and hero numbers only
  static const display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 36,
    fontWeight: FontWeight.w300,
    letterSpacing: 0.5,
    height: 1.2,
    color: VyColors.textPrimary,
  );

  // Title — screen headers
  static const title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.3,
    height: 1.25,
    color: VyColors.textPrimary,
  );

  // Section label — ALL CAPS, spaced, the wordmark energy
  static const sectionLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 2.5,
    height: 1.4,
    color: VyColors.textMuted,
  );

  // Heading — card titles
  static const heading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    height: 1.3,
    color: VyColors.textPrimary,
  );

  // Body — standard readable text
  static const body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.65,
    color: VyColors.textPrimary,
  );

  // Body muted — secondary body content
  static const bodyMuted = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.65,
    color: VyColors.textMuted,
  );

  // Caption — timestamps, metadata
  static const caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.3,
    height: 1.5,
    color: VyColors.textFaint,
  );

  // Number display — hero metrics (focus hours, streak)
  static const metric = TextStyle(
    fontFamily: fontFamily,
    fontSize: 48,
    fontWeight: FontWeight.w300,
    letterSpacing: -0.5,
    height: 1.0,
    color: VyColors.gold,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // Gold accent text — active nav, CTAs
  static const accent = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.5,
    height: 1.4,
    color: VyColors.gold,
  );
}

class VySpacing {
  static const xs  = 4.0;
  static const sm  = 8.0;
  static const md  = 16.0;
  static const lg  = 24.0;
  static const xl  = 32.0;
  static const xxl = 48.0;

  // Screen horizontal padding — consistent on every screen
  static const screenH = 20.0;
  // Screen top padding — the open ring breathing room
  static const screenTop = 24.0;
}

class VyRadius {
  static const sm  = Radius.circular(8);
  static const md  = Radius.circular(12);
  static const lg  = Radius.circular(16);
  static const xl  = Radius.circular(24);
  static const full = Radius.circular(999);
}

class VyDuration {
  static const fast    = Duration(milliseconds: 180);
  static const normal  = Duration(milliseconds: 320);
  static const slow    = Duration(milliseconds: 500);
  static const verySlow = Duration(milliseconds: 800);
}

class VyCurves {
  // The primary easing curve — everything uses this unless specified
  static const standard = Cubic(0.16, 1.0, 0.3, 1.0);  // ease out expo
  static const enter    = Cubic(0.0, 0.0, 0.2, 1.0);    // decelerate
  static const exit     = Cubic(0.4, 0.0, 1.0, 1.0);    // accelerate
}
