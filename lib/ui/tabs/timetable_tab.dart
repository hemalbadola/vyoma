import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/weekly_calendar_grid.dart';

class TimetableTab extends StatelessWidget {
  const TimetableTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      'vyoma-icon-192.svg',
                      width: 18,
                      height: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "SCHEDULE",
                      style: GoogleFonts.inter(
                        color: const Color(0xFF737373),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Your week",
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B0D12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF252A35), width: 0.9),
                    ),
                    child: const WeeklyCalendarGrid(),
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
