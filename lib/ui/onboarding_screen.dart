import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vyoma/agent_debug_log.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/memory_service.dart';
import '../core/permission_manager.dart';
import '../core/calendar_service.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/vy_logo.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _OnboardingFlow();
  }
}

class _OnboardingSeed {
  final String name;
  final String category;
  final String year;
  final String field;
  final List<String> subjects;
  final String wake;
  final String sleep;
  final String goal;
  final bool calendarGranted;
  final bool notificationGranted;
  final String socialMode;

  const _OnboardingSeed({
    required this.name,
    required this.category,
    required this.year,
    required this.field,
    required this.subjects,
    required this.wake,
    required this.sleep,
    required this.goal,
    required this.calendarGranted,
    required this.notificationGranted,
    required this.socialMode,
  });

  factory _OnboardingSeed.empty() {
    return const _OnboardingSeed(
      name: 'You',
      category: 'other',
      year: '',
      field: '',
      subjects: [],
      wake: '07:00',
      sleep: '23:00',
      goal: 'No mission set',
      calendarGranted: false,
      notificationGranted: false,
      socialMode: 'solo',
    );
  }

  _OnboardingSeed copyWith({
    String? name,
    String? category,
    String? year,
    String? field,
    List<String>? subjects,
    String? wake,
    String? sleep,
    String? goal,
    bool? calendarGranted,
    bool? notificationGranted,
    String? socialMode,
  }) {
    return _OnboardingSeed(
      name: name ?? this.name,
      category: category ?? this.category,
      year: year ?? this.year,
      field: field ?? this.field,
      subjects: subjects ?? this.subjects,
      wake: wake ?? this.wake,
      sleep: sleep ?? this.sleep,
      goal: goal ?? this.goal,
      calendarGranted: calendarGranted ?? this.calendarGranted,
      notificationGranted: notificationGranted ?? this.notificationGranted,
      socialMode: socialMode ?? this.socialMode,
    );
  }
}

class _OnboardingFlow extends StatefulWidget {
  const _OnboardingFlow();

  @override
  State<_OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<_OnboardingFlow> {
  int _step = 0;
  _OnboardingSeed _seed = _OnboardingSeed.empty();

  void _next(_OnboardingSeed seed) {
    setState(() {
      _seed = seed;
      _step += 1;
    });
  }

  Future<void> _finish() async {
    final memory = context.read<MemoryService>();
    await memory.updateIdentity(_seed.name, '${_seed.category} ${_seed.year} ${_seed.field}'.trim());
    await memory.updateSubjects(_seed.subjects);
    await memory.updateRoutine(_seed.wake, _seed.sleep);
    await memory.updateProtocol(_seed.goal, 'Not started');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    await prefs.setBool('profile_setup_complete', true);
    await prefs.setBool('calendar_permission_granted', _seed.calendarGranted);
    await prefs.setBool('notification_permission_granted', _seed.notificationGranted);
    await prefs.setString('social_mode', _seed.socialMode);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case 0:
        return _ArrivalStep(onDone: () => _next(_seed));
      case 1:
        return _IdentityStep(seed: _seed, onNext: _next, onSkip: () => _next(_seed));
      case 2:
        return _ContextStep(seed: _seed, onNext: _next, onSkip: () => _next(_seed));
      case 3:
        return _SubjectsStep(seed: _seed, onNext: _next, onSkip: () => _next(_seed));
      case 4:
        return _WindowStep(seed: _seed, onNext: _next, onSkip: () => _next(_seed));
      case 5:
        return _MissionStep(seed: _seed, onNext: _next, onSkip: () => _next(_seed));
      case 6:
        return _PermissionStep(seed: _seed, onNext: _next, onSkip: () => _next(_seed));
      case 7:
        return _SocialStep(seed: _seed, onNext: _next);
      default:
        return _HandoffStep(seed: _seed, onBegin: _finish, onSkipTutorial: _finish);
    }
  }
}

class _ArrivalStep extends StatefulWidget {
  const _ArrivalStep({required this.onDone});

  final VoidCallback onDone;

  @override
  State<_ArrivalStep> createState() => _ArrivalStepState();
}

class _ArrivalStepState extends State<_ArrivalStep> {
  bool _showLine = false;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _showLine = true);
    });
    Timer(const Duration(milliseconds: 3500), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _LogoPulse(size: 220),
            const SizedBox(height: 24),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 350),
              opacity: _showLine ? 1 : 0,
              child: Text(
                'Your cognitive operator is ready.',
                style: GoogleFonts.inter(color: const Color(0xFFB6C2CF), fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdentityStep extends StatefulWidget {
  const _IdentityStep({required this.seed, required this.onNext, required this.onSkip});
  final _OnboardingSeed seed;
  final ValueChanged<_OnboardingSeed> onNext;
  final VoidCallback onSkip;

  @override
  State<_IdentityStep> createState() => _IdentityStepState();
}

class _IdentityStepState extends State<_IdentityStep> {
  final _name = TextEditingController();
  String? _category;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      title: 'Step 1 of 8',
      prompt: "Let's start with basics. What should I call you?",
      body: [
        TextField(controller: _name, style: GoogleFonts.inter(color: Colors.white), decoration: _fieldDecoration('Your first name')),
        const SizedBox(height: 14),
        Text('And what are you?', style: GoogleFonts.inter(color: const Color(0xFF9CA3AF))),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            _ChoiceChip(label: 'Student', selected: _category == 'student', onTap: () => setState(() => _category = 'student')),
            _ChoiceChip(label: 'Professional', selected: _category == 'professional', onTap: () => setState(() => _category = 'professional')),
            _ChoiceChip(label: 'Something else', selected: _category == 'other', onTap: () => setState(() => _category = 'other')),
          ],
        ),
      ],
      onNext: () {
        widget.onNext(widget.seed.copyWith(
          name: _name.text.trim().isEmpty ? 'You' : _name.text.trim(),
          category: _category ?? 'other',
        ));
      },
      onSkip: widget.onSkip,
    );
  }
}

class _ContextStep extends StatefulWidget {
  const _ContextStep({required this.seed, required this.onNext, required this.onSkip});
  final _OnboardingSeed seed;
  final ValueChanged<_OnboardingSeed> onNext;
  final VoidCallback onSkip;

  @override
  State<_ContextStep> createState() => _ContextStepState();
}

class _ContextStepState extends State<_ContextStep> {
  final _first = TextEditingController();
  final _second = TextEditingController();

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.seed.category;
    final q1 = cat == 'student'
        ? 'Which year are you in?'
        : cat == 'professional'
            ? "What's your role?"
            : 'What does your day mostly revolve around?';
    final q2 = cat == 'student' ? 'What are you studying?' : 'What industry or domain?';
    return _StepShell(
      title: 'Step 2 of 8',
      prompt: '$q1 ${widget.seed.name}',
      body: [
        TextField(controller: _first, style: GoogleFonts.inter(color: Colors.white), decoration: _fieldDecoration('Type here')),
        const SizedBox(height: 14),
        if (cat != 'other') ...[
          Text(q2, style: GoogleFonts.inter(color: const Color(0xFF9CA3AF))),
          const SizedBox(height: 8),
          TextField(controller: _second, style: GoogleFonts.inter(color: Colors.white), decoration: _fieldDecoration('Type here')),
        ],
      ],
      onNext: () => widget.onNext(widget.seed.copyWith(
        year: _first.text.trim(),
        field: cat == 'other' ? _first.text.trim() : _second.text.trim(),
      )),
      onSkip: widget.onSkip,
    );
  }
}

class _SubjectsStep extends StatefulWidget {
  const _SubjectsStep({required this.seed, required this.onNext, required this.onSkip});
  final _OnboardingSeed seed;
  final ValueChanged<_OnboardingSeed> onNext;
  final VoidCallback onSkip;

  @override
  State<_SubjectsStep> createState() => _SubjectsStepState();
}

class _SubjectsStepState extends State<_SubjectsStep> {
  final _controller = TextEditingController();
  final List<String> _subjects = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addSubject(String value) {
    final t = value.trim();
    if (t.isEmpty || _subjects.length >= 3 || _subjects.contains(t)) return;
    setState(() {
      _subjects.add(t);
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      title: 'Step 3 of 8',
      prompt: 'What are 2-3 things you most want to stay on top of?',
      body: [
        TextField(
          controller: _controller,
          style: GoogleFonts.inter(color: Colors.white),
          decoration: _fieldDecoration('Add subject and press enter'),
          onSubmitted: _addSubject,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _subjects
              .map((s) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111317),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF2B313B)),
                    ),
                    child: Text(s, style: GoogleFonts.inter(color: Colors.white)),
                  ))
              .toList(),
        ),
      ],
      onNext: () => widget.onNext(widget.seed.copyWith(subjects: _subjects)),
      onSkip: widget.onSkip,
    );
  }
}

class _WindowStep extends StatefulWidget {
  const _WindowStep({required this.seed, required this.onNext, required this.onSkip});
  final _OnboardingSeed seed;
  final ValueChanged<_OnboardingSeed> onNext;
  final VoidCallback onSkip;

  @override
  State<_WindowStep> createState() => _WindowStepState();
}

class _WindowStepState extends State<_WindowStep> {
  TimeOfDay wake = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay sleep = const TimeOfDay(hour: 23, minute: 0);

  String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      title: 'Step 4 of 8',
      prompt: "When are you active? I'll only ping inside this window.",
      body: [
        Row(
          children: [
            Expanded(child: _TimeTile(label: 'Wake', value: _fmt(wake), onTap: () async {
              final chosen = await showTimePicker(context: context, initialTime: wake);
              if (chosen != null) setState(() => wake = chosen);
            })),
            const SizedBox(width: 10),
            Expanded(child: _TimeTile(label: 'Sleep', value: _fmt(sleep), onTap: () async {
              final chosen = await showTimePicker(context: context, initialTime: sleep);
              if (chosen != null) setState(() => sleep = chosen);
            })),
          ],
        ),
      ],
      onNext: () => widget.onNext(widget.seed.copyWith(wake: _fmt(wake), sleep: _fmt(sleep))),
      onSkip: widget.onSkip,
    );
  }
}

class _MissionStep extends StatefulWidget {
  const _MissionStep({required this.seed, required this.onNext, required this.onSkip});
  final _OnboardingSeed seed;
  final ValueChanged<_OnboardingSeed> onNext;
  final VoidCallback onSkip;

  @override
  State<_MissionStep> createState() => _MissionStepState();
}

class _MissionStepState extends State<_MissionStep> {
  final _goal = TextEditingController();

  @override
  void dispose() {
    _goal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      title: 'Step 5 of 8',
      prompt: "What's one thing you want to finish today, ${widget.seed.name}?",
      body: [
        TextField(controller: _goal, style: GoogleFonts.inter(color: Colors.white), decoration: _fieldDecoration('One concrete outcome')),
      ],
      onNext: () => widget.onNext(widget.seed.copyWith(goal: _goal.text.trim().isEmpty ? 'No mission set' : _goal.text.trim())),
      onSkip: widget.onSkip,
    );
  }
}

class _PermissionStep extends StatefulWidget {
  const _PermissionStep({required this.seed, required this.onNext, required this.onSkip});
  final _OnboardingSeed seed;
  final ValueChanged<_OnboardingSeed> onNext;
  final VoidCallback onSkip;

  @override
  State<_PermissionStep> createState() => _PermissionStepState();
}

class _PermissionStepState extends State<_PermissionStep> {
  bool calendar = false;
  bool notifications = false;

  Future<void> _debugLog({
    required String hypothesisId,
    required String location,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    // #region agent log
    await agentDebugNdjsonLog(
      runId: 'pre-fix-2',
      hypothesisId: hypothesisId,
      location: location,
      message: message,
      data: data,
    );
    // #endregion
  }

  @override
  void initState() {
    super.initState();
    calendar = widget.seed.calendarGranted;
    notifications = widget.seed.notificationGranted;
  }

  Future<void> _requestNotifications() async {
    await _debugLog(
      hypothesisId: 'H7',
      location: 'onboarding_screen.dart:_requestNotifications',
      message: 'Notification permission tap',
      data: {'platform': defaultTargetPlatform.name},
    );
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux) {
      setState(() => notifications = true);
      return;
    }
    notifications = await PermissionManager.hasNotificationPermission();
    setState(() {});
  }

  Future<void> _requestCalendar() async {
    final calendarService = context.read<CalendarService>();
    await _debugLog(
      hypothesisId: 'H6',
      location: 'onboarding_screen.dart:_requestCalendar',
      message: 'Calendar permission tap',
      data: {'behavior': 'calendar_oauth_attempt', 'calendarBefore': calendar},
    );
    try {
      calendarService.clearInitCooldown();
      await calendarService.syncEvents(maxResults: 1);
      setState(() => calendar = true);
      await _debugLog(
        hypothesisId: 'H6',
        location: 'onboarding_screen.dart:_requestCalendar',
        message: 'Calendar oauth success',
        data: {'calendarAfter': calendar},
      );
    } catch (e) {
      setState(() => calendar = false);
      await _debugLog(
        hypothesisId: 'H6',
        location: 'onboarding_screen.dart:_requestCalendar',
        message: 'Calendar oauth failed',
        data: {'error': e.toString()},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Calendar connection failed: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      title: 'Step 6 of 8',
      prompt: 'Permissions. You can skip and connect later.',
      body: [
        _PermissionCard(
          title: 'Calendar Access',
          description: 'Vyoma reads events to plan around them.',
          granted: calendar,
          action: 'Connect Calendar',
          onTap: _requestCalendar,
        ),
        const SizedBox(height: 12),
        _PermissionCard(
          title: 'Focus Reminders',
          description: 'Vyoma checks in while you work.',
          granted: notifications,
          action: 'Allow Notifications',
          onTap: _requestNotifications,
        ),
      ],
      onNext: () => widget.onNext(widget.seed.copyWith(calendarGranted: calendar, notificationGranted: notifications)),
      onSkip: widget.onSkip,
    );
  }
}

class _SocialStep extends StatelessWidget {
  const _SocialStep({required this.seed, required this.onNext});
  final _OnboardingSeed seed;
  final ValueChanged<_OnboardingSeed> onNext;

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      title: 'Step 7 of 8',
      prompt: 'Are you doing this with anyone?',
      body: [
        _ChoiceChip(label: 'Invite a friend', selected: seed.socialMode == 'inviting', onTap: () => onNext(seed.copyWith(socialMode: 'inviting'))),
        const SizedBox(height: 8),
        _ChoiceChip(label: 'Find by username', selected: seed.socialMode == 'searching', onTap: () => onNext(seed.copyWith(socialMode: 'searching'))),
        const SizedBox(height: 8),
        _ChoiceChip(label: 'Just me for now', selected: seed.socialMode == 'solo', onTap: () => onNext(seed.copyWith(socialMode: 'solo'))),
      ],
      onNext: () => onNext(seed),
      onSkip: null,
    );
  }
}

class _HandoffStep extends StatelessWidget {
  const _HandoffStep({required this.seed, required this.onBegin, required this.onSkipTutorial});
  final _OnboardingSeed seed;
  final Future<void> Function() onBegin;
  final Future<void> Function() onSkipTutorial;

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      title: 'Step 8 of 8',
      prompt: "Here's your profile, ${seed.name}.",
      body: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF111317),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2B313B)),
          ),
          child: Text(
            'IDENTITY  ${seed.category} ${seed.year} ${seed.field}\n'
            'SUBJECTS  ${seed.subjects.join(', ')}\n'
            'ACTIVE    ${seed.wake} -> ${seed.sleep}\n'
            'MISSION   ${seed.goal}\n'
            'SOCIAL    ${seed.socialMode}',
            style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 12, height: 1.5),
          ),
        ),
      ],
      onNext: onBegin,
      nextLabel: 'Begin',
      onSkip: onSkipTutorial,
      skipLabel: 'Skip tutorial',
    );
  }
}

class _StepShell extends StatelessWidget {
  const _StepShell({
    required this.title,
    required this.prompt,
    required this.body,
    required this.onNext,
    this.onSkip,
    this.nextLabel = 'Continue',
    this.skipLabel = 'Skip',
  });

  final String title;
  final String prompt;
  final List<Widget> body;
  final FutureOr<void> Function() onNext;
  final FutureOr<void> Function()? onSkip;
  final String nextLabel;
  final String skipLabel;

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
                  _OnboardingStepHead(title),
                  const SizedBox(height: 10),
                  _VyomaPrompt(prompt),
                  const SizedBox(height: 16),
                  ...body,
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (onSkip != null) _SecondaryButton(label: skipLabel, onTap: () => onSkip!()),
                      const Spacer(),
                      _PrimaryButton(label: nextLabel, onTap: () => onNext()),
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

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.title,
    required this.description,
    required this.granted,
    required this.action,
    required this.onTap,
  });
  final String title;
  final String description;
  final bool granted;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111317),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2B313B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(description, style: GoogleFonts.inter(color: const Color(0xFF9CA3AF), fontSize: 13)),
          const SizedBox(height: 10),
          _PrimaryButton(label: granted ? 'Granted' : action, onTap: onTap),
        ],
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold : AppColors.surface1,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(label, style: GoogleFonts.inter(color: selected ? AppColors.background : AppColors.textPrimary)),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.gold,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: AppColors.background,
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
            Text(label, style: GoogleFonts.inter(color: const Color(0xFF9CA3AF), fontSize: 12)),
            const Spacer(),
            Text(value, style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
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

  const _LogoPulse({required this.size});

  @override
  State<_LogoPulse> createState() => _LogoPulseState();
}

class _LogoPulseState extends State<_LogoPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: _VyomaLogo(size: widget.size),
    );
  }
}

class _VyomaLogo extends StatelessWidget {
  final double size;

  const _VyomaLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return VyMark(size: size);
  }
}
