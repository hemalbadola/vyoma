import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;
import 'package:googleapis/calendar/v3.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'auth_manager.dart';
import 'secrets.dart';

class AuthManagerMobile implements AuthManager {
  static String? _nonEmptyOrNull(String raw) {
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  final String? _iosClientId = _nonEmptyOrNull(Secrets.iOSClientId);
  final String? _androidServerClientId = _nonEmptyOrNull(Secrets.webClientId);

  late final gsi.GoogleSignIn _googleSignIn = gsi.GoogleSignIn(
    scopes: [CalendarApi.calendarScope],
    clientId: Platform.isIOS ? _iosClientId : null,
    serverClientId: Platform.isAndroid ? _androidServerClientId : null,
  );

  late final gsi.GoogleSignIn _googleSignInFallbackNoServerClientId = gsi.GoogleSignIn(
    scopes: [CalendarApi.calendarScope],
    clientId: Platform.isIOS ? _iosClientId : null,
    serverClientId: null,
  );
  
  gsi.GoogleSignInAccount? _currentUser;

  // Race condition guard.
  Completer<http.Client>? _authInFlight;

  // Cooldown: after interactive sign-in fails, don't show the picker again
  // for this duration. Prevents the infinite popup loop.
  DateTime? _lastAuthFailure;
  static const _authCooldown = Duration(minutes: 5);

  bool get _isInCooldown =>
      _lastAuthFailure != null &&
      DateTime.now().difference(_lastAuthFailure!) < _authCooldown;

  Duration? get _authCooldownRemaining {
    final failedAt = _lastAuthFailure;
    if (failedAt == null) return null;
    final elapsed = DateTime.now().difference(failedAt);
    if (elapsed >= _authCooldown) return null;
    return _authCooldown - elapsed;
  }

  @override
  Future<http.Client> getAuthenticatedClient() async {
    // If an auth attempt is already running, piggyback on it.
    if (_authInFlight != null) {
      return _authInFlight!.future;
    }

    final completer = Completer<http.Client>();
    _authInFlight = completer;
    final allowInteractive = !_isInCooldown;

    try {
      final client = await _doAuthenticate(allowInteractive: allowInteractive);
      _lastAuthFailure = null; // Clear cooldown on success.
      completer.complete(client);
      return client;
    } catch (e) {
      if (e is AuthConfigurationException) {
        _lastAuthFailure = null;
      } else if (e is! AuthCooldownException) {
        _lastAuthFailure = DateTime.now();
      }
      completer.completeError(e);
      rethrow;
    } finally {
      _authInFlight = null;
    }
  }

  bool _isDeveloperError(PlatformException e) {
    final code = e.code.toLowerCase();
    final message = (e.message ?? '').toLowerCase();
    return code.contains('developer_error') || code == '10' || message.contains('developer_error');
  }

  Exception _mapPlatformException(PlatformException e) {
    final code = e.code.toLowerCase();
    final message = (e.message ?? '').toLowerCase();

    if (code.contains('sign_in_canceled') || code.contains('cancelled') || code.contains('canceled')) {
      return AuthCancelledException('Google sign-in was cancelled.');
    }

    if (_isDeveloperError(e)) {
      return AuthConfigurationException(
        'Google sign-in failed (${e.code}): ${e.message}. '
        'Verify Android OAuth package com.vyoma.app with correct SHA-1/SHA-256 and set VYOMA_WEB_CLIENT_ID to your Web OAuth client ID.',
      );
    }

    if (message.contains('network') || message.contains('timeout')) {
      return Exception('Google sign-in failed due to connectivity issues. Please retry.');
    }

    return Exception('Google sign-in failed (${e.code}): ${e.message}');
  }

  Future<gsi.GoogleSignInAccount?> _runSignInAttempt(
    gsi.GoogleSignIn signIn,
    {required bool allowInteractive}
  ) async {
    var user = await signIn.signInSilently();
    debugPrint('AuthManagerMobile: signInSilently => ${user?.email ?? "null"}');

    if (user == null) {
      if (!allowInteractive) {
        throw AuthCooldownException(_authCooldownRemaining ?? const Duration(seconds: 30));
      }
      user = await signIn.signIn();
      debugPrint('AuthManagerMobile: signIn => ${user?.email ?? "null"}');
    }

    return user;
  }

  Future<http.Client> _doAuthenticate({required bool allowInteractive}) async {
    debugPrint('AuthManagerMobile: Starting authentication...');
    debugPrint(
      'AuthManagerMobile: serverClientId configured = ${Platform.isAndroid ? _androidServerClientId != null : false}',
    );

    gsi.GoogleSignInAccount? signedInUser;
    try {
      signedInUser = await _runSignInAttempt(_googleSignIn, allowInteractive: allowInteractive);
    } on PlatformException catch (e) {
      debugPrint('AuthManagerMobile: PlatformException(primary): ${e.code} - ${e.message}');

      // Fallback for Android: if configured serverClientId is invalid, retry once without it.
      if (Platform.isAndroid && _androidServerClientId != null && _isDeveloperError(e)) {
        debugPrint('AuthManagerMobile: Retrying sign-in without serverClientId fallback.');
        try {
          signedInUser = await _runSignInAttempt(
            _googleSignInFallbackNoServerClientId,
            allowInteractive: allowInteractive,
          );
        } on PlatformException catch (fallbackError) {
          debugPrint('AuthManagerMobile: PlatformException(fallback): ${fallbackError.code} - ${fallbackError.message}');
          throw _mapPlatformException(fallbackError);
        }
      } else {
        throw _mapPlatformException(e);
      }
    }

    _currentUser = signedInUser;
    
    if (_currentUser == null) {
      debugPrint('AuthManagerMobile: User declined or sign-in returned null');
      throw const AuthCancelledException('Google sign-in was cancelled or dismissed.');
    }

    debugPrint('AuthManagerMobile: Signed in as ${_currentUser!.email}, getting auth headers...');

    try {
      final authHeaders = await _currentUser!.authHeaders;
      final authParams = await _currentUser!.authentication;
      
      try {
        final credential = fb.GoogleAuthProvider.credential(
          accessToken: authParams.accessToken,
          idToken: authParams.idToken,
        );
        await fb.FirebaseAuth.instance.signInWithCredential(credential);
        debugPrint('AuthManagerMobile: User synced to Firebase Auth');
      } catch (e) {
        debugPrint("AuthManagerMobile: Failed to sync to Firebase Auth: $e");
      }

      debugPrint('AuthManagerMobile: Got auth headers successfully');

      return auth.authenticatedClient(
        http.Client(),
        auth.AccessCredentials(
          auth.AccessToken(
            'Bearer',
            authHeaders['Authorization']!.split(' ').last,
            DateTime.now().toUtc().add(const Duration(hours: 1)),
          ),
          null,
          [CalendarApi.calendarScope],
        ),
      );
    } catch (e) {
      debugPrint('AuthManagerMobile: authHeaders failed: $e');
      // Auth headers failed — user object is stale, clear it.
      _currentUser = null;
      rethrow;
    }
  }

  @override
  Future<CalendarApi> getCalendarApi() async {
    final client = await getAuthenticatedClient();
    return CalendarApi(client);
  }

  @override
  void clearAuthCooldown() {
    _lastAuthFailure = null;
  }

  @override
  Future<void> signOut() async {
    await fb.FirebaseAuth.instance.signOut();
    await _googleSignIn.disconnect();
    _currentUser = null;
    _lastAuthFailure = null;
  }
}
