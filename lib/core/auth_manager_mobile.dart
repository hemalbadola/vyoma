import 'dart:io';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;
import 'package:googleapis/calendar/v3.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'auth_manager.dart';
import 'secrets.dart';

class AuthManagerMobile implements AuthManager {
  final gsi.GoogleSignIn _googleSignIn = gsi.GoogleSignIn(
    scopes: [CalendarApi.calendarScope],
    clientId: Platform.isIOS ? Secrets.iOSClientId : null, 
    // Android uses google-services.json usually, but we can try passing it if needed. 
    // However, google_sign_in recommends null for Android to let the plugin handle it via config.
  );
  
  gsi.GoogleSignInAccount? _currentUser;

  @override
  Future<http.Client> getAuthenticatedClient() async {
    try {
      _currentUser ??= await _googleSignIn.signInSilently();
      _currentUser ??= await _googleSignIn.signIn();
    } on PlatformException catch (e) {
      if (Platform.isAndroid) {
        throw Exception(
          'Google sign-in failed on Android (${e.code}). Verify OAuth setup: package name + SHA-1 in Google Cloud and add android/app/google-services.json.',
        );
      }
      rethrow;
    }
    
    if (_currentUser == null) {
      throw Exception('User declined sign in');
    }

    final authHeaders = await _currentUser!.authHeaders;
    final authenticateClient = auth.authenticatedClient(
      http.Client(),
      auth.AccessCredentials(
        auth.AccessToken(
          'Bearer',
          authHeaders['Authorization']!.split(' ').last,
          DateTime.now().toUtc().add(const Duration(hours: 1)), // Expiry handled by plugin usually
        ),
        null, // Refresh token not exposed by google_sign_in usually, handled internally
        [CalendarApi.calendarScope],
      ),
    );
    
    return authenticateClient;
  }

  @override
  Future<CalendarApi> getCalendarApi() async {
    final client = await getAuthenticatedClient();
    return CalendarApi(client);
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.disconnect();
    _currentUser = null;
  }
}
