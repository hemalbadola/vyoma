import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/telemetry_service.dart';
import '../../tutorial/tutorial_controller.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/glass_card.dart';

/// Preferences — display, notifications, routine.
class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  // Local-only preferences (no AI required)
  TimeOfDay _wakeTime = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _sleepTime = const TimeOfDay(hour: 23, minute: 0);
  bool _quietHoursEnabled = false;
  TimeOfDay _quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEnd = const TimeOfDay(hour: 7, minute: 0);

  Future<void> _pickTime(String label, TimeOfDay initial,
      ValueChanged<TimeOfDay> onPicked) async {
    final picked =
        await showTimePicker(context: context, initialTime: initial);
    if (picked != null) onPicked(picked);
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'PREFERENCES',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header('⏰ ROUTINE'),
            _timeRow('Wake Time', _wakeTime,
                (t) => setState(() => _wakeTime = t)),
            _timeRow('Sleep Time', _sleepTime,
                (t) => setState(() => _sleepTime = t)),

            const SizedBox(height: 24),
            _header('🌙 QUIET HOURS'),
            _switchRow('Enable Quiet Hours', _quietHoursEnabled,
                (v) => setState(() => _quietHoursEnabled = v)),
            if (_quietHoursEnabled) ...[
              _timeRow('Quiet Start', _quietStart,
                  (t) => setState(() => _quietStart = t)),
              _timeRow('Quiet End', _quietEnd,
                  (t) => setState(() => _quietEnd = t)),
            ],

            const SizedBox(height: 24),
            _header('🌐 ECOSYSTEM SYNC'),
            _buildSyncCard(),

            const SizedBox(height: 32),
            // Info — background ticks (Workmanager) are clock-driven; optional Gemini polish uses your session.
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.gold, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Vyoma can wake on a schedule for deadline nudges and short post-class debriefs. '
                      'An ongoing notification shows focus + next calendar anchor after you open chat with calendar sync.',
                      style: GoogleFonts.outfit(
                          color: Colors.white54, fontSize: 13, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            _header('🎓 ONBOARDING'),
            GlassCard(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.school_outlined, color: AppColors.gold, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Replay App Tutorial',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Walk through how Vyoma works again',
                          style: GoogleFonts.outfit(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final tutorialController = context.read<TutorialController>();
                      final navigator = Navigator.of(context);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove(TutorialController.prefKeyCompleted);
                      if (!mounted) return;
                      tutorialController.start();
                      if (navigator.canPop()) {
                        navigator.pop();
                      }
                    },
                    child: const Text(
                      'REPLAY',
                      style: TextStyle(color: AppColors.gold),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _header(String title) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          title,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      );

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) =>
      GlassCard(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14)),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.gold,
              activeTrackColor: AppColors.gold.withValues(alpha: 0.35),
            ),
          ],
        ),
      );

  Widget _timeRow(
      String label, TimeOfDay value, ValueChanged<TimeOfDay> onPicked) =>
      GlassCard(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14)),
            GestureDetector(
              onTap: () => _pickTime(label, value, onPicked),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _fmt(value),
                  style: GoogleFonts.jetBrainsMono(
                      color: AppColors.gold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildSyncCard() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: context.read<TelemetryService>().getCrossDeviceMatrix(),
      builder: (context, snapshot) {
        final devices = snapshot.data ?? [];
        
        return GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.sync, color: AppColors.gold, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Multi-Device Accountability',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'To link your laptop and phone, sign in with the SAME Google account on both. Vyoma will aggregate your focus and catch procrastination across all active screens.',
                style: GoogleFonts.outfit(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              if (devices.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 12),
                Text(
                  'SYNCED DEVICES',
                  style: GoogleFonts.outfit(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                ...devices.map((device) {
                  final isActive = device['isActive'] as bool;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      children: [
                        Icon(
                          device['platform'].toString().toLowerCase().contains('ios') || 
                          device['platform'].toString().toLowerCase().contains('android') 
                            ? Icons.phone_iphone : Icons.laptop_mac,
                          size: 14,
                          color: isActive ? AppColors.gold : Colors.white24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            device['platform'],
                            style: GoogleFonts.outfit(
                              color: isActive ? Colors.white : Colors.white38,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(color: AppColors.gold, fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }
}
