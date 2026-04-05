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
    if (referenceStart != null && referenceStart.isNotEmpty) {
      final refParts = referenceStart.split(':');
      final refHour = int.tryParse(refParts[0]) ?? 0;
      if (refHour >= 12 && hour < 12) {
        hour += 12;
      }
    }
    
    // Standalone heuristic: times 01:00-05:59 are almost certainly PM for a college schedule.
    if (hour >= 1 && hour <= 5) {
      hour += 12;
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

