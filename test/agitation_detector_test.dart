import 'package:flutter_test/flutter_test.dart';
import 'package:vyoma/features/bindu_moment/domain/agitation_detector.dart';

void main() {
  test('does not propose on a single chat-open', () {
    final d = AgitationDetector();
    d.noteChatOpen();
    expect(d.shouldOfferBindu, isFalse);
  });

  test('proposes after a flurry of events crossing threshold', () {
    final d = AgitationDetector();
    d.noteTaskSwitch();
    d.noteTaskSwitch();
    d.noteTaskSwitch();
    d.noteTaskSwitch();
    expect(d.shouldOfferBindu, isTrue);
  });

  test('acknowledged() clears the proposal', () {
    final d = AgitationDetector();
    d.noteTaskSwitch();
    d.noteTaskSwitch();
    d.noteTaskSwitch();
    d.noteTaskSwitch();
    expect(d.shouldOfferBindu, isTrue);
    d.acknowledged();
    expect(d.shouldOfferBindu, isFalse);
  });

  test('dismissed() suppresses re-trigger immediately after', () {
    final d = AgitationDetector();
    d.noteTaskSwitch();
    d.noteTaskSwitch();
    d.noteTaskSwitch();
    d.noteTaskSwitch();
    d.dismissed();
    d.noteTaskSwitch();
    d.noteTaskSwitch();
    d.noteTaskSwitch();
    d.noteTaskSwitch();
    expect(d.shouldOfferBindu, isFalse,
        reason: 'cooldown should suppress fresh proposals');
  });
}
