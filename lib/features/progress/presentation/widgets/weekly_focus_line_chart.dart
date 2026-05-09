import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/daily_stats.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/vy_card.dart';

List<DailyStats> orderedLast14Days(List<DailyStats> input) {
  final out = List<DailyStats>.from(input);
  out.sort((a, b) => a.id.compareTo(b.id));
  if (out.length <= 14) return out;
  return out.sublist(out.length - 14);
}

class WeeklyFocusLineChart extends StatelessWidget {
  const WeeklyFocusLineChart({super.key, required this.last14Days});

  final List<DailyStats> last14Days;

  @override
  Widget build(BuildContext context) {
    final days = orderedLast14Days(last14Days);
    final spots = <FlSpot>[];
    for (var i = 0; i < days.length; i++) {
      spots.add(FlSpot(i.toDouble(), days[i].focusMinutes / 60.0));
    }

    String labelFor(int i) {
      if (i < 0 || i >= days.length) return '';
      final parts = days[i].id.split('-');
      if (parts.length != 3) return '';
      final dt = DateTime(
        int.tryParse(parts[0]) ?? 0,
        int.tryParse(parts[1]) ?? 1,
        int.tryParse(parts[2]) ?? 1,
      );
      return DateFormat('MMM d').format(dt);
    }

    return VyCard(
      child: SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: 3,
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: 1,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: AppColors.borderSubtle, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: 1,
                  getTitlesWidget: (value, _) =>
                      Text('${value.toInt()}h', style: VyText.labelSmall),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (value, _) {
                    final idx = value.toInt();
                    final show = idx == 0 || idx == 6 || idx == 13;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        show ? labelFor(idx) : '',
                        style: VyText.labelSmall,
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: AppColors.accent,
                barWidth: 2.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, _, lineData, index) {
                    final adjust = (lineData.spots.length + index) * 0.0;
                    return FlDotCirclePainter(
                      radius: 2.4 + adjust,
                      color: AppColors.accent,
                      strokeColor: AppColors.accentSurface,
                      strokeWidth: 1,
                    );
                  },
                ),
                belowBarData: BarAreaData(show: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
