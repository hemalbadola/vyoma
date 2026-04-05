import 'package:intl/intl.dart';
import 'memory_service.dart';

class WakeupService {
  final MemoryService _memory;

  WakeupService(this._memory);

  /// Checks if the protocol should be triggered NOW.
  /// Returns true if:
  /// 1. Current time is within [wakeTime, wakeTime + 30 mins]
  /// 2. User has NOT confirmed wakeup for today yet.
  Future<bool> shouldTriggerProtocol() async {
    final prefs = _memory.getSegment('preferences') as Map<String, dynamic>? ?? {};
    final wakeTimeString = prefs['wake_time']; // "HH:mm"
    
    if (wakeTimeString == null) return false;

    final now = DateTime.now();
    final wakeTime = _parseTime(wakeTimeString, now);

    // Window: From WakeTime up to WakeTime + 60 mins
    // (If they are late, we still want to scream at them)
    final endWindow = wakeTime.add(const Duration(minutes: 60));

    // Check if entered window
    if (now.isAfter(wakeTime) && now.isBefore(endWindow)) {
       // Check if already done today
       final lastWakeupStr = prefs['last_wakeup_date']; // "YYYY-MM-DD"
       final todayStr = DateFormat('yyyy-MM-dd').format(now);
       
       if (lastWakeupStr != todayStr) {
         return true; // Trigger it!
       }
    }

    return false;
  }

  Future<void> confirmWakeup() async {
    final prefs = _memory.getSegment('preferences') as Map<String, dynamic>? ?? {};
    final now = DateTime.now();
    
    // Save new map to ensure mutability
    final newPrefs = Map<String, dynamic>.from(prefs);
    newPrefs['last_wakeup_date'] = DateFormat('yyyy-MM-dd').format(now);
    
    await _memory.updateSegment('preferences', newPrefs);
  }

  // Helper to parse "06:00" into today's DateTime
  DateTime _parseTime(String timeStr, DateTime now) {
    try {
      final parts = timeStr.split(":");
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (e) {
      // Fallback
      return DateTime(now.year, now.month, now.day, 6, 0);
    }
  }
}
