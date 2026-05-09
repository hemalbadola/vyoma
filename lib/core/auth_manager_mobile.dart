import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
  final gsi.GoogleSignIn _googleSignIn = gsi.GoogleSignIn.instance;
  bool _googleSignInInitialized = false;

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
  Future<http.Client> getAuthenticatedClient({
    bool allowInteractive = true,
  }) async {
    // If an auth attempt is already running, piggyback on it.
    if (_authInFlight != null) {
      return _authInFlight!.future;
    }

    final completer = Completer<http.Client>();
    _authInFlight = completer;
    final canPromptUser = allowInteractive && !_isInCooldown;

    try {
      final client = await _doAuthenticate(allowInteractive: canPromptUser);
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

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;
    await _googleSignIn.initialize(
      clientId: Platform.isIOS ? _iosClientId : null,
      serverClientId: Platform.isAndroid ? _androidServerClientId : null,
    );
    _googleSignInInitialized = true;
  }

  bool _isDeveloperError(gsi.GoogleSignInException e) {
    if (e.code == gsi.GoogleSignInExceptionCode.clientConfigurationError ||
        e.code == gsi.GoogleSignInExceptionCode.providerConfigurationError) {
      return true;
    }
    final details = (e.description ?? '').toLowerCase();
    return details.contains('developer_error') ||
        details.contains('configuration');
  }

  Exception _mapGoogleSignInException(gsi.GoogleSignInException e) {
    final details = (e.description ?? '').toLowerCase();

    if (e.code == gsi.GoogleSignInExceptionCode.canceled ||
        e.code == gsi.GoogleSignInExceptionCode.interrupted ||
        e.code == gsi.GoogleSignInExceptionCode.uiUnavailable) {
      return AuthCancelledException('Google sign-in was cancelled.');
    }

    if (_isDeveloperError(e)) {
      return AuthConfigurationException(
        'Google sign-in failed (${e.code.name}): ${e.description ?? "Unknown configuration issue"}. '
        'Verify Android OAuth package com.vyoma.app with correct SHA-1/SHA-256 and set VYOMA_WEB_CLIENT_ID to your Web OAuth client ID.',
      );
    }

    if (details.contains('network') || details.contains('timeout')) {
      return Exception(
        'Google sign-in failed due to connectivity issues. Please retry.',
      );
    }

    return Exception(
      'Google sign-in failed (${e.code.name}): ${e.description ?? "Unknown error"}',
    );
  }

  Future<gsi.GoogleSignInAccount?> _runSignInAttempt({
    required bool allowInteractive,
  }) async {
    await _ensureGoogleSignInInitialized();

    final lightweightAttempt = _googleSignIn.attemptLightweightAuthentication();
    var user = lightweightAttempt == null ? null : await lightweightAttempt;
    debugPrint('AuthManagerMobile: signInSilently => ${user?.email ?? "null"}');

    if (user == null) {
      if (!allowInteractive) {
        throw AuthCooldownException(
          _authCooldownRemaining ?? const Duration(seconds: 30),
        );
      }
      user = await _googleSignIn.authenticate(
        scopeHint: const [CalendarApi.calendarScope],
      );
      debugPrint('AuthManagerMobile: signIn => ${user.email}');
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
      signedInUser = await _runSignInAttempt(
        allowInteractive: allowInteractive,
      );
    } on gsi.GoogleSignInException catch (e) {
      debugPrint(
        'AuthManagerMobile: GoogleSignInException(primary): ${e.code.name} - ${e.description}',
      );
      throw _mapGoogleSignInException(e);
    }

    _currentUser = signedInUser;

    if (_currentUser == null) {
      debugPrint('AuthManagerMobile: User declined or sign-in returned null');
      throw const AuthCancelledException(
        'Google sign-in was cancelled or dismissed.',
      );
    }

    debugPrint(
      'AuthManagerMobile: Signed in as ${_currentUser!.email}, getting auth headers...',
    );

    try {
      var authHeaders = await _currentUser!.authorizationClient
          .authorizationHeaders(const [
            CalendarApi.calendarScope,
          ], promptIfNecessary: false);
      final authParams = _currentUser!.authentication;
      var bearer = authHeaders?['Authorization'];

      if ((bearer == null || !bearer.contains(' ')) && allowInteractive) {
        await _currentUser!.authorizationClient.authorizeScopes(const [
          CalendarApi.calendarScope,
        ]);
        authHeaders = await _currentUser!.authorizationClient
            .authorizationHeaders(const [
              CalendarApi.calendarScope,
            ], promptIfNecessary: false);
        bearer = authHeaders?['Authorization'];
      }

      if (bearer == null || !bearer.contains(' ')) {
        throw const AuthCooldownException(Duration(seconds: 30));
      }
      final accessToken = bearer.split(' ').last;
      return _buildAuthenticatedCalendarClient(
        accessToken: accessToken,
        idToken: authParams.idToken,
      );
    } on gsi.GoogleSignInException catch (e) {
      debugPrint('AuthManagerMobile: authHeaders google sign-in failure: $e');
      _currentUser = null;
      throw _mapGoogleSignInException(e);
    } catch (e) {
      debugPrint('AuthManagerMobile: authHeaders failed: $e');
      // Auth headers failed — user object is stale, clear it.
      _currentUser = null;
      rethrow;
    }
  }

  Future<http.Client> _buildAuthenticatedCalendarClient({
    required String accessToken,
    required String? idToken,
  }) async {
    try {
      final credential = fb.GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
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
          accessToken,
          DateTime.now().toUtc().add(const Duration(hours: 1)),
        ),
        null,
        [CalendarApi.calendarScope],
      ),
    );
  }

  @override
  Future<CalendarApi> getCalendarApi({bool allowInteractive = true}) async {
    final client = await getAuthenticatedClient(
      allowInteractive: allowInteractive,
    );
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
