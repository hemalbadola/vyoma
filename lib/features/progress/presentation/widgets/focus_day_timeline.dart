import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/focus_block.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/vy_card.dart';
import '../../../../ui/theme/vyoma_colors.dart';

/// Horizontal day timeline (YPT-style): blocks positioned on a 24h axis.
class FocusDayTimeline extends StatelessWidget {
  const FocusDayTimeline({
    super.key,
    required this.day,
    required this.blocks,
    this.embedded = false,
  });

  final DateTime day;
  final List<FocusBlock> blocks;
  /// When true, renders only the track + legend (no outer [VyCard]).
  final bool embedded;

  static const double _trackHeight = 44;
  static const double _hourLabelHeight = 18;

  @override
  Widget build(BuildContext context) {
    final dayLabel = DateFormat('EEE, MMM d').format(day);
    final totalMin = blocks.fold<int>(0, (s, b) => s + b.durationMinutes);

    final track = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!embedded) ...[
          Row(
            children: [
              Text(
                dayLabel,
                style: VyText.titleMedium.copyWith(
                  color: VyomaColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                totalMin > 0 ? '${totalMin}m focused' : 'No blocks yet',
                style: VyText.labelSmall.copyWith(color: VyomaColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          height: _trackHeight + _hourLabelHeight + 8,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return Column(
                children: [
                  SizedBox(
                    height: _trackHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _hourGrid(w),
                        ...blocks.map((b) => _blockChip(b, w, day)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  _hourLabels(w),
                ],
              );
            },
          ),
        ),
        if (blocks.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...blocks.reversed.take(embedded ? 6 : 4).map(_legendRow),
        ],
      ],
    );

    if (embedded) return track;
    return VyCard(child: track);
  }

  Widget _hourGrid(double width) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
    );
  }

  Widget _hourLabels(double width) {
    const marks = [0, 6, 12, 18, 24];
    return SizedBox(
      height: _hourLabelHeight,
      child: Stack(
        children: [
          for (final h in marks)
            Positioned(
              left: (h / 24.0) * width - (h == 24 ? 12 : 0),
              child: Text(
                h == 24 ? '24' : '$h',
                style: VyText.labelSmall.copyWith(
                  color: VyomaColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _blockChip(FocusBlock block, double width, DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    var start = block.start.isBefore(dayStart) ? dayStart : block.start;
    var end = block.end.isAfter(dayEnd) ? dayEnd : block.end;
    if (!end.isAfter(start)) return const SizedBox.shrink();

    final startFrac =
        start.difference(dayStart).inMinutes / (24 * 60);
    final endFrac = end.difference(dayStart).inMinutes / (24 * 60);
    final left = startFrac.clamp(0.0, 1.0) * width;
    final blockW = (endFrac - startFrac).clamp(0.02, 1.0) * width;

    final color = block.displayColor;
    final timeFmt = DateFormat('HH:mm');

    return Positioned(
      left: left,
      width: blockW.clamp(4, width - left),
      top: 6,
      height: _trackHeight - 12,
      child: Tooltip(
        message:
            '${block.task}\n${timeFmt.format(block.start)}–${timeFmt.format(block.end)} · ${block.durationMinutes}m · ${block.mode}',
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: blockW > 48
              ? Text(
                  block.task,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _legendRow(FocusBlock block) {
    final color = block.displayColor;
    final fmt = DateFormat('HH:mm');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              block.task,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VyText.bodyMedium.copyWith(color: VyomaColors.textPrimary),
            ),
          ),
          Text(
            '${fmt.format(block.start)} · ${block.durationMinutes}m',
            style: VyText.labelSmall.copyWith(color: VyomaColors.textMuted),
          ),
        ],
      ),
    );
  }

}
