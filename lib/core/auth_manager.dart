import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:googleapis/calendar/v3.dart';
import 'package:http/http.dart' as http;
import 'auth_manager_desktop.dart'
    if (dart.library.html) 'auth_manager_web.dart';
// Note: Web not targeted effectively, but good for conditional import structure.
// Actually, better to use conditional imports for mobile vs desktop if needed,
// but since dart:io is available on both, we can just check Platform.isAndroid/iOS at runtime
// or use a factory. However, google_sign_in has platform limitations.

import 'auth_manager_mobile.dart';
// import 'auth_manager_desktop.dart'; // Duplicate removed, already imported above conditionally/directly

class AuthCooldownException implements Exception {
  final Duration retryAfter;

  const AuthCooldownException(this.retryAfter);

  @override
  String toString() {
    final mins = retryAfter.inMinutes;
    final secs = retryAfter.inSeconds % 60;
    if (mins > 0) {
      return secs > 0
          ? 'Auth cooldown active. Retry in ${mins}m ${secs}s.'
          : 'Auth cooldown active. Retry in ${mins}m.';
    }
    return 'Auth cooldown active. Retry in a few seconds.';
  }
}

class AuthConfigurationException implements Exception {
  final String message;

  const AuthConfigurationException(this.message);

  @override
  String toString() => message;
}

class AuthCancelledException implements Exception {
  final String message;

  const AuthCancelledException(this.message);

  @override
  String toString() => message;
}

abstract class AuthManager {
  Future<http.Client> getAuthenticatedClient({bool allowInteractive = true});
  Future<CalendarApi> getCalendarApi({bool allowInteractive = true});
  void clearAuthCooldown();
  Future<void> signOut();

  factory AuthManager() {
    if (kIsWeb) {
      // Placeholder for web if ever needed
      throw UnimplementedError("Web not supported yet");
    } else if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      // macOS uses the Google Sign-In plugin flow (same manager as mobile)
      // so we avoid the legacy desktop loopback/secret-based path.
      return AuthManagerMobile();
    } else if (Platform.isWindows || Platform.isLinux) {
      return AuthManagerDesktop();
    } else {
      throw UnsupportedError("Platform not supported");
    }
  }
}
