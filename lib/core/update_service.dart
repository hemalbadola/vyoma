import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ui/vyoma_theme.dart';
import 'config/app_config.dart';
import 'models/release_manifest.dart';

/// Checks [releases.json] on Hosting and shows an update dialog when a newer build exists.
class UpdateService {
  static const _dismissedVersionKey = 'update_dismissed_version';
  static const _lastCheckKey = 'update_last_check_ms';
  static const _checkIntervalMs = 1000 * 60 * 60 * 6; // 6 hours between background checks

  static String get _platformId {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  /// Call on app launch and when returning to foreground.
  static Future<void> checkForUpdates(
    BuildContext context, {
    bool force = false,
  }) async {
    if (kIsWeb) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!force) {
        final last = prefs.getInt(_lastCheckKey) ?? 0;
        if (DateTime.now().millisecondsSinceEpoch - last < _checkIntervalMs) {
          return;
        }
      }
      await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = installedVersionLabel(packageInfo);

      final manifest = await _fetchManifest();
      if (manifest == null) return;

      final firestoreOverride = await _fetchFirestoreOverride();
      final latestVersion = firestoreOverride?['latest_version'] as String? ?? manifest.appVersion;
      final mandatory =
          firestoreOverride?['mandatory'] as bool? ?? manifest.mandatory;
      final releaseNotes =
          firestoreOverride?['release_notes'] as String? ?? manifest.releaseNotes;

      if (!isNewerVersion(latestVersion, currentVersion)) {
        return;
      }

      if (!mandatory) {
        final dismissed = prefs.getString(_dismissedVersionKey);
        if (dismissed == latestVersion) {
          return;
        }
      }

      final platformId = _platformId;
      final platformRelease = manifest.platform(platformId);
      String? downloadUrl = firestoreOverride?['download_url'] as String?;

      if ((downloadUrl == null || downloadUrl.isEmpty) && platformRelease != null) {
        if (platformRelease.available && platformRelease.url.isNotEmpty) {
          downloadUrl = _absoluteUrl(platformRelease.url);
        }
      }

      // Always send users to the download page (latest APK link lives there).
      downloadUrl = AppConfig.updateWebsiteUrl;

      if (!context.mounted) return;
      await _showUpdateDialog(
        context,
        latestVersion: latestVersion,
        currentVersion: currentVersion,
        downloadUrl: downloadUrl,
        releaseNotes: releaseNotes,
        mandatory: mandatory,
        onLater: () => prefs.setString(_dismissedVersionKey, latestVersion),
      );
    } catch (e) {
      debugPrint('UPDATE_DEBUG: $e');
    }
  }

  static Future<ReleaseManifest?> _fetchManifest() async {
    final uri = Uri.parse('${AppConfig.releaseManifestUrl}?t=${DateTime.now().millisecondsSinceEpoch}');
    final res = await http.get(uri, headers: {'Cache-Control': 'no-cache'});
    if (res.statusCode != 200) return null;
    return ReleaseManifest.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<Map<String, dynamic>?> _fetchFirestoreOverride() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('config').doc('app_version').get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      debugPrint('UPDATE_DEBUG: Firestore override failed: $e');
      return null;
    }
  }

  static String _absoluteUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final base = Uri.parse(AppConfig.releaseManifestUrl);
    final origin = '${base.scheme}://${base.host}';
    return url.startsWith('/') ? '$origin$url' : '$origin/$url';
  }

  /// Installed label matching CI releases (`1.11.2+42`).
  static String installedVersionLabel(PackageInfo info) {
    final build = info.buildNumber.trim();
    if (build.isEmpty || build == '0') return info.version;
    return '${info.version}+$build';
  }

  /// True when [latest] is greater than [current] (semver + optional `+build`).
  static bool isNewerVersion(String latest, String current) {
    final a = _parseVersionLabel(current);
    final b = _parseVersionLabel(latest);
    final semverLen = a.semver.length > b.semver.length ? a.semver.length : b.semver.length;
    for (var i = 0; i < semverLen; i++) {
      final c1 = i < a.semver.length ? a.semver[i] : 0;
      final c2 = i < b.semver.length ? b.semver[i] : 0;
      if (c2 > c1) return true;
      if (c1 > c2) return false;
    }
    return b.build > a.build;
  }

  static ({List<int> semver, int build}) _parseVersionLabel(String raw) {
    final trimmed = raw.trim();
    final plus = trimmed.split('+');
    final semver = plus[0]
        .split('.')
        .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    final build = plus.length > 1 ? (int.tryParse(plus[1].trim()) ?? 0) : 0;
    return (semver: semver, build: build);
  }

  static Future<void> _showUpdateDialog(
    BuildContext context, {
    required String latestVersion,
    required String currentVersion,
    required String downloadUrl,
    required String releaseNotes,
    required bool mandatory,
    required VoidCallback onLater,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: !mandatory,
      builder: (dialogContext) {
        return PopScope(
          canPop: !mandatory,
          child: AlertDialog(
            backgroundColor: VyomaColors.bgDeep,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: VyomaColors.accent, width: 1),
            ),
            title: Text(
              'Update available',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Text(
                'You are on v$currentVersion. v$latestVersion is ready for ${_platformLabel()}.\n\n'
                '${releaseNotes.isNotEmpty ? releaseNotes : 'Install the latest build for fixes and new features.'}'
                '${mandatory ? '\n\nThis update is required to continue.' : ''}',
                style: const TextStyle(color: Colors.white70, height: 1.45),
              ),
            ),
            actions: [
              if (!mandatory)
                TextButton(
                  onPressed: () {
                    onLater();
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Later', style: TextStyle(color: Colors.white54)),
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: VyomaColors.accent,
                  foregroundColor: Colors.black,
                ),
                onPressed: () async {
                  final uri = Uri.parse(downloadUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Text(
                  downloadUrl.contains('vyomai.app')
                      ? 'Open vyomai.app'
                      : 'Download update',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<void> openUpdateWebsite() async {
    final uri = Uri.parse(AppConfig.updateWebsiteUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static String _platformLabel() {
    switch (_platformId) {
      case 'android':
        return 'Android';
      case 'windows':
        return 'Windows';
      case 'macos':
        return 'macOS';
      case 'ios':
        return 'iOS';
      default:
        return 'your device';
    }
  }
}
