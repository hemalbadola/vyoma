class TimetableSlot {
  final String dayOfWeek;
  final String startTime; // FORMAT: "HH:mm" (24h)
  final String endTime;   // FORMAT: "HH:mm" (24h)
  final String subject;
  final String venue;

  TimetableSlot({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.venue,
  });

  Map<String, dynamic> toJson() => {
    'dayOfWeek': dayOfWeek,
    'startTime': startTime,
    'endTime': endTime,
    'subject': subject,
    'venue': venue,
  };

  /// Normalizes 12-hour times to 24-hour format.
  /// College schedules run 08:00-18:00; any HH:mm where HH < 06 is likely PM.
  static String _normalizeTo24h(String time, {String? referenceStart}) {
    if (time.isEmpty) return time;
    final parts = time.split(':');
    if (parts.length != 2) return time;
    
    var hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts[1];
    
    // If referenceStart is provided, check if end < start (12h rollover)
    // Only apply this to typical college schedule hours (8 AM - 6 PM logic).
    // If we get "00" or "01", it's likely a true 24h midnight crossing, so don't touch it.
    if (referenceStart != null && referenceStart.isNotEmpty) {
      final refParts = referenceStart.split(':');
      final refHour = int.tryParse(refParts[0]) ?? 0;
      if (refHour >= 12 && hour < 12 && hour >= 6) {
        hour += 12;
      }
    }
    
    // Standalone heuristic: times 01:00-05:59 are almost certainly PM for a college schedule,
    // UNLESS the reference start is late night (like 23:00).
    if (hour >= 1 && hour <= 5) {
      // If we're crossing midnight (e.g. 23:00 to 01:00), we don't want to make it 13:00.
      bool isMidnightCross = false;
      if (referenceStart != null && referenceStart.isNotEmpty) {
        final refHour = int.tryParse(referenceStart.split(':')[0]) ?? 0;
        if (refHour >= 20) isMidnightCross = true;
      }
      if (!isMidnightCross) {
        hour += 12;
      }
    }
    
    return '${hour.toString().padLeft(2, '0')}:$minute';
  }

  factory TimetableSlot.fromJson(Map<String, dynamic> json) {
    final rawStart = (json['startTime'] ?? '').toString();
    final rawEnd = (json['endTime'] ?? '').toString();
    
    final normalizedStart = _normalizeTo24h(rawStart);
    final normalizedEnd = _normalizeTo24h(rawEnd, referenceStart: normalizedStart);
    
    return TimetableSlot(
      dayOfWeek: json['dayOfWeek'] ?? '',
      startTime: normalizedStart,
      endTime: normalizedEnd,
      subject: json['subject'] ?? '',
      venue: json['venue'] ?? '',
    );
  }
}

