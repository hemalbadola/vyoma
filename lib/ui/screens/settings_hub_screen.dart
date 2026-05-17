import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/auth_manager.dart';
import '../../core/user_service.dart';
import '../../core/telemetry_service.dart';
import '../../core/ai_service.dart';
import '../../core/calendar_service.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../onboarding_screen.dart';
import '../../features/anti_goals/presentation/screens/anti_goals_screen.dart';
import '../../features/dharma_map/presentation/screens/dharma_map_screen.dart';
import 'subscription_screen.dart';

class SettingsHubScreen extends StatefulWidget {
  const SettingsHubScreen({super.key});

  @override
  State<SettingsHubScreen> createState() => _SettingsHubScreenState();
}

class _SettingsHubScreenState extends State<SettingsHubScreen> {
  Future<void> _resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('onboarding_complete');
    await prefs.remove('profile_setup_complete');
    await prefs.remove('tutorial_completed_v1');
    await prefs.remove('calendar_permission_granted');
    await prefs.remove('notification_permission_granted');
    await prefs.remove('social_mode');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (route) => false,
    );
  }

  Future<void> _ensureAuth() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      try {
        await auth.signInAnonymously();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign-in unavailable on this macOS keychain session. Use Restart Onboarding.'),
          ),
        );
      }
    }
  }

  Future<void> _reconnectGoogleCalendar() async {
    final calendarService = context.read<CalendarService>();
    try {
      calendarService.clearInitCooldown();
      await calendarService.syncEvents(maxResults: 1);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Calendar connected.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Calendar connection failed: $e')),
      );
    }
  }

  /// Full sign-out: calendar/Google session via [AuthManager], then Firebase.
  /// Uses [GlassCard.onTap] for the tile — wrapping GlassCard in InkWell breaks
  /// taps because GlassCard's inner GestureDetector wins without invoking Firebase.
  Future<void> _performSignOut() async {
    final authManager = context.read<AuthManager>();
    try {
      await authManager.signOut();
    } catch (e) {
      debugPrint('SETTINGS_DEBUG: AuthManager.signOut failed: $e');
    }
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('SETTINGS_DEBUG: FirebaseAuth.signOut failed: $e');
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
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
                    Text(
                      'Sign In (Local) creates an anonymous Firebase session only—it does not attach Google Calendar. '
                      'After signing in, use Reconnect Google Calendar, or use Restart Onboarding for a full setup.',
                      style: GoogleFonts.outfit(
                        color: Colors.white60,
                        fontSize: 13,
                        height: 1.45,
                      ),
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
                          onPressed: _reconnectGoogleCalendar,
                          child: const Text('Reconnect Google Calendar'),
                        ),
                        ElevatedButton(
                          onPressed: _resetOnboarding,
                          child: const Text('Restart Onboarding'),
                        ),
                        TextButton(
                          onPressed: _performSignOut,
                          child: const Text(
                            'Sign out',
                            style: TextStyle(color: Colors.white54),
                          ),
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
            _sectionHeader('✦ SUBSCRIPTION'),
            GlassCard(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                );
              },
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.subscriptionPlan != null
                              ? 'Plan: ${profile.subscriptionPlan}'
                              : 'Upgrade Vyoma',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          profile.subscriptionExpiresAt != null
                              ? 'Renews / expires ${profile.subscriptionExpiresAt}'
                              : 'Weekly, monthly & semester — same as the website.',
                          style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white38),
                ],
              ),
            ),
            const SizedBox(height: 24),
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
            _sectionHeader('PRACTICE'),
            _buildNavTile(
              title: 'Dharma Map',
              subtitle: 'three-month chapters of who you are becoming.',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DharmaMapScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _buildNavTile(
              title: 'Anti-Goals',
              subtitle: 'name what you refuse to become.',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AntiGoalsScreen()),
              ),
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

  Widget _buildNavTile({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            color: AppColors.gold,
            size: 14,
          ),
        ],
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
            activeThumbColor: AppColors.gold,
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
                      color: active ? AppColors.gold : Colors.white24,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(d['platform'], style: TextStyle(color: active ? Colors.white : Colors.white54)),
                    ),
                    if (active)
                      Text("ONLINE", style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold)),
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
            title: Text(
              e.key.toUpperCase(),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            value: e.value,
            onChanged: (v) async {
              if (v == null) return;
              await ai.memory.toggleSegment(e.key, v);
              if (mounted) setState(() {});
            },
            checkColor: AppColors.background,
            fillColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.gold;
              }
              return Colors.transparent;
            }),
            side: const BorderSide(color: AppColors.goldDim),
            dense: true,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSignOutTile() {
    return GlassCard(
      variant: GlassVariant.danger,
      padding: const EdgeInsets.all(16),
      onTap: _performSignOut,
      child: Row(
        children: [
          Icon(Icons.logout_rounded, color: AppColors.errorColor, size: 20),
          const SizedBox(width: 12),
          Text(
            'Sign Out',
            style: GoogleFonts.outfit(
              color: AppColors.errorColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
