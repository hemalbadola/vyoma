import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../war_room_viewmodel.dart';
import '../../core/models/user_preferences.dart';
import '../widgets/glass_card.dart';

/// Preferences Screen for customizing Vyoma's proactive intelligence
class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  late UserPreferences _prefs;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final vm = Provider.of<WarRoomViewModel>(context, listen: false);
    _prefs = vm.sentinelService.preferences;
  }

  void _updatePrefs(UserPreferences newPrefs) {
    setState(() {
      _prefs = newPrefs;
      _hasChanges = true;
    });
  }

  Future<void> _savePrefs() async {
    final vm = Provider.of<WarRoomViewModel>(context, listen: false);
    await vm.sentinelService.updatePreferences(_prefs);
    setState(() => _hasChanges = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preferences saved ✓"), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          "PREFERENCES",
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _savePrefs,
              child: Text(
                "SAVE",
                style: GoogleFonts.outfit(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("⏰ TIME SETTINGS"),
            _buildTimeRow("Wake Time", _prefs.wakeTime, (v) => _updatePrefs(_prefs.copyWith(wakeTime: v))),
            _buildTimeRow("Sleep Time", _prefs.sleepTime, (v) => _updatePrefs(_prefs.copyWith(sleepTime: v))),
            _buildTimeRow("Daily Brief Time", _prefs.dailyBriefTime ?? _prefs.wakeTime, 
              (v) => _updatePrefs(_prefs.copyWith(dailyBriefTime: v))),
            
            const SizedBox(height: 24),
            _buildSectionHeader("🌙 QUIET HOURS"),
            _buildSwitchRow("Enable Quiet Hours", _prefs.quietHoursEnabled,
              (v) => _updatePrefs(_prefs.copyWith(quietHoursEnabled: v))),
            if (_prefs.quietHoursEnabled) ...[
              _buildTimeRow("Quiet Start", _prefs.quietStart, (v) => _updatePrefs(_prefs.copyWith(quietStart: v))),
              _buildTimeRow("Quiet End", _prefs.quietEnd, (v) => _updatePrefs(_prefs.copyWith(quietEnd: v))),
            ],
            
            const SizedBox(height: 24),
            _buildSectionHeader("☀️ DAILY BRIEF CONTENT"),
            _buildSwitchRow("Include Weather", _prefs.briefIncludeWeather,
              (v) => _updatePrefs(_prefs.copyWith(briefIncludeWeather: v))),
            _buildSwitchRow("Include Battery", _prefs.briefIncludeBattery,
              (v) => _updatePrefs(_prefs.copyWith(briefIncludeBattery: v))),
            _buildSwitchRow("Include Calendar", _prefs.briefIncludeCalendar,
              (v) => _updatePrefs(_prefs.copyWith(briefIncludeCalendar: v))),
            _buildSwitchRow("Include Goals", _prefs.briefIncludeGoals,
              (v) => _updatePrefs(_prefs.copyWith(briefIncludeGoals: v))),
            _buildSwitchRow("Include Metrics", _prefs.briefIncludeMetrics,
              (v) => _updatePrefs(_prefs.copyWith(briefIncludeMetrics: v))),
            
            const SizedBox(height: 24),
            _buildSectionHeader("🔔 PROACTIVE ALERTS"),
            _buildSwitchRow("Late for Event", _prefs.alertLateForEvent,
              (v) => _updatePrefs(_prefs.copyWith(alertLateForEvent: v))),
            _buildSwitchRow("Weather Warnings", _prefs.alertWeatherChange,
              (v) => _updatePrefs(_prefs.copyWith(alertWeatherChange: v))),
            _buildSwitchRow("Focus Drift", _prefs.alertFocusDrift,
              (v) => _updatePrefs(_prefs.copyWith(alertFocusDrift: v))),
            _buildSwitchRow("Low Battery", _prefs.alertLowBattery,
              (v) => _updatePrefs(_prefs.copyWith(alertLowBattery: v))),
            _buildSwitchRow("AWOL Return", _prefs.alertAwolReturn,
              (v) => _updatePrefs(_prefs.copyWith(alertAwolReturn: v))),
            _buildSwitchRow("End of Day Review", _prefs.alertEndOfDay,
              (v) => _updatePrefs(_prefs.copyWith(alertEndOfDay: v))),
            
            const SizedBox(height: 24),
            _buildSectionHeader("⚙️ ALERT TIMING"),
            _buildSliderRow("Event Reminder (min)", _prefs.eventReminderMinutes.toDouble(), 5, 60,
              (v) => _updatePrefs(_prefs.copyWith(eventReminderMinutes: v.round()))),
            _buildSliderRow("Travel Buffer (min)", _prefs.travelBufferMinutes.toDouble(), 0, 30,
              (v) => _updatePrefs(_prefs.copyWith(travelBufferMinutes: v.round()))),
            _buildSliderRow("Focus Drift Threshold (min)", _prefs.focusDriftThreshold.toDouble(), 2, 15,
              (v) => _updatePrefs(_prefs.copyWith(focusDriftThreshold: v.round()))),
            _buildSliderRow("Low Battery Alert (%)", _prefs.lowBatteryThreshold.toDouble(), 10, 50,
              (v) => _updatePrefs(_prefs.copyWith(lowBatteryThreshold: v.round()))),
            
            const SizedBox(height: 24),
            _buildSectionHeader("🚫 DISTRACTION APPS"),
            _buildDistractionApps(),
            
            const SizedBox(height: 100), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSwitchRow(String label, bool value, Function(bool) onChanged) {
    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.greenAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRow(String label, String value, Function(String) onChanged) {
    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14)),
          GestureDetector(
            onTap: () async {
              final parts = value.split(':');
              final initial = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
              final picked = await showTimePicker(context: context, initialTime: initial);
              if (picked != null) {
                onChanged("${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}");
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value,
                style: GoogleFonts.jetBrainsMono(color: Colors.greenAccent, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow(String label, double value, double min, double max, Function(double) onChanged) {
    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14)),
              Text(
                value.round().toString(),
                style: GoogleFonts.jetBrainsMono(color: Colors.greenAccent, fontSize: 16),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).round(),
            activeColor: Colors.greenAccent,
            inactiveColor: Colors.white24,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDistractionApps() {
    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _prefs.distractionApps.map((app) => Chip(
              label: Text(app, style: GoogleFonts.outfit(color: Colors.white, fontSize: 12)),
              backgroundColor: Colors.red.withOpacity(0.3),
              deleteIconColor: Colors.white70,
              onDeleted: () {
                final newApps = List<String>.from(_prefs.distractionApps)..remove(app);
                _updatePrefs(_prefs.copyWith(distractionApps: newApps));
              },
            )).toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            style: GoogleFonts.outfit(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Add app...",
              hintStyle: GoogleFonts.outfit(color: Colors.white38),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white24),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onSubmitted: (value) {
              if (value.isNotEmpty && !_prefs.distractionApps.contains(value)) {
                final newApps = List<String>.from(_prefs.distractionApps)..add(value);
                _updatePrefs(_prefs.copyWith(distractionApps: newApps));
              }
            },
          ),
        ],
      ),
    );
  }
}
