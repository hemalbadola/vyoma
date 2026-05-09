import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a witness vow. The states are intentionally narrow — you cannot
/// "pause" a vow. Either you keep it, you break it, or you complete it.
enum VowStatus { active, completed, broken }

/// A single vow held by one user (owner) and witnessed by another.
///
/// The asymmetric structure is the whole point: the witness is not co-doing
/// the same task. They are a *holder* — a named person whose presence in your
/// commitment changes its weight.
class WitnessVow {
  final String id;
  final String ownerUid;
  final String witnessUid;
  final String vowText;
  final int durationDays;
  final DateTime startedAt;
  final DateTime expiresAt;
  // Date strings (YYYY-MM-DD) on which the owner checked in.
  final List<String> checkIns;
  final VowStatus status;

  const WitnessVow({
    required this.id,
    required this.ownerUid,
    required this.witnessUid,
    required this.vowText,
    required this.durationDays,
    required this.startedAt,
    required this.expiresAt,
    required this.checkIns,
    required this.status,
  });

  /// Days elapsed since the vow started, capped to durationDays.
  int daysElapsed(DateTime now) {
    final diff = now.difference(_startOfDay(startedAt)).inDays;
    if (diff < 0) return 0;
    if (diff > durationDays) return durationDays;
    return diff;
  }

  /// Days the owner has missed: elapsed days minus check-in days.
  /// If today is not yet ended, today is not counted as missed.
  int daysMissed(DateTime now) {
    final elapsed = daysElapsed(now);
    final missed = elapsed - checkIns.length;
    return missed < 0 ? 0 : missed;
  }

  bool checkedInToday(DateTime now) {
    return checkIns.contains(_dateKey(now));
  }

  Map<String, dynamic> toJson() => {
        'ownerUid': ownerUid,
        'witnessUid': witnessUid,
        'vowText': vowText,
        'durationDays': durationDays,
        'startedAt': Timestamp.fromDate(startedAt),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'checkIns': checkIns,
        'status': status.name,
      };

  factory WitnessVow.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return WitnessVow(
      id: doc.id,
      ownerUid: data['ownerUid'] as String? ?? '',
      witnessUid: data['witnessUid'] as String? ?? '',
      vowText: data['vowText'] as String? ?? '',
      durationDays: (data['durationDays'] as num?)?.toInt() ?? 30,
      startedAt: (data['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(days: 30)),
      checkIns: (data['checkIns'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      status: _statusFrom(data['status'] as String?),
    );
  }

  static VowStatus _statusFrom(String? s) {
    return VowStatus.values.firstWhere(
      (v) => v.name == s,
      orElse: () => VowStatus.active,
    );
  }

  static DateTime _startOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day);
  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
