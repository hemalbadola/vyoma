import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/timetable_service.dart';
import '../../core/models/timetable.dart';

class AnimatedTimetable extends StatelessWidget {
  const AnimatedTimetable({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TimetableService>(
      builder: (context, timetableService, child) {
        final slots = timetableService.slots;
        
        if (slots.isEmpty) {
          return Center(
            child: Text(
               "Timetable Empty. Ask Vyoma to generate one.",
               style: TextStyle(color: Colors.white54, fontSize: 16),
            ).animate().fade(duration: 500.ms),
          );
        }

        // Group by Day
        final groupedSlots = <String, List<TimetableSlot>>{};
        for (var slot in slots) {
           groupedSlots.putIfAbsent(slot.dayOfWeek, () => []).add(slot);
        }

        final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: days.length,
          itemBuilder: (context, index) {
            final day = days[index];
            final daySlots = groupedSlots[day] ?? [];
            if (daySlots.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(
                    day.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                      letterSpacing: 2.0,
                    ),
                  ).animate().fadeIn(delay: Duration(milliseconds: 100 * index)).slideX(),
                ),
                ...daySlots.asMap().entries.map((entry) {
                   final slotIndex = entry.key;
                   final slot = entry.value;
                   
                   return Container(
                     margin: const EdgeInsets.only(bottom: 8),
                     padding: const EdgeInsets.all(16),
                     decoration: BoxDecoration(
                       color: Colors.white.withValues(alpha: 0.05),
                       borderRadius: BorderRadius.circular(12),
                       border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                     ),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(
                               slot.subject,
                               style: GoogleFonts.inter(
                                 fontSize: 16,
                                 fontWeight: FontWeight.w600,
                                 color: Colors.white,
                               ),
                             ),
                             const SizedBox(height: 4),
                             Text(
                               slot.venue,
                               style: GoogleFonts.inter(
                                 fontSize: 12,
                                 color: Colors.white54,
                               ),
                             ),
                           ],
                         ),
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                           decoration: BoxDecoration(
                             color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                             borderRadius: BorderRadius.circular(8),
                           ),
                           child: Text(
                             "\${slot.startTime} - \${slot.endTime}",
                             style: GoogleFonts.robotoMono(
                               fontSize: 12,
                               fontWeight: FontWeight.w500,
                               color: Theme.of(context).colorScheme.primary,
                             ),
                           ),
                         ),
                       ],
                     ),
                   ).animate().fadeIn(
                     delay: Duration(milliseconds: 300 + (100 * index) + (50 * slotIndex))
                   ).slideX(begin: 0.1);
                }),
                const SizedBox(height: 16),
              ],
            );
          },
        );
      },
    );
  }
}
