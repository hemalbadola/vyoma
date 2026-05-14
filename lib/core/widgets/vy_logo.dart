import 'package:flutter/material.dart';
import '../theme/vyoma_tokens.dart';

// Vyoma logomark — renders the user-supplied PNG icon.
// Sanskrit "व्योम" = sky, ether, void. The mark is the center of that void.
//
// The asset is the single source of truth for the brand mark.
// `color` is accepted for API symmetry but ignored — the PNG carries its own art.
class VyMark extends StatelessWidget {
  final double size;
  final Color? color;

  const VyMark({super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/vyoma_small_icon.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}

// Wordmark — "vyoma" set in Cormorant Garamond Light, lowercase, letter-spaced.
// The lowercase + airy spacing reads as restraint, not ceremony.
class VyWordmark extends StatelessWidget {
  final double fontSize;
  final Color? color;

  const VyWordmark({super.key, this.fontSize = 22, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Vyoma',
      style: TextStyle(
        fontFamily: VyType.fontFamily,
        fontSize: fontSize,
        fontWeight: FontWeight.w300,
        letterSpacing: fontSize * 0.18,
        height: 1.0,
        color: color ?? VyColors.textPrimary,
      ),
    );
  }
}

// Lockup — mark + wordmark side-by-side. Used on splash, login, settings header.
class VyLockup extends StatelessWidget {
  final double markSize;
  final Color? color;
  final MainAxisAlignment alignment;

  const VyLockup({
    super.key,
    this.markSize = 28,
    this.color,
    this.alignment = MainAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        VyMark(size: markSize, color: color),
        SizedBox(width: markSize * 0.45),
        VyWordmark(fontSize: markSize * 0.78, color: color),
      ],
    );
  }
}
