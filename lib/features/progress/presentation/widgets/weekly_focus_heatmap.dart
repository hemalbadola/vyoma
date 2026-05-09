import 'package:flutter/material.dart';

import '../../../../core/models/daily_stats.dart';
import '../../../../core/theme/app_theme.dart';

enum FocusBucket { none, low, medium, high }

FocusBucket bucketForMinutes(int minutes) {
  if (minutes == 0) return FocusBucket.none;
  if (minutes < 25) return FocusBucket.low;
  if (minutes < 60) return FocusBucket.medium;
  return FocusBucket.high;
}

class WeeklyFocusHeatmap extends StatefulWidget {
  const WeeklyFocusHeatmap({super.key, required this.last7Days});

  final List<DailyStats> last7Days;

  @override
  State<WeeklyFocusHeatmap> createState() => _WeeklyFocusHeatmapState();
}

class _WeeklyFocusHeatmapState extends State<WeeklyFocusHeatmap> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  Color _colorForBucket(FocusBucket bucket) {
    switch (bucket) {
      case FocusBucket.none:
        return AppColors.surface2;
      case FocusBucket.low:
        return const Color(0xFF153C2F);
      case FocusBucket.medium:
        return const Color(0xFF1E5A40);
      case FocusBucket.high:
        return const Color(0xFF2FA36A);
    }
  }

  String _dayShort(String id) {
    final parts = id.split('-');
    if (parts.length != 3) return '';
    final dt = DateTime(
      int.tryParse(parts[0]) ?? 0,
      int.tryParse(parts[1]) ?? 1,
      int.tryParse(parts[2]) ?? 1,
    );
    const map = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return map[(dt.weekday - 1).clamp(0, 6)];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 280),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: widget.last7Days.map((stats) {
          final bucket = bucketForMinutes(stats.focusMinutes);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _dayShort(stats.id),
                style: VyText.labelSmall.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: VySpacing.xs),
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: _colorForBucket(bucket),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
