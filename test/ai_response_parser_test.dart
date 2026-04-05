import 'package:flutter_test/flutter_test.dart';
import 'package:vyoma/core/ai_service.dart';
import 'package:vyoma/core/memory_service.dart';

class _FakeMemoryService extends MemoryService {
  @override
  dynamic getSegment(String key) => null;
}

void main() {
  group('AI XML parser', () {
    late AIService service;

    setUp(() {
      service = AIService(_FakeMemoryService());
    });

    test('parses attribute-style XML create with body summary', () {
      const xml = '''
<thought>t</thought>
<verbal>v</verbal>
<actions><create startTime="2026-03-18T11:35:06" notifyAt="2026-03-18T11:30:06">Swimming Class</create></actions>
<metric_delta>{"focus_change":0,"distraction_change":0,"task_change":0,"note":""}</metric_delta>
<memory_update>null</memory_update>
''';

      final parsed = service.parseXmlForTest(xml);
      expect(parsed.actions, isNotEmpty);
      final action = parsed.actions.first;
      expect(action.type, 'create');
      expect(action.startTime, '2026-03-18T11:35:06');
      expect(action.notifyAt, '2026-03-18T11:30:06');
      expect(action.summary, 'Swimming Class');
    });

    test('parses self-closing attribute XML create', () {
      const xml = '''
<thought>t</thought>
<verbal>v</verbal>
<actions><create startTime="2026-03-18T13:45:00" /></actions>
<metric_delta>{"focus_change":0,"distraction_change":0,"task_change":0,"note":""}</metric_delta>
<memory_update>null</memory_update>
''';

      final parsed = service.parseXmlForTest(xml);
      expect(parsed.actions, isNotEmpty);
      final action = parsed.actions.first;
      expect(action.type, 'create');
      expect(action.startTime, '2026-03-18T13:45:00');
    });

    test('parses JSON actions list path', () {
      const xml = '''
<thought>t</thought>
<verbal>v</verbal>
<actions>[{"type":"create","summary":"Karate Class","startTime":"2026-03-18T13:45:00"}]</actions>
<metric_delta>{"focus_change":0,"distraction_change":0,"task_change":0,"note":""}</metric_delta>
<memory_update>null</memory_update>
''';

      final parsed = service.parseXmlForTest(xml);
      expect(parsed.actions, hasLength(1));
      expect(parsed.actions.first.type, 'create');
      expect(parsed.actions.first.summary, 'Karate Class');
    });

    test('parses self-closing notify action with attributes', () {
      const xml = '''
<thought>t</thought>
<verbal>v</verbal>
<actions><notify message="Leave now" notifyAt="2026-03-18T10:50:00" /></actions>
<metric_delta>{"focus_change":0,"distraction_change":0,"task_change":0,"note":""}</metric_delta>
<memory_update>null</memory_update>
''';

      final parsed = service.parseXmlForTest(xml);
      expect(parsed.actions, hasLength(1));
      expect(parsed.actions.first.type, 'notify');
      expect(parsed.actions.first.message, 'Leave now');
      expect(parsed.actions.first.notifyAt, '2026-03-18T10:50:00');
    });

    test('parses create action with subject attribute', () {
      const xml = '''
<thought>t</thought>
<verbal>v</verbal>
<actions><create subject="XCS lecture" startTime="2026-03-18T10:00:00" /></actions>
<metric_delta>{"focus_change":0,"distraction_change":0,"task_change":0,"note":""}</metric_delta>
<memory_update>null</memory_update>
''';

      final parsed = service.parseXmlForTest(xml);
      expect(parsed.actions, hasLength(1));
      expect(parsed.actions.first.type, 'create');
      expect(parsed.actions.first.summary, 'XCS lecture');
      expect(parsed.actions.first.startTime, '2026-03-18T10:00:00');
    });

    test('does not crash on empty actions list', () {
      const xml = '''
<thought>t</thought>
<verbal>No action required.</verbal>
<actions>[]</actions>
<metric_delta>{"focus_change":0,"distraction_change":0,"task_change":0,"note":""}</metric_delta>
<memory_update>null</memory_update>
''';

      final parsed = service.parseXmlForTest(xml);
      expect(parsed.actions, isEmpty);
      expect(parsed.response, 'No action required.');
    });
  });
}
