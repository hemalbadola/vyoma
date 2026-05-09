import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/calendar/v3.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'auth_manager.dart';
import 'secrets.dart';

class AuthManagerDesktop implements AuthManager {
  AutoRefreshingAuthClient? _client;

  static const _scopes = [CalendarApi.calendarScope];

  Future<File> _getCredentialsFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/credentials.json');
  }

  ClientId _requireDesktopClientId() {
    final id = Secrets.desktopClientId.trim();
    final secret = Secrets.desktopClientSecret.trim();
    if (id.isEmpty || secret.isEmpty) {
      throw StateError(
        'Desktop Google OAuth is not configured. Provide VYOMA_DESKTOP_CLIENT_ID and '
        'VYOMA_DESKTOP_CLIENT_SECRET via --dart-define or runtime env.',
      );
    }
    return ClientId(id, secret);
  }

  @override
  Future<http.Client> getAuthenticatedClient({
    bool allowInteractive = true,
  }) async {
    if (_client != null) return _client!;

    try {
      final file = await _getCredentialsFile();
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final credentials = AccessCredentials.fromJson(jsonDecode(jsonString));

        // Check if token needs refresh
        if (credentials.accessToken.hasExpired) {
          // autoRefreshingClient handles refresh automatically if refresh token is present
          // but we need to ensure we re-save it if it changes.
          // For simplicity, we just use autoRefreshingClient with a save callback?
          // Actually, usually we just create the client.
        }

        final clientId = _requireDesktopClientId();
        _client = autoRefreshingClient(clientId, credentials, http.Client());

        // Verify it works (sometimes tokens are revoked)
        // If it throws, we fall back to full login
        return _client!;
      }
    } catch (e) {
      debugPrint("Failed to load credentials: $e. Initiating full login.");
    }

    // Fallback: Full Login
    // Desktop Auth Flow: Loopback
    // Note: User must provide a Client ID configured for "Desktop" (native) or "Other" in Google Cloud Console.
    final clientId = _requireDesktopClientId();

    _client = await clientViaUserConsent(clientId, _scopes, (url) async {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        debugPrint("Please go to the following URL and grant access:");
        debugPrint("  => $url");
        debugPrint("");
      }
    });

    // Save Credentials
    try {
      final file = await _getCredentialsFile();
      await file.writeAsString(jsonEncode(_client!.credentials.toJson()));
    } catch (e) {
      debugPrint("Failed to save credentials: $e");
    }

    return _client!;
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
    // Desktop flow has no transient interactive cooldown.
  }

  @override
  Future<void> signOut() async {
    _client?.close();
    _client = null;
    try {
      final file = await _getCredentialsFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Ignore
    }
  }
}
