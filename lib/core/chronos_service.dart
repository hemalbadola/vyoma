import 'dart:async';
import 'package:flutter/foundation.dart';
import 'memory_service.dart';

class ChronosService {
  final MemoryService _memory;
  
  // Constants
  static const int kAwolThresholdHours = 24;
  static const int kLongAbsenceThresholdDays = 4;

  ChronosService(this._memory);

  /// Returns the duration since the user was last active.
  /// Returns Duration.zero if first run.
  Duration getTimeGap() {
    final lastActiveStr = _memory.getSegment('last_active_timestamp');
    if (lastActiveStr == null) return Duration.zero;
    
    final lastActive = DateTime.parse(lastActiveStr);
    final now = DateTime.now();
    return now.difference(lastActive);
  }

  /// Updates the heartbeat timestamp. Call this periodically or on user interaction.
  Future<void> updateHeartbeat() async {
    await _memory.updateSegment('last_active_timestamp', DateTime.now().toIso8601String());
  }

  /// Analyzes the time gap and returns a status code/description.
  TemporalStatus analyzeTemporalState() {
     final gap = getTimeGap();
     
     if (gap.inDays >= kLongAbsenceThresholdDays) {
       return TemporalStatus.longAbsence; // 4+ Days (MIA)
     } else if (gap.inHours >= kAwolThresholdHours) {
       return TemporalStatus.awol; // 24h+ (AWOL)
     } else if (gap.inHours >= 8) {
       return TemporalStatus.newDay; // Likely a new day/sleep cycle
     } else {
       return TemporalStatus.active; // Standard session
     }
  }

  String getTemporalContext() {
    final status = analyzeTemporalState();
    final gap = getTimeGap();
    
    switch (status) {
      case TemporalStatus.longAbsence:
        return "CRITICAL PROTOCOL: User was MIA for ${gap.inDays} days. Assume negligence. Demand immediate status report.";
      case TemporalStatus.awol:
        return "WARNING: User was AWOL for ${gap.inHours} hours. Verify if tasks were abandoned.";
      case TemporalStatus.newDay:
        return "CONTEXT: New operational cycle detected. Gap: ${gap.inHours} hours.";
      case TemporalStatus.active:
        return "CONTEXT: Active session. Gap: ${gap.inMinutes} minutes.";
    }
  }
}

enum TemporalStatus {
  active,
  newDay,
  awol,       // 24h - 4 Days
  longAbsence // > 4 Days
}
