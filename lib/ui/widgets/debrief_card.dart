import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DebriefCard extends StatelessWidget {
  final String title;
  final String eventId;
  final VoidCallback onReport;

  const DebriefCard({
    super.key, 
    required this.title, 
    required this.eventId, 
    required this.onReport
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "MISSION DEBRIEF",
                style: GoogleFonts.jetBrainsMono(
                  color: const Color(0xFF8E8E93),
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Icon(Icons.history_edu, color: Colors.white54, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Mission Report: '$title'",
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
           Text(
            "Submit status report for adjudication.",
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          _buildButton(
            context, 
            label: "REPORT STATUS", 
            color: Colors.white, 
            textColor: Colors.black,
            onTap: onReport,
          ),
        ],
      ),
    );
  }

  Widget _buildButton(BuildContext context, {required String label, required Color color, required Color textColor, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 48,
        width: double.infinity,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
