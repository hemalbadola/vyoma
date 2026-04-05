import 'package:flutter_test/flutter_test.dart';
import 'package:vyoma/core/chronos_service.dart';
import 'package:vyoma/core/memory_service.dart';

class _FakeMemoryService extends MemoryService {
  final Map<String, dynamic> _store = {};

  @override
  dynamic getSegment(String key) => _store[key];

  @override
  Future<void> updateSegment(String key, dynamic data) async {
    _store[key] = data;
  }
}

void main() {
  group('ChronosService', () {
    test('returns active when no previous heartbeat exists', () {
      final memory = _FakeMemoryService();
      final chronos = ChronosService(memory);

      expect(chronos.getTimeGap(), Duration.zero);
      expect(chronos.analyzeTemporalState(), TemporalStatus.active);
    });

    test('returns newDay for 8+ hour gap', () {
      final memory = _FakeMemoryService();
      memory.updateSegment(
        'last_active_timestamp',
        DateTime.now().subtract(const Duration(hours: 9)).toIso8601String(),
      );
      final chronos = ChronosService(memory);

      expect(chronos.analyzeTemporalState(), TemporalStatus.newDay);
    });

    test('returns awol for 24+ hour gap', () {
      final memory = _FakeMemoryService();
      memory.updateSegment(
        'last_active_timestamp',
        DateTime.now().subtract(const Duration(hours: 25)).toIso8601String(),
      );
      final chronos = ChronosService(memory);

      expect(chronos.analyzeTemporalState(), TemporalStatus.awol);
    });

    test('returns longAbsence for 4+ day gap', () {
      final memory = _FakeMemoryService();
      memory.updateSegment(
        'last_active_timestamp',
        DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
      );
      final chronos = ChronosService(memory);

      expect(chronos.analyzeTemporalState(), TemporalStatus.longAbsence);
    });

    test('updateHeartbeat writes last_active_timestamp', () async {
      final memory = _FakeMemoryService();
      final chronos = ChronosService(memory);

      await chronos.updateHeartbeat();

      final value = memory.getSegment('last_active_timestamp');
      expect(value, isA<String>());
      expect(() => DateTime.parse(value as String), returnsNormally);
    });
  });
}
