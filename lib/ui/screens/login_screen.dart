import 'dart:io';
import 'package:vyoma/agent_debug_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;
import 'package:googleapis/calendar/v3.dart' show CalendarApi;

import '../vyoma_theme.dart';
import '../../core/secrets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const MethodChannel _macAuthDiagChannel = MethodChannel(
    'vyoma/macos_auth_diag',
  );
  static const String _macClientIdFallback =
      '126666832937-keuqil3kqmijirdi4te3m3psfe8rt17f.apps.googleusercontent.com';

  /// Web OAuth client (matches SERVER_CLIENT_ID in macOS GoogleService-Info.plist).
  static const String _macServerClientIdFallback =
      '126666832937-louf8gbcjd5j64el9p68rrjaf9ci9aoh.apps.googleusercontent.com';

  bool _isLoading = false;
  String? _error;

  bool _looksLikeGoogleClientId(String value) {
    final candidate = value.trim();
    if (candidate.isEmpty) return false;
    return RegExp(
      r'^\d{6,}-[a-z0-9\-]+\.apps\.googleusercontent\.com$',
    ).hasMatch(candidate);
  }

  Future<Map<String, dynamic>> _collectMacSignInDiagnostics({
    required String effectiveClientId,
    required String webServerClientId,
    required String? serverClientId,
    required String? macCodesignProbe,
  }) async {
    final diagnostics = <String, dynamic>{
      'effectiveClientId': effectiveClientId,
      'webServerClientId': webServerClientId,
      'serverClientId': serverClientId,
      'effectiveClientIdLooksValid': _looksLikeGoogleClientId(
        effectiveClientId,
      ),
      'webServerClientIdLooksValid': _looksLikeGoogleClientId(
        webServerClientId,
      ),
      'serverClientIdLooksValid': serverClientId == null
          ? true
          : _looksLikeGoogleClientId(serverClientId),
      'macExecutableCodesignProbe': macCodesignProbe,
    };

    try {
      final native = await _macAuthDiagChannel.invokeMapMethod<String, dynamic>(
        'googleSignInDebugSnapshot',
      );
      diagnostics['nativeSnapshot'] = native;
    } catch (e) {
      diagnostics['nativeSnapshotError'] = e.toString();
    }

    return diagnostics;
  }

  Future<void> _logSignInFailure(
    Object error,
    StackTrace stackTrace, {
    Map<String, dynamic>? diagnostics,
  }) async {
    final data = <String, dynamic>{
      'errorType': error.runtimeType.toString(),
      'error': error.toString(),
      'stackTrace': stackTrace.toString(),
    };

    if (error is PlatformException) {
      data['platformException'] = <String, dynamic>{
        'code': error.code,
        'message': error.message,
        'details': error.details?.toString(),
      };
      final combined = '${error.code} ${error.message ?? ''}'.toLowerCase();
      data['likelyKeychainFailure'] =
          combined.contains('keychain') || combined.contains('gid');
    } else if (error is gsi.GoogleSignInException) {
      data['googleSignInException'] = <String, dynamic>{
        'code': error.code.name,
        'description': error.description,
      };
      final combined = '${error.code.name} ${error.description ?? ''}'
          .toLowerCase();
      data['likelyKeychainFailure'] =
          combined.contains('keychain') || combined.contains('gid');
    }

    if (diagnostics != null) {
      data['diagnostics'] = diagnostics;
    }

    await _debugLog(
      hypothesisId: 'H12',
      location: 'login_screen.dart:_signInWithGoogle',
      message: 'Sign-in flow exception',
      data: data,
    );
  }

  bool _isMacKeychainSignInFailure(Object error) {
    if (kIsWeb || !Platform.isMacOS) return false;
    if (error is PlatformException) {
      final code = error.code.toLowerCase();
      final message = (error.message ?? '').toLowerCase();
      final details = (error.details?.toString() ?? '').toLowerCase();
      return code.contains('sign_in_failed') &&
          (message.contains('gid') || details.contains('keychain'));
    }
    if (error is gsi.GoogleSignInException) {
      final combined = '${error.code.name} ${error.description ?? ''}'
          .toLowerCase();
      return combined.contains('keychain') || combined.contains('gid');
    }
    return false;
  }

  Future<gsi.GoogleSignInAccount?> _authenticateGoogle(
    gsi.GoogleSignIn googleSignIn, {
    List<String> scopeHint = const <String>[],
  }) async {
    try {
      return await googleSignIn.authenticate(scopeHint: scopeHint);
    } on gsi.GoogleSignInException catch (error) {
      if (error.code == gsi.GoogleSignInExceptionCode.canceled ||
          error.code == gsi.GoogleSignInExceptionCode.interrupted ||
          error.code == gsi.GoogleSignInExceptionCode.uiUnavailable) {
        return null;
      }
      rethrow;
    }
  }

  Future<gsi.GoogleSignInAccount?> _signInWithMacRecovery(
    gsi.GoogleSignIn googleSignIn, {
    Map<String, dynamic>? diagnostics,
  }) async {
    try {
      return await _authenticateGoogle(googleSignIn);
    } catch (error) {
      if (!_isMacKeychainSignInFailure(error)) rethrow;

      try {
        final cleanup = await _macAuthDiagChannel
            .invokeMapMethod<String, dynamic>('clearGoogleSignInKeychainState');
        await _debugLog(
          hypothesisId: 'H15',
          location: 'login_screen.dart:_signInWithGoogle',
          message:
              'macOS keychain cleanup attempted after keychain sign-in failure',
          data: {'cleanupResult': cleanup, 'diagnostics': diagnostics},
        );
      } catch (cleanupError) {
        await _debugLog(
          hypothesisId: 'H15',
          location: 'login_screen.dart:_signInWithGoogle',
          message: 'macOS keychain cleanup call failed',
          data: {
            'cleanupError': cleanupError.toString(),
            'diagnostics': diagnostics,
          },
        );
      }

      try {
        await googleSignIn.signOut();
      } catch (_) {}
      return await _authenticateGoogle(googleSignIn);
    }
  }

  int? _asInt(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  Future<void> _debugLog({
    required String hypothesisId,
    required String location,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    // #region agent log
    await agentDebugNdjsonLog(
      runId: 'pre-fix-3',
      hypothesisId: hypothesisId,
      location: location,
      message: message,
      data: data,
    );
    // #endregion
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    Map<String, dynamic>? diagnostics;

    try {
      final auth = FirebaseAuth.instance;
      final effectiveClientId = (!kIsWeb && Platform.isIOS)
          ? Secrets.iOSClientId
          : (!kIsWeb && Platform.isMacOS
                ? (Secrets.desktopClientId.isNotEmpty
                      ? Secrets.desktopClientId
                      : _macClientIdFallback)
                : '');
      // #region agent log
      String? macCodesignProbe;
      if (!kIsWeb && Platform.isMacOS) {
        try {
          final exe = Platform.resolvedExecutable;
          final r = await Process.run('codesign', ['-dvv', exe]);
          final blob = '${r.stdout}${r.stderr}';
          String? pick(String label) => RegExp(
            '$label=(.+)',
            multiLine: true,
          ).firstMatch(blob)?.group(1)?.trim();
          final pathParts = exe.split('/');
          final tail = pathParts.length > 4
              ? pathParts.sublist(pathParts.length - 4).join('/')
              : exe;
          final sigLine = pick('Signature');
          final sigSize = pick('Signature size');
          final authority = RegExp(
            r'^Authority=(.+)$',
            multiLine: true,
          ).firstMatch(blob)?.group(1)?.trim();
          macCodesignProbe =
              'exe:$tail|Signature=${sigLine ?? (sigSize != null ? 'size_$sigSize' : '?')}|Authority=${authority ?? '?'}|TeamIdentifier=${pick('TeamIdentifier') ?? '?'}|Identifier=${pick('Identifier') ?? '?'}|adhoc=${blob.contains('adhoc')}';
        } catch (e) {
          macCodesignProbe = 'probe_failed:${e.toString()}';
        }
      }
      // #endregion

      await _debugLog(
        hypothesisId: 'H13',
        location: 'login_screen.dart:_signInWithGoogle',
        message: 'Sign-in attempt started',
        data: {
          'platform': defaultTargetPlatform.name,
          'iosClientIdConfigured': Secrets.iOSClientId.isNotEmpty,
          'desktopClientIdConfigured': Secrets.desktopClientId.isNotEmpty,
          'webClientIdConfigured': Secrets.webClientId.isNotEmpty,
          'usingClientId': effectiveClientId.isNotEmpty,
          'usingMacFallbackClientId':
              Platform.isMacOS && Secrets.desktopClientId.isEmpty,
          'macExecutableCodesignProbe': macCodesignProbe,
          'macOsMinimalScopes': !kIsWeb && Platform.isMacOS,
        },
      );

      // macOS: sign in with default OIDC scopes only. Requesting Calendar during the
      // first GIDSignIn flow has been unreliable (native keychain errors); Calendar is
      // connected later via onboarding / calendar services.
      final loginScopes = (!kIsWeb && Platform.isMacOS)
          ? const <String>[]
          : <String>[CalendarApi.calendarScope];

      final webServerClientId = Secrets.webClientId.isNotEmpty
          ? Secrets.webClientId
          : _macServerClientIdFallback;

      final String? serverClientId;
      if (kIsWeb) {
        serverClientId = null;
      } else if (Platform.isIOS) {
        // iOS: SERVER_CLIENT_ID in GoogleService-Info.plist / optional GIDServerClientID in Info.plist.
        serverClientId = null;
      } else if (Platform.isAndroid) {
        serverClientId = Secrets.webClientId.isNotEmpty
            ? Secrets.webClientId
            : null;
      } else if (Platform.isMacOS) {
        serverClientId = webServerClientId;
      } else {
        serverClientId = null;
      }

      final googleSignIn = gsi.GoogleSignIn.instance;
      await googleSignIn.initialize(
        serverClientId: serverClientId,
        clientId: effectiveClientId.isEmpty ? null : effectiveClientId,
      );

      if (!kIsWeb && Platform.isMacOS) {
        diagnostics = await _collectMacSignInDiagnostics(
          effectiveClientId: effectiveClientId,
          webServerClientId: webServerClientId,
          serverClientId: serverClientId,
          macCodesignProbe: macCodesignProbe,
        );
        await _debugLog(
          hypothesisId: 'H14',
          location: 'login_screen.dart:_signInWithGoogle',
          message: 'macOS preflight diagnostics snapshot',
          data: diagnostics,
        );

        if (!(diagnostics['effectiveClientIdLooksValid'] as bool) ||
            !(diagnostics['webServerClientIdLooksValid'] as bool) ||
            !(diagnostics['serverClientIdLooksValid'] as bool)) {
          throw StateError(
            'OAuth client ID format check failed. Verify Web/iOS/macOS client IDs before sign-in.',
          );
        }

        final nativeSnapshot = diagnostics['nativeSnapshot'];
        if (nativeSnapshot is Map) {
          final probe = nativeSnapshot['keychainProbe'];
          if (probe is Map) {
            final addStatus = _asInt(probe['addStatus']) ?? -1;
            final readStatus = _asInt(probe['readStatus']) ?? -1;
            final payloadRoundTripMatch =
                probe['payloadRoundTripMatch'] == true;
            if (addStatus != 0 || readStatus != 0 || !payloadRoundTripMatch) {
              throw StateError(
                'Native keychain probe failed before sign-in (addStatus=$addStatus, readStatus=$readStatus, roundTrip=$payloadRoundTripMatch). Clear keychain entries and reboot once.',
              );
            }
          }
        }

        try {
          await googleSignIn.signOut();
        } catch (_) {}
      }

      final account = !kIsWeb && Platform.isMacOS
          ? await _signInWithMacRecovery(googleSignIn, diagnostics: diagnostics)
          : await _authenticateGoogle(googleSignIn, scopeHint: loginScopes);
      await _debugLog(
        hypothesisId: 'H10',
        location: 'login_screen.dart:_signInWithGoogle',
        message: 'Google sign-in returned',
        data: {'hasAccount': account != null},
      );
      if (account != null) {
        final gAuth = account.authentication;
        String? accessToken;
        if (loginScopes.isNotEmpty) {
          final authHeaders = await account.authorizationClient
              .authorizationHeaders(loginScopes, promptIfNecessary: true);
          final bearer = authHeaders?['Authorization'];
          if (bearer != null && bearer.contains(' ')) {
            accessToken = bearer.split(' ').last;
          }
        }
        await _debugLog(
          hypothesisId: 'H11',
          location: 'login_screen.dart:_signInWithGoogle',
          message: 'Google auth tokens fetched',
          data: {
            'hasAccessToken': accessToken != null,
            'hasIdToken': gAuth.idToken != null,
          },
        );
        if (gAuth.idToken == null) {
          throw StateError('Google sign-in returned no idToken.');
        }
        final credential = GoogleAuthProvider.credential(
          accessToken: accessToken,
          idToken: gAuth.idToken,
        );

        await auth.signInWithCredential(credential);
        await _debugLog(
          hypothesisId: 'H11',
          location: 'login_screen.dart:_signInWithGoogle',
          message: 'Firebase credential sign-in succeeded',
        );
        // Authentication state changes will trigger the routing gate in main.dart
      } else {
        setState(() {
          _error = "Sign in cancelled by user.";
          _isLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('LoginScreen: Google Sign-In failed: $e');
      await _logSignInFailure(e, st, diagnostics: diagnostics);
      setState(() {
        _error = (!kIsWeb && Platform.isMacOS)
            ? "Authentication failed on macOS native sign-in. Diagnostics captured."
            : "Authentication failed. Please try again.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VyomaColors.bgBase,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "VYOMA NODE",
                style: GoogleFonts.jetBrainsMono(
                  color: VyomaColors.accent,
                  fontSize: 18,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Sign in to synchronize your calendar and establish your presence.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 48),
              if (_error != null) ...[
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
                const SizedBox(height: 24),
              ],
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.g_mobiledata_rounded, size: 36),
                  label: Text(
                    "Continue with Google",
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
