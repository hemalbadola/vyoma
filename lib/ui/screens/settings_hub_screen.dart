import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/user_service.dart';
import '../../core/telemetry_service.dart';
import '../../core/ai_service.dart';
import '../widgets/glass_card.dart';

class SettingsHubScreen extends StatefulWidget {
  const SettingsHubScreen({super.key});

  @override
  State<SettingsHubScreen> createState() => _SettingsHubScreenState();
}

class _SettingsHubScreenState extends State<SettingsHubScreen> {
  @override
  Widget build(BuildContext context) {
    final userSvc = context.watch<UserService>();
    final profile = userSvc.profile;
    
    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
            activeColor: const Color(0xFF06B6D4),
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
