import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:googleapis/calendar/v3.dart';
import 'package:http/http.dart' as http;
import 'auth_manager_desktop.dart' if (dart.library.html) 'auth_manager_web.dart'; 
// Note: Web not targeted effectively, but good for conditional import structure.
// Actually, better to use conditional imports for mobile vs desktop if needed, 
// but since dart:io is available on both, we can just check Platform.isAndroid/iOS at runtime 
// or use a factory. However, google_sign_in has platform limitations.

import 'auth_manager_mobile.dart';
// import 'auth_manager_desktop.dart'; // Duplicate removed, already imported above conditionally/directly

abstract class AuthManager {
  Future<http.Client> getAuthenticatedClient();
  Future<CalendarApi> getCalendarApi();
  Future<void> signOut();

  factory AuthManager() {
    if (kIsWeb) {
      // Placeholder for web if ever needed
      throw UnimplementedError("Web not supported yet");
    } else if (Platform.isAndroid || Platform.isIOS) {
      return AuthManagerMobile();
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return AuthManagerDesktop();
    } else {
      throw UnsupportedError("Platform not supported");
    }
  }
}
