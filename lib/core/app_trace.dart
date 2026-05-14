import 'package:flutter/foundation.dart';

/// Logs only when asserts are enabled (debug/profile). No overhead in release.
void traceDebug(String message) {
  assert(() {
    debugPrint(message);
    return true;
  }());
}
