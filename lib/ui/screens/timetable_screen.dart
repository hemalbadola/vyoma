import 'package:flutter/material.dart';
import '../vyoma_theme.dart';
import '../widgets/weekly_calendar_grid.dart';
import '../widgets/background_mesh.dart';

class TimetableScreen extends StatelessWidget {
  final bool showBackButton;
  const TimetableScreen({super.key, this.showBackButton = true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VyomaColors.bgDeep,
      body: Stack(
        children: [
          const BackgroundMesh(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                const Expanded(
                  child: WeeklyCalendarGrid(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (showBackButton) ...[
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "TIMETABLE",
                    style: TextStyle(fontFeatures: const [FontFeature.tabularFigures()],
                      color: VyomaColors.accent,
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Weekly Grid",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
