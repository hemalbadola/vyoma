import 'package:flutter/foundation.dart';

/// Lightweight detector that emits a Bindu Moment proposal when it sees
/// signals consistent with agitation: rapid task switching, repeated
/// chat-open events in a short window.
///
/// v0 lives in memory only — no persistence, no firestore, no AI. Each
/// significant event ([noteTaskSwitch], [noteChatOpen]) increments a decaying
/// counter. When the counter crosses a threshold, [shouldOfferBindu] flips
/// true. The UI subscribes and offers (never imposes) a Bindu Moment.
///
/// Tone is everything. Surface this as a quiet snackbar, not a modal.
class AgitationDetector extends ChangeNotifier {
  AgitationDetector();

  // Each event adds to score; score decays toward zero with a half-life of
  // ~5 minutes (one decay tick per minute).
  static const _threshold = 1.5;
  static const _decayPerMinute = 0.85;
  static const _windowSeconds = 120;
  static const _cooldownAfterTrigger = Duration(minutes: 30);

  double _score = 0;
  DateTime _lastUpdate = DateTime.now();
  DateTime? _lastTrigger;
  DateTime? _lastDismiss;

  // Already-active proposal that the UI hasn't acknowledged yet.
  bool _proposed = false;

  /// True when we want the UI to offer a Bindu Moment.
  bool get shouldOfferBindu => _proposed;

  void _decay() {
    final now = DateTime.now();
    final mins = now.difference(_lastUpdate).inSeconds / 60.0;
    if (mins <= 0) return;
    _score *= _decayPerMinute * mins.clamp(0.0, 1.0) +
        (1 - mins.clamp(0.0, 1.0));
    if (_score < 0.001) _score = 0;
    _lastUpdate = now;
  }

  void _bumped(double delta) {
    _decay();
    final now = DateTime.now();
    final lastTrigger = _lastTrigger;
    if (lastTrigger != null &&
        now.difference(lastTrigger) < _cooldownAfterTrigger) {
      return;
    }
    final lastDismiss = _lastDismiss;
    if (lastDismiss != null &&
        now.difference(lastDismiss) < _cooldownAfterTrigger) {
      return;
    }
    _score += delta;
    _lastUpdate = now;
    if (_score >= _threshold && !_proposed) {
      _proposed = true;
      _lastTrigger = now;
      notifyListeners();
    }
  }

  /// Called when the user switches between active tasks rapidly. Each
  /// switch counts ~0.4; three within a short window crosses threshold.
  void noteTaskSwitch() => _bumped(0.4);

  /// Called when the user opens chat. Most one-offs are benign; rapid
  /// repeated opens are a stress signal.
  void noteChatOpen() => _bumped(0.3);

  /// Called when the user submits an "asap"-flavored sentence. Higher signal.
  void noteUrgentLanguage() => _bumped(0.6);

  /// User accepted the offer — clear and start cooldown.
  void acknowledged() {
    _proposed = false;
    _score = 0;
    notifyListeners();
  }

  /// User dismissed the offer — clear, set cooldown, do not re-trigger soon.
  void dismissed() {
    _proposed = false;
    _score = 0;
    _lastDismiss = DateTime.now();
    notifyListeners();
  }

  // For tests: read internal state.
  @visibleForTesting
  double get debugScore => _score;
  @visibleForTesting
  int get debugWindowSeconds => _windowSeconds;
}
