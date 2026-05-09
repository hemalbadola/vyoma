// ─────────────────────────────────────────────────────────────────────────────
// glass_card.dart  —  Vyoma Glass Design System v2
//
// Design language: deep obsidian base + icy frosted surface + electric accent.
// Every card is a pane of cold glass floating over the mesh background.
//
// ANIMATION CONTRACTS (frame-by-frame):
//
//  [Press ripple]
//    Frame 0ms   : User finger/tap lands. Scale begins at 1.0 → 0.97.
//    Frame 0–80ms: Spring compression. Curve: Curves.easeIn. Scale → 0.97.
//                  Simultaneously: border opacity 0.18 → 0.42 (brightens).
//                  Inner glow sigma 0 → 6 (soft cyan bloom).
//    Frame 80ms  : Tap registered. Scale holds at 0.97 for 20ms.
//    Frame 80–180ms: Spring release. Scale 0.97 → 1.0. Curve: Curves.elasticOut.
//                  Border opacity 0.42 → 0.18. Glow sigma 6 → 0.
//
//  [Hover shimmer — desktop/iPad hover]
//    Frame 0ms   : Mouse enters card bounds.
//    Frame 0–350ms: A diagonal shimmer gradient sweeps left→right across the card.
//                  Start: translateX = -width. End: translateX = +width.
//                  Gradient: transparent → white 8% → transparent.
//                  Curve: Curves.easeInOut.
//    Frame 350ms : Shimmer exits. No repeat. Replays on next hover-enter.
//
//  [Glow pulse — showGlow: true]
//    Continuous loop, 2000ms period:
//    Frame 0–1000ms : BoxShadow blurRadius 18 → 32, spreadRadius -4 → 2.
//                     Opacity: glowColor.withAlpha(30) → glowColor.withAlpha(60).
//    Frame 1000–2000ms: blurRadius 32 → 18, spread 2 → -4. Opacity reverses.
//    Curve: Curves.easeInOut. Repeats forever.
//
//  [Entry animation — used when card first builds in a list]
//    Frame 0ms    : opacity 0, translateY +24px.
//    Frame 0–320ms: opacity 0→1, translateY +24→0. Curve: Curves.easeOutCubic.
//    Delay: staggered by index * 60ms when used in lists.
//
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:ui';
import 'package:flutter/material.dart';

// ── Token palette (aliased to gold/warm system) ───────────────────────────────
class VyomaGlass {
  VyomaGlass._();

  // Surfaces — warm void
  static const Color obsidian      = Color(0xFF0D0D0B);
  static const Color surface       = Color(0xFF151513);
  static const Color surfaceRaised = Color(0xFF1C1C1A);
  static const Color frost         = Color(0x14FFFFFF);
  static const Color frostStrong   = Color(0x22FFFFFF);

  // Borders
  static const Color borderSubtle  = Color(0xFF222220);
  static const Color borderActive  = Color(0xFF2A2820);
  static const Color borderAccent  = Color(0xFFD4AF72); // gold

  // Accent / glow — gold-only
  static const Color cyan          = Color(0xFFD4AF72);
  static const Color cyanDim       = Color(0x1ED4AF72);
  static const Color cyanGlow      = Color(0x26D4AF72);
  static const Color amber         = Color(0xFFD4AF72);
  static const Color amberDim      = Color(0x1ED4AF72);
  static const Color emerald       = Color(0xFFD4AF72);
  static const Color emeraldDim    = Color(0x1ED4AF72);
  static const Color rose          = Color(0xFF8B3A3A);
  static const Color roseDim       = Color(0x1E8B3A3A);

  // Text
  static const Color textPrimary   = Color(0xFFE8E4DC);
  static const Color textSecondary = Color(0xFF8A8780);
  static const Color textFaint     = Color(0xFF5C5A55);

  // Blur levels
  static const double blurTight    = 6.0;
  static const double blurMedium   = 12.0;
  static const double blurHeavy    = 22.0;
}

// ── Variants ──────────────────────────────────────────────────────────────────
enum GlassVariant {
  /// Default: semi-transparent dark frost. Use for cards, panels.
  standard,
  /// Elevated: slightly brighter frost + stronger border. Use for modals, sheets.
  elevated,
  /// Accent: cyan-tinted border + subtle cyan background tint.
  accent,
  /// Danger: rose tint. Use for destructive confirmations.
  danger,
  /// Ghost: near-invisible background, just a hairline border. Use for tags/chips.
  ghost,
}

// ── Main GlassCard ────────────────────────────────────────────────────────────
class GlassCard extends StatefulWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double blur;
  final double borderRadius;
  final GlassVariant variant;
  final bool showGlow;
  final Color? glowColor;
  /// If true, plays entry fade+slide animation when first built.
  final bool animateEntry;
  /// Stagger delay for list usage. e.g. index * 60ms.
  final Duration entryDelay;

  const GlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding          = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.blur             = VyomaGlass.blurMedium,
    this.borderRadius     = 16,
    this.variant          = GlassVariant.standard,
    this.showGlow         = false,
    this.glowColor,
    this.animateEntry     = false,
    this.entryDelay       = Duration.zero,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard>
    with TickerProviderStateMixin {

  // Press animation
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressScale;
  late final Animation<double> _pressBorderOpacity;

  // Glow pulse
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowBlur;
  late final Animation<double> _glowOpacity;

  // Entry
  late final AnimationController _entryCtrl;
  late final Animation<double> _entryOpacity;
  late final Animation<Offset> _entrySlide;

  // Hover shimmer
  late final AnimationController _shimmerCtrl;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();

    // ── Press ──
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(
        parent: _pressCtrl,
        curve: Curves.easeIn,
        reverseCurve: Curves.elasticOut,
      ),
    );
    _pressBorderOpacity = Tween<double>(begin: 0.18, end: 0.42).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeIn),
    );

    // ── Glow pulse ──
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _glowBlur = Tween<double>(begin: 18, end: 32).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
    _glowOpacity = Tween<double>(begin: 0.12, end: 0.28).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
    if (widget.showGlow) {
      _glowCtrl.repeat(reverse: true);
    }

    // ── Entry ──
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _entryOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic),
    );
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.06), // 24px at typical card height
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    if (widget.animateEntry) {
      Future.delayed(widget.entryDelay, () {
        if (mounted) _entryCtrl.forward();
      });
    } else {
      _entryCtrl.value = 1.0;
    }

    // ── Shimmer ──
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    _glowCtrl.dispose();
    _entryCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap != null) _pressCtrl.forward();
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onTap != null) {
      _pressCtrl.reverse();
      widget.onTap!();
    }
  }

  void _onTapCancel() {
    _pressCtrl.reverse();
  }

  void _onHoverEnter(PointerEvent _) {
    setState(() => _hovered = true);
    _shimmerCtrl.forward(from: 0);
  }

  void _onHoverExit(PointerEvent _) {
    setState(() => _hovered = false);
  }

  // ── Variant resolvers ──────────────────────────────────────────────────────

  Color _bgColor() {
    switch (widget.variant) {
      case GlassVariant.standard:
        return VyomaGlass.frost;
      case GlassVariant.elevated:
        return VyomaGlass.frostStrong;
      case GlassVariant.accent:
        return VyomaGlass.cyanDim;
      case GlassVariant.danger:
        return VyomaGlass.roseDim;
      case GlassVariant.ghost:
        return Colors.transparent;
    }
  }

  Color _borderColor() {
    switch (widget.variant) {
      case GlassVariant.accent:
        return VyomaGlass.borderAccent.withAlpha(90);
      case GlassVariant.danger:
        return VyomaGlass.rose.withAlpha(90);
      case GlassVariant.ghost:
        return VyomaGlass.borderSubtle;
      default:
        return VyomaGlass.borderSubtle;
    }
  }

  Color _resolvedGlow() =>
      widget.glowColor ??
      (widget.variant == GlassVariant.accent
          ? VyomaGlass.cyan
          : widget.variant == GlassVariant.danger
              ? VyomaGlass.rose
              : VyomaGlass.cyan);

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _entryOpacity,
      child: SlideTransition(
        position: _entrySlide,
        child: AnimatedBuilder(
          animation: Listenable.merge(
              [_pressCtrl, _glowCtrl, _shimmerCtrl]),
          builder: (context, _) {
            final borderOpacity = widget.onTap != null
                ? _pressBorderOpacity.value
                : (_hovered ? 0.30 : 0.18);
            final border = _borderColor().withAlpha((borderOpacity * 255).round());
            final glow = _resolvedGlow();

            return Transform.scale(
              scale: _pressScale.value,
              child: Container(
                width: widget.width,
                height: widget.height,
                margin: widget.margin,
                decoration: widget.showGlow
                    ? BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(widget.borderRadius),
                        boxShadow: [
                          BoxShadow(
                            color: glow.withAlpha(
                                (_glowOpacity.value * 255).round()),
                            blurRadius: _glowBlur.value,
                            spreadRadius: -2,
                          ),
                        ],
                      )
                    : null,
                child: MouseRegion(
                  cursor: widget.onTap != null
                      ? SystemMouseCursors.click
                      : MouseCursor.defer,
                  onEnter: _onHoverEnter,
                  onExit: _onHoverExit,
                  child: GestureDetector(
                    onTapDown: _onTapDown,
                    onTapUp: _onTapUp,
                    onTapCancel: _onTapCancel,
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(widget.borderRadius),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: widget.blur,
                          sigmaY: widget.blur,
                        ),
                        child: Container(
                          padding: widget.padding,
                          decoration: BoxDecoration(
                            color: _bgColor(),
                            borderRadius:
                                BorderRadius.circular(widget.borderRadius),
                            border: Border.all(color: border, width: 0.6),
                          ),
                          // Shimmer overlay
                          child: _hovered && widget.onTap != null
                              ? Stack(
                                  children: [
                                    widget.child,
                                    Positioned.fill(
                                      child: _ShimmerOverlay(
                                        animation: _shimmerCtrl,
                                        borderRadius: widget.borderRadius,
                                      ),
                                    ),
                                  ],
                                )
                              : widget.child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Shimmer overlay painted during hover ─────────────────────────────────────
class _ShimmerOverlay extends StatelessWidget {
  final Animation<double> animation;
  final double borderRadius;
  const _ShimmerOverlay({required this.animation, required this.borderRadius});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        // sweep from -1.0 to +2.0 across the card width
        final t = animation.value;
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: CustomPaint(
            painter: _ShimmerPainter(t),
          ),
        );
      },
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final double t;
  _ShimmerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final x = (t * (size.width + 160)) - 80;
    final gradient = LinearGradient(
      colors: [
        Colors.transparent,
        Colors.white.withAlpha(20),
        Colors.white.withAlpha(8),
        Colors.transparent,
      ],
      stops: const [0.0, 0.45, 0.55, 1.0],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      transform: GradientRotation(0.4),
    );
    final rect = Rect.fromLTWH(x - 80, 0, 160, size.height);
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..blendMode = BlendMode.plus;
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.t != t;
}

// ── Convenience: GlassChip ────────────────────────────────────────────────────
/// A small pill-shaped glass tag/badge.
class GlassChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? accentColor;
  final VoidCallback? onTap;

  const GlassChip({
    super.key,
    required this.label,
    this.icon,
    this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? VyomaGlass.cyan;
    return GlassCard(
      variant: GlassVariant.ghost,
      borderRadius: 99,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Convenience: GlassPanel ───────────────────────────────────────────────────
/// Full-width glass container for sections (no tap, heavier blur).
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      variant: GlassVariant.elevated,
      blur: VyomaGlass.blurHeavy,
      borderRadius: borderRadius,
      padding: padding,
      margin: margin,
      child: child,
    );
  }
}
