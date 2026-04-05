import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const kCardBg = Color(0xFF101114);
  static const kBorder = Color(0xFF2A2A2A);
  static const kEmerald = Color(0xFF10B981);
  static const kTextMuted = Color(0xFF7A7D85);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: kCardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kBorder, width: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _NavItem(
                      icon: Icons.home_rounded,
                      label: "TODAY",
                      isSelected: currentIndex == 0,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onTap(0);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CommandOrb(onCommand: onCommand),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.analytics_rounded,
                      label: "PROGRESS",
                      isSelected: currentIndex == 1,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onTap(1);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.auto_stories_rounded,
                      label: "JOURNAL",
                      isSelected: currentIndex == 2,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onTap(2);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.calendar_view_week_rounded,
                      label: "SCHEDULE",
                      isSelected: currentIndex == 3,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onTap(3);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CommandOrb extends StatefulWidget {
  final VoidCallback onCommand;

  const _CommandOrb({required this.onCommand});

  @override
  State<_CommandOrb> createState() => _CommandOrbState();
}

class _CommandOrbState extends State<_CommandOrb> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: "Talk to Vyoma",
      textStyle: GoogleFonts.inter(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
      ),
      preferBelow: false,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            widget.onCommand();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _isHovered ? const Color(0xFF14C88D) : const Color(0xFF10B981),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.35),
                  blurRadius: _isHovered ? 20 : 14,
                  spreadRadius: _isHovered ? 1.5 : 0.5,
                ),
              ],
            ),
            child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
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
          scale: _isPressed ? 0.95 : (_isHovered ? 1.02 : 1.0),
          duration: const Duration(milliseconds: 140),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? Colors.white.withValues(alpha: 0.08)
                  : (_isHovered ? Colors.white.withValues(alpha: 0.04) : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
              border: widget.isSelected
                  ? Border.all(color: Colors.white12, width: 0.6)
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  color: widget.isSelected ? Colors.white : const Color(0xFF7A7D85),
                  size: 18,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: widget.isSelected ? Colors.white : const Color(0xFF7A7D85),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
