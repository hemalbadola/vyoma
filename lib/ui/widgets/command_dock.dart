import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class CommandDock extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback onCommand;

  const CommandDock({
    super.key, 
    required this.currentIndex, 
    required this.onTap,
    required this.onCommand
  });

  // High Contrast Palette
  static const kCardBg = Color(0xFF121212);
  static const kBorder = Color(0xFF2A2A2A);
  static const kEmerald = Color(0xFF10B981);
  static const kTextPrimary = Color(0xFFFFFFFF);
  static const kTextMuted = Color(0xFF737373);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 28, left: 28, right: 28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kBorder, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Home
              _NavItem(
                symbol: "◈",
                label: "HOME",
                isSelected: currentIndex == 0,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap(0);
                },
              ),

              const SizedBox(width: 8),

              // Central Chat Orb with tooltip
              Tooltip(
                message: "Talk to Vyoma",
                textStyle: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kEmerald.withOpacity(0.3)),
                ),
                preferBelow: false,
                verticalOffset: 30,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      onCommand();
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: kEmerald,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: kEmerald.withOpacity(0.35),
                            blurRadius: 16,
                            spreadRadius: 0,
                          )
                        ]
                      ),
                      child: Center(
                        child: Text(
                          "◇",
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                    ).animate(onPlay: (c) => c.repeat(reverse: true))
                     .scaleXY(end: 1.04, duration: 2500.ms, curve: Curves.easeInOut),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Intel
              _NavItem(
                symbol: "◎",
                label: "INTEL",
                isSelected: currentIndex == 1,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap(1);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final String symbol;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.symbol,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _isPressed ? 0.92 : (_isHovered ? 1.05 : 1.0),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: widget.isSelected 
                  ? Colors.white.withOpacity(0.06) 
                  : (_isHovered ? Colors.white.withOpacity(0.03) : Colors.transparent),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.symbol,
                  style: GoogleFonts.inter(
                    color: widget.isSelected ? Colors.white : const Color(0xFF525252),
                    fontSize: 14,
                  ),
                ),
                if (widget.isSelected) ...[
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ).animate().fadeIn(duration: 150.ms).slideX(begin: -0.15),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
