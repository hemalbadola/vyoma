import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
// TODO: inject theme via BuildContext instead of direct import
import '../ui/vyoma_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class UpdateService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Checks for updates and shows a dialog if one is available.
  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      final doc = await _firestore.collection('config').doc('app_version').get();
      if (!doc.exists) return;

      final data = doc.data()!;
      final latestVersion = data['latest_version'] as String?;
      final downloadUrl = data['download_url'] as String?;
      final isMandatory = data['mandatory'] as bool? ?? false;

      if (latestVersion == null || downloadUrl == null) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (_isUpdateAvailable(currentVersion, latestVersion)) {
        if (context.mounted) {
          _showUpdateDialog(context, latestVersion, downloadUrl, isMandatory);
        }
      }
    } catch (e) {
      debugPrint("UpdateService: Error checking for updates: $e");
    }
  }

  /// Compares semantic versions like 1.0.0 and 1.0.1
  static bool _isUpdateAvailable(String current, String latest) {
    try {
      final v1 = current.split('.').map(int.parse).toList();
      final v2 = latest.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        final c1 = i < v1.length ? v1[i] : 0;
        final c2 = i < v2.length ? v2[i] : 0;
        if (c2 > c1) return true;
        if (c1 > c2) return false;
      }
    } catch (e) {
      return false; // Fallback
    }
    return false;
  }

  static void _showUpdateDialog(
    BuildContext context, 
    String latestVersion, 
    String downloadUrl, 
    bool isMandatory
  ) {
    showDialog(
      context: context,
      barrierDismissible: !isMandatory,
      builder: (context) {
        // WillPopScope equivalent for newer Flutter versions is PopScope
        return PopScope(
          canPop: !isMandatory,
          child: AlertDialog(
            backgroundColor: VyomaColors.bgDeep,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: VyomaColors.accent, width: 1),
            ),
            title: Text(
              'Update Available',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'Version $latestVersion is now available.\n\n${isMandatory ? 'This is a required update. Please install the new version to continue using Vyoma.' : 'Please install the new version for the best experience.'}',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              if (!isMandatory)
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Later', style: TextStyle(color: Colors.white54)),
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: VyomaColors.accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  final uri = Uri.parse(downloadUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: const Text('Update Now', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }
}
