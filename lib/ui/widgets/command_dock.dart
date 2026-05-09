import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/vyoma_tokens.dart';
import '../../tutorial/tutorial_keys.dart';

class CommandDock extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback onCommand;
  // Long-press the bindu FAB to enter a contemplative pause. Optional —
  // callers that don't pass it get tap-only behavior.
  final VoidCallback? onBinduMoment;
  final GlobalKey? navWarRoomKey;
  final GlobalKey? navIntelKey;
  final GlobalKey? navJournalKey;
  final GlobalKey? navScheduleKey;
  final GlobalKey? navCircleKey;

  const CommandDock({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onCommand,
    this.onBinduMoment,
    this.navWarRoomKey,
    this.navIntelKey,
    this.navJournalKey,
    this.navScheduleKey,
    this.navCircleKey,
  });

  @override
  State<CommandDock> createState() => _CommandDockState();
}

class _CommandDockState extends State<CommandDock> {
  bool _fabPressed = false;

  Widget _keyWrap(GlobalKey? key, Widget child) {
    if (key == null) return child;
    return KeyedSubtree(key: key, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    return SafeArea(
      top: false,
      child: Container(
        key: VyomaTutorialKeys.commandDock,
        decoration: const BoxDecoration(
          color: VyColors.surface1,
          border: Border(
            top: BorderSide(color: VyColors.border, width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(
          vertical: VySpacing.sm,
          horizontal: VySpacing.xs,
        ),
        child: Row(
          children: [
            Expanded(
              child: _keyWrap(
                widget.navWarRoomKey,
                _VyNavItem(
                  icon: Icons.brightness_low_rounded,
                  label: 'TODAY',
                  isSelected: widget.currentIndex == 0,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onTap(0);
                  },
                ),
              ),
            ),
            Expanded(
              child: _keyWrap(
                widget.navScheduleKey,
                _VyNavItem(
                  icon: Icons.calendar_view_week_rounded,
                  label: 'SCHEDULE',
                  isSelected: widget.currentIndex == 3,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onTap(3);
                  },
                ),
              ),
            ),
            // Bindu FAB — single primary action entry point
            GestureDetector(
              onTapDown: (_) {
                if (disableAnimations) return;
                setState(() => _fabPressed = true);
              },
              onTapCancel: () {
                if (disableAnimations) return;
                setState(() => _fabPressed = false);
              },
              onTapUp: (_) async {
                if (!disableAnimations) {
                  await Future<void>.delayed(VyDuration.fast);
                  if (mounted) setState(() => _fabPressed = false);
                }
              },
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onCommand();
              },
              onLongPress: widget.onBinduMoment == null
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      widget.onBinduMoment!();
                    },
              child: AnimatedScale(
                scale: _fabPressed ? 0.92 : 1.0,
                duration: VyDuration.fast,
                curve: VyCurves.standard,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: VyColors.gold,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chat_bubble_rounded,
                    color: VyColors.background,
                    size: 20,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _keyWrap(
                widget.navIntelKey,
                _VyNavItem(
                  icon: Icons.show_chart_rounded,
                  label: 'PROGRESS',
                  isSelected: widget.currentIndex == 1,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onTap(1);
                  },
                ),
              ),
            ),
            Expanded(
              child: _keyWrap(
                widget.navCircleKey,
                _VyNavItem(
                  icon: Icons.group_rounded,
                  label: 'CIRCLE',
                  isSelected: widget.currentIndex == 4,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onTap(4);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VyNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _VyNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? VyColors.gold : VyColors.textFaint;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.fade,
              style: VyType.sectionLabel.copyWith(
                color: color,
                fontSize: 9,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
