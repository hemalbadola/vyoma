import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/glass_card.dart';

/// Simplified Preferences Screen — manages display and notification settings.
/// Proactive Sentinel patrol has been removed to eliminate background API usage.
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

            const SizedBox(height: 32),
            // Info card — sentinel removed
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Background AI patrol has been removed to conserve API quota. '
                      'Vyoma now responds only when you initiate a conversation.',
                      style: GoogleFonts.outfit(
                          color: Colors.white54, fontSize: 13, height: 1.5),
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
              activeThumbColor: const Color(0xFF10B981),
              activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.35),
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
                      color: const Color(0xFF10B981), fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      );
}
