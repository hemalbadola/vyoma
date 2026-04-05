import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/memory_service.dart';
import 'home_screen.dart';
import 'war_room_viewmodel.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ArrivalStep();
  }
}

class _OnboardingSeed {
  final String goal;
  final String wake;
  final String sleep;
  final bool guided;

  const _OnboardingSeed({
    required this.goal,
    required this.wake,
    required this.sleep,
    required this.guided,
  });

  _OnboardingSeed copyWith({
    String? goal,
    String? wake,
    String? sleep,
    bool? guided,
  }) {
    return _OnboardingSeed(
      goal: goal ?? this.goal,
      wake: wake ?? this.wake,
      sleep: sleep ?? this.sleep,
      guided: guided ?? this.guided,
    );
  }
}

class _ArrivalStep extends StatefulWidget {
  const _ArrivalStep();

  @override
  State<_ArrivalStep> createState() => _ArrivalStepState();
}

class _ArrivalStepState extends State<_ArrivalStep> {
  final TextEditingController _goalController = TextEditingController();
  bool _showPrompt = false;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _showPrompt = true);
      }
    });
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    final goal = _goalController.text.trim();
    if (goal.isEmpty) return;

    final memory = context.read<MemoryService>();
    await memory.updateProtocol(goal, 'Unclear next action');

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _OperatingWindowStep(
          seed: _OnboardingSeed(
            goal: goal,
            wake: '07:00',
            sleep: '23:00',
            guided: false,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 1300),
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: child,
                    ),
                    child: Center(
                      child: const _LogoPulse(size: 220, assetPath: 'vyoma-horizontal-lockup.svg'),
                    ),
                  ),
                  const SizedBox(height: 36),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 400),
                    opacity: _showPrompt ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: !_showPrompt,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _VyomaPrompt(
                            'Before we begin - what is one thing you actually want to get done today?',
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _goalController,
                            autofocus: true,
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                            decoration: InputDecoration(
                              hintText: 'One concrete outcome for today',
                              hintStyle: GoogleFonts.inter(color: const Color(0xFF6B7280)),
                              filled: true,
                              fillColor: const Color(0xFF111317),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF2B313B)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF2B313B)),
                              ),
                            ),
                            onSubmitted: (_) => _next(),
                          ),
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerRight,
                            child: _PrimaryButton(
                              label: 'Continue',
                              onTap: _next,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OperatingWindowStep extends StatefulWidget {
  final _OnboardingSeed seed;

  const _OperatingWindowStep({required this.seed});

  @override
  State<_OperatingWindowStep> createState() => _OperatingWindowStepState();
}

class _OperatingWindowStepState extends State<_OperatingWindowStep> {
  late TimeOfDay _wake;
  late TimeOfDay _sleep;

  @override
  void initState() {
    super.initState();
    _wake = const TimeOfDay(hour: 7, minute: 0);
    _sleep = const TimeOfDay(hour: 23, minute: 0);
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickWake() async {
    final chosen = await showTimePicker(context: context, initialTime: _wake);
    if (chosen != null) {
      setState(() => _wake = chosen);
    }
  }

  Future<void> _pickSleep() async {
    final chosen = await showTimePicker(context: context, initialTime: _sleep);
    if (chosen != null) {
      setState(() => _sleep = chosen);
    }
  }

  Future<void> _next() async {
    final memory = context.read<MemoryService>();
    await memory.updateRoutine(_fmt(_wake), _fmt(_sleep));

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FeatureRevealStep(
          seed: widget.seed.copyWith(wake: _fmt(_wake), sleep: _fmt(_sleep)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _OnboardingStepHead('Step 2 of 5'),
                  const SizedBox(height: 10),
                  const _VyomaPrompt('What time do you usually wake up and sleep?'),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: _TimeTile(label: 'Wake', value: _fmt(_wake), onTap: _pickWake),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TimeTile(label: 'Sleep', value: _fmt(_sleep), onTap: _pickSleep),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _PrimaryButton(label: 'Continue', onTap: _next),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRevealStep extends StatelessWidget {
  final _OnboardingSeed seed;

  const _FeatureRevealStep({required this.seed});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _OnboardingStepHead('Step 3 of 5'),
                  const SizedBox(height: 10),
                  const _VyomaPrompt(
                    'I can see your calendar, remember what matters, and notice when you drift. Show you around?',
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _PrimaryButton(
                          label: 'Yes',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => _GuidedDemoStep(
                                  seed: seed.copyWith(guided: true),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SecondaryButton(
                          label: 'Just let me explore',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => _HandoffStep(seed: seed.copyWith(guided: false)),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GuidedDemoStep extends StatefulWidget {
  final _OnboardingSeed seed;

  const _GuidedDemoStep({required this.seed});

  @override
  State<_GuidedDemoStep> createState() => _GuidedDemoStepState();
}

class _GuidedDemoStepState extends State<_GuidedDemoStep> {
  int _index = 0;
  final TextEditingController _scheduleController = TextEditingController();
  final TextEditingController _vaultController = TextEditingController();
  bool _isAnalyzing = false;
  List<String> _insights = [];

  @override
  void initState() {
    super.initState();
    _scheduleController.text = 'Schedule a 60-minute focused block this week for ${widget.seed.goal}.';
  }

  @override
  void dispose() {
    _scheduleController.dispose();
    _vaultController.dispose();
    super.dispose();
  }

  Future<void> _runSchedule() async {
    final text = _scheduleController.text.trim();
    if (text.isEmpty) return;
    context.read<WarRoomViewModel>().submitCommand(text);
    setState(() => _index = 1);
  }

  Future<void> _runVaultAnalyze() async {
    final text = _vaultController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isAnalyzing = true);
    try {
      final vm = context.read<WarRoomViewModel>();
      final insights = await vm.previewJournalInsights(text);
      await vm.submitJournalEntry(
        text: text,
        mood: 'focused',
        tags: const ['onboarding', 'vault'],
        acceptedInsights: insights,
      );
      if (!mounted) return;
      setState(() {
        _insights = insights;
        _index = 2;
      });
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Widget _buildStepBody() {
    if (_index == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'One - Chat',
            style: GoogleFonts.inter(color: const Color(0xFF34D399), fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          const _VyomaPrompt('Tell me something you need to schedule this week.'),
          const SizedBox(height: 14),
          TextField(
            controller: _scheduleController,
            style: GoogleFonts.inter(color: Colors.white),
            decoration: _fieldDecoration('Try a scheduling command'),
          ),
          const SizedBox(height: 12),
          _PrimaryButton(label: 'Schedule It', onTap: _runSchedule),
        ],
      );
    }

    if (_index == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Two - Vault',
            style: GoogleFonts.inter(color: const Color(0xFF34D399), fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          const _VyomaPrompt('The Vault is where you think out loud. Write one thing on your mind right now.'),
          const SizedBox(height: 14),
          TextField(
            controller: _vaultController,
            maxLines: 5,
            style: GoogleFonts.inter(color: Colors.white),
            decoration: _fieldDecoration('One honest thought is enough'),
          ),
          const SizedBox(height: 12),
          _PrimaryButton(
            label: _isAnalyzing ? 'Analyzing...' : 'Analyze Entry',
            onTap: _isAnalyzing ? null : _runVaultAnalyze,
          ),
        ],
      );
    }

    if (_index == 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Three - Intel',
            style: GoogleFonts.inter(color: const Color(0xFF34D399), fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          const _VyomaPrompt('This is where I track your patterns. It is empty now. It gets interesting over time.'),
          if (_insights.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Vault reflection captured. ${_insights.first}',
              style: GoogleFonts.inter(color: const Color(0xFFB6C2CF), fontSize: 13),
            ),
          ],
          const SizedBox(height: 14),
          _PrimaryButton(label: 'Continue', onTap: () => setState(() => _index = 3)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Four - Timetable',
          style: GoogleFonts.inter(color: const Color(0xFF34D399), fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        const _VyomaPrompt('If you are a student or have a fixed weekly schedule, add it here. I will plan around it.'),
        const SizedBox(height: 14),
        _PrimaryButton(
          label: 'Finish Demo',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => _HandoffStep(seed: widget.seed)),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _OnboardingStepHead('Step 4 of 5'),
                  const SizedBox(height: 10),
                  _buildStepBody(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HandoffStep extends StatelessWidget {
  final _OnboardingSeed seed;

  const _HandoffStep({required this.seed});

  Future<void> _complete(BuildContext context) async {
    final memory = context.read<MemoryService>();
    await memory.updateRoutine(seed.wake, seed.sleep);
    await memory.updateProtocol(seed.goal, 'Unclear next action');
    await memory.updateIdentity('User', '');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);

    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _OnboardingStepHead('Step 5 of 5'),
                  const SizedBox(height: 10),
                  const _VyomaPrompt(
                    'That is everything. I will observe quietly and speak when it matters. Your day starts now.',
                  ),
                  const SizedBox(height: 20),
                  _PrimaryButton(label: 'Start Day', onTap: () => _complete(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: disabled ? const Color(0xFF1F2937) : const Color(0xFF10B981),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: disabled ? const Color(0xFF94A3B8) : Colors.black,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SecondaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF111317),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2B313B)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(0xFFE5E7EB),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _TimeTile({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF111317),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2B313B)),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(color: const Color(0xFF9CA3AF), fontSize: 12),
            ),
            const Spacer(),
            Text(
              value,
              style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.inter(color: const Color(0xFF6B7280)),
    filled: true,
    fillColor: const Color(0xFF111317),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF2B313B)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF2B313B)),
    ),
  );
}

class _OnboardingStepHead extends StatelessWidget {
  final String text;

  const _OnboardingStepHead(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _VyomaLogo(size: 18),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.jetBrainsMono(
            color: const Color(0xFF6B7280),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _VyomaPrompt extends StatelessWidget {
  final String text;

  const _VyomaPrompt(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _VyomaLogo(size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _LogoPulse extends StatefulWidget {
  final double size;
  final String assetPath;

  const _LogoPulse({required this.size, this.assetPath = 'vyoma-icon-192.svg'});

  @override
  State<_LogoPulse> createState() => _LogoPulseState();
}

class _LogoPulseState extends State<_LogoPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: _VyomaLogo(size: widget.size, assetPath: widget.assetPath),
    );
  }
}

class _VyomaLogo extends StatelessWidget {
  final double size;
  final String assetPath;

  const _VyomaLogo({required this.size, this.assetPath = 'vyoma-icon-192.svg'});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
