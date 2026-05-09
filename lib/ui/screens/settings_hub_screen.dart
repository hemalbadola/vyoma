import 'package:vyoma/agent_debug_log.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/user_service.dart';
import '../../core/telemetry_service.dart';
import '../../core/ai_service.dart';
import '../widgets/glass_card.dart';
import '../onboarding_screen.dart';

class SettingsHubScreen extends StatefulWidget {
  const SettingsHubScreen({super.key});

  @override
  State<SettingsHubScreen> createState() => _SettingsHubScreenState();
}

class _SettingsHubScreenState extends State<SettingsHubScreen> {
  Future<void> _debugLog({
    required String hypothesisId,
    required String location,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    // #region agent log
    await agentDebugNdjsonLog(
      runId: 'pre-fix-1',
      hypothesisId: hypothesisId,
      location: location,
      message: message,
      data: data,
    );
    // #endregion
  }

  Future<void> _resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('onboarding_complete');
    await prefs.remove('profile_setup_complete');
    await prefs.remove('tutorial_completed_v1');
    await prefs.remove('calendar_permission_granted');
    await prefs.remove('notification_permission_granted');
    await prefs.remove('social_mode');
    await _debugLog(
      hypothesisId: 'H4',
      location: 'settings_hub_screen.dart:_resetOnboarding',
      message: 'Onboarding reset keys removed',
      data: {'onboarding_complete_after': prefs.getBool('onboarding_complete')},
    );
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (route) => false,
    );
  }

  Future<void> _ensureAuth() async {
    final auth = FirebaseAuth.instance;
    await _debugLog(
      hypothesisId: 'H3',
      location: 'settings_hub_screen.dart:_ensureAuth',
      message: 'Ensure auth triggered',
      data: {'hasCurrentUser': auth.currentUser != null},
    );
    if (auth.currentUser == null) {
      try {
        await auth.signInAnonymously();
        await _debugLog(
          hypothesisId: 'H3',
          location: 'settings_hub_screen.dart:_ensureAuth',
          message: 'Anonymous sign-in success',
        );
      } catch (e) {
        await _debugLog(
          hypothesisId: 'H3',
          location: 'settings_hub_screen.dart:_ensureAuth',
          message: 'Anonymous sign-in failed',
          data: {'error': e.toString()},
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign-in unavailable on this macOS keychain session. Use Restart Onboarding.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userSvc = context.watch<UserService>();
    final profile = userSvc.profile;
    
    if (profile == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'HUB SETTINGS',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile not ready yet',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You can recover from here: sign in locally or restart onboarding from the beginning.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ElevatedButton(
                          onPressed: _ensureAuth,
                          child: const Text('Sign In (Local)'),
                        ),
                        ElevatedButton(
                          onPressed: _resetOnboarding,
                          child: const Text('Restart Onboarding'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'HUB SETTINGS',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('🛡️ PRIVACY & ACCOUNTABILITY'),
            _buildPrivacyTile(
              title: "Share Active Tasks",
              subtitle: "Allow friends to see your top 3 missions in real-time.",
              value: profile.shareTasksWithFriends,
              onChanged: (v) => userSvc.updatePrivacySetting(shareTasks: v),
            ),
            const SizedBox(height: 12),
            _buildPrivacyTile(
              title: "Ghost Mode (Online Status)",
              subtitle: "Hide your emerald pulse. Friends won't know when you are active.",
              value: profile.showOnlineStatus,
              onChanged: (v) => userSvc.updatePrivacySetting(showOnline: v),
            ),
            const SizedBox(height: 12),
            _buildPrivacyTile(
              title: "Device Shield (Telemetry)",
              subtitle: "Stop heartbeats. Vyoma won't track your cross-device sessions.",
              value: profile.enableTelemetry,
              onChanged: (v) => userSvc.updatePrivacySetting(telemetry: v),
            ),
            const SizedBox(height: 12),
            _buildPrivacyTile(
              title: "Intention Mask",
              subtitle: "Hide your daily focus tagline from the social circle.",
              value: profile.shareIntention,
              onChanged: (v) => userSvc.updatePrivacySetting(intention: v),
            ),
            
            const SizedBox(height: 32),
            _sectionHeader('🌐 YOUR ECOSYSTEM'),
            _buildEcosystemList(),

            const SizedBox(height: 32),
            _sectionHeader('🧠 AI INTEL SEGMENTS'),
            _buildAISegmentToggles(),

            const SizedBox(height: 32),
            _sectionHeader('🚪 SESSION'),
            _buildSignOutTile(),

            const SizedBox(height: 100), // Padding for scroll
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          color: Colors.white70,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildPrivacyTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF06B6D4),
          ),
        ],
      ),
    );
  }

  Widget _buildEcosystemList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: context.read<TelemetryService>().getCrossDeviceMatrix(),
      builder: (context, snapshot) {
        final devices = snapshot.data ?? [];
        if (devices.isEmpty) {
          return const GlassCard(
            padding: EdgeInsets.all(16),
            child: Text("No other devices linked yet.", style: TextStyle(color: Colors.white38, fontSize: 12)),
          );
        }

        return GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: devices.map((d) {
              final active = d['isActive'] ?? false;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Icon(
                      d['platform'].toString().toLowerCase().contains('mac') || d['platform'].toString().toLowerCase().contains('win') 
                          ? Icons.laptop : Icons.phone_iphone,
                      color: active ? const Color(0xFF06B6D4) : Colors.white24,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(d['platform'], style: TextStyle(color: active ? Colors.white : Colors.white54)),
                    ),
                    if (active)
                      const Text("ONLINE", style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildAISegmentToggles() {
    final ai = context.watch<AIService>();
    final toggles = ai.memory.getSegmentToggles();

    return GlassCard(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: toggles.entries.map((e) {
          return CheckboxListTile(
            title: Text(e.key.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
            value: e.value,
            onChanged: (v) {
              if (v != null) {
                ai.memory.toggleSegment(e.key, v);
                setState(() {});
              }
            },
            activeColor: const Color(0xFF7C3AED),
            dense: true,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSignOutTile() {
    return InkWell(
      onTap: () => FirebaseAuth.instance.signOut(),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.logout, color: Colors.redAccent, size: 20),
            const SizedBox(width: 12),
            Text("Sign Out", style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
