// ─────────────────────────────────────────────────────────────────────────────
// tutorial_overlay.dart  —  Vyoma Story-Mode Tutorial System
//
// HOW IT WORKS:
//   TutorialController is provided via InheritedWidget / provider above
//   HomeScreen. Any widget that wants to be spotlighted calls:
//
//     TutorialTarget(
//       stepId: TutorialStep.warRoom,
//       child: YourWidget(),
//     )
//
//   When a step is active, TutorialTarget registers its GlobalKey with the
//   controller. The overlay reads that key to compute the RenderBox bounds
//   and paints the spotlight hole exactly over it.
//
// ANIMATION CONTRACTS (frame-by-frame):
//
//  [Step enter]
//    Frame 0ms    : Previous darkening at full opacity (0.80). Spotlight hole
//                  at previous step rect or full-screen if first step.
//    Frame 0–280ms: Spotlight rect tweens from oldRect → newRect using
//                  Rect.lerp with Curves.easeOutCubic.
//                  Simultaneously: tooltip card fades in (opacity 0→1)
//                  and slides up 12px → 0. Curve: Curves.easeOutCubic.
//    Frame 280ms  : Spotlight settled. Tooltip card fully visible.
//    Frame 280ms+ : Attention pulse begins on spotlight border:
//                  Border glow 0 → 8px → 0 over 1200ms, repeating.
//
//  [Skip tap]
//    Frame 0ms   : User taps Skip.
//    Frame 0–200ms: Entire overlay fades out (opacity 1→0). Curve: easeOut.
//    Frame 200ms : Overlay removed from widget tree. Preference saved.
//
//  [Step tap — advance]
//    Frame 0ms   : User taps "Got it" or tooltip body.
//    Frame 0–120ms: Tooltip card fades out + slides down 8px.
//    Frame 120ms : Step index advances. Step enter animation begins.
//
//  [Final step complete]
//    Same as skip, but a completion micro-interaction fires first:
//    Frame 0–80ms: Spotlight expands by 16px in all directions.
//    Frame 80–160ms: Spotlight shrinks back.
//    Frame 160–360ms: Overlay fades out.
//
// ARROW DIRECTIONS:
//   Each step declares ArrowDirection. The arrow is drawn as a custom
//   CustomPainter with an animated length (0 → full over 200ms at step enter,
//   delay 140ms so it appears after spotlight settles).
//   Arrow tip always points to the spotlight rect edge closest to the tooltip.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';

// ── Step definitions ──────────────────────────────────────────────────────────

enum TutorialStep {
  welcome,
  warRoomChat,
  commandDock,
  missionTab,
  intelTab,
  timetableTab,
  journalVault,
  friendsHub,
  settingsBtn,
  complete,
}

enum ArrowDirection { up, down, left, right, none }

class TutorialStepData {
  final TutorialStep step;
  final String title;
  final String body;
  final ArrowDirection arrowDirection;
  /// Where to place the tooltip relative to spotlight.
  final Alignment tooltipAnchor;

  const TutorialStepData({
    required this.step,
    required this.title,
    required this.body,
    this.arrowDirection = ArrowDirection.none,
    this.tooltipAnchor  = Alignment.bottomCenter,
  });
}

const List<TutorialStepData> kTutorialSteps = [
  TutorialStepData(
    step: TutorialStep.welcome,
    title: 'Welcome to Vyoma',
    body: 'Your personal AI operator. Everything you need — calendar, reminders, focus, and squad — all in one command layer.',
    arrowDirection: ArrowDirection.none,
    tooltipAnchor: Alignment.center,
  ),
  TutorialStepData(
    step: TutorialStep.warRoomChat,
    title: 'The War Room',
    body: 'This is your command centre. Type anything — "schedule physics lab tomorrow 2pm" — and Vyoma handles the rest.',
    arrowDirection: ArrowDirection.down,
    tooltipAnchor: Alignment.topCenter,
  ),
  TutorialStepData(
    step: TutorialStep.commandDock,
    title: 'Command Dock',
    body: 'Navigate between Mission, Intel, Journal, Timetable, and Friends. The glowing button opens the chat.',
    arrowDirection: ArrowDirection.up,
    tooltipAnchor: Alignment.topCenter,
  ),
  TutorialStepData(
    step: TutorialStep.missionTab,
    title: 'Mission Tab',
    body: "Today's focus, tasks, and your active sprint. Your battlefield for the day.",
    arrowDirection: ArrowDirection.down,
    tooltipAnchor: Alignment.bottomCenter,
  ),
  TutorialStepData(
    step: TutorialStep.intelTab,
    title: 'Intel Tab',
    body: 'Your AI-synced calendar and upcoming events — across Google Calendar and your timetable.',
    arrowDirection: ArrowDirection.down,
    tooltipAnchor: Alignment.bottomCenter,
  ),
  TutorialStepData(
    step: TutorialStep.timetableTab,
    title: 'Timetable',
    body: 'Your recurring weekly class schedule. Tell Vyoma your classes once and it remembers forever.',
    arrowDirection: ArrowDirection.down,
    tooltipAnchor: Alignment.bottomCenter,
  ),
  TutorialStepData(
    step: TutorialStep.journalVault,
    title: 'Vault',
    body: 'Private journal with AI insight extraction. What you write here stays here — and makes Vyoma smarter about you.',
    arrowDirection: ArrowDirection.down,
    tooltipAnchor: Alignment.bottomCenter,
  ),
  TutorialStepData(
    step: TutorialStep.friendsHub,
    title: 'Squad',
    body: 'Add friends. Vyoma watches your squad\'s momentum and weaves it into your daily context.',
    arrowDirection: ArrowDirection.down,
    tooltipAnchor: Alignment.bottomCenter,
  ),
  TutorialStepData(
    step: TutorialStep.settingsBtn,
    title: 'Settings',
    body: 'Connect Google Calendar, manage your API keys, and personalise your experience.',
    arrowDirection: ArrowDirection.right,
    tooltipAnchor: Alignment.bottomLeft,
  ),
];

// ── TutorialController ──────────────────────────────────────────────────────────

class TutorialController extends ChangeNotifier {
  static const _prefKey = 'vyoma_tutorial_done';

  bool _active = false;
  int  _stepIndex = 0;
  bool _loading = true;

  /// GlobalKey map: stepId → key registered by TutorialTarget
  final Map<TutorialStep, GlobalKey> _keys = {};

  bool get isActive  => _active;
  bool get isLoading => _loading;
  TutorialStep get currentStep =>
      _stepIndex < kTutorialSteps.length
          ? kTutorialSteps[_stepIndex].step
          : TutorialStep.complete;
  TutorialStepData get currentData => kTutorialSteps[_stepIndex.clamp(0, kTutorialSteps.length - 1)];
  int get stepIndex  => _stepIndex;
  int get totalSteps => kTutorialSteps.length;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final done  = prefs.getBool(_prefKey) ?? false;
    _loading = false;
    if (!done) {
      _active = true;
    }
    notifyListeners();
  }

  void registerKey(TutorialStep step, GlobalKey key) {
    _keys[step] = key;
  }

  GlobalKey? keyFor(TutorialStep step) => _keys[step];

  Rect? rectFor(TutorialStep step) {
    final key = _keys[step];
    if (key == null) return null;
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final offset = box.localToGlobal(Offset.zero);
    return offset & box.size;
  }

  void advance() {
    if (_stepIndex < kTutorialSteps.length - 1) {
      _stepIndex++;
      notifyListeners();
    } else {
      _complete();
    }
  }

  void skip() => _complete();

  Future<void> _complete() async {
    _active = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  /// Reset for testing / re-watching tutorial
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
    _stepIndex = 0;
    _active    = true;
    notifyListeners();
  }
}

// ── TutorialTarget — wrap any widget to make it spotlightable ──────────────────

class TutorialTarget extends StatefulWidget {
  final TutorialStep stepId;
  final Widget child;

  const TutorialTarget({
    super.key,
    required this.stepId,
    required this.child,
  });

  @override
  State<TutorialTarget> createState() => _TutorialTargetState();
}

class _TutorialTargetState extends State<TutorialTarget> {
  final GlobalKey _key = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ctrl = TutorialControllerProvider.of(context);
    ctrl?.registerKey(widget.stepId, _key);
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.child);
  }
}

// ── InheritedWidget provider ───────────────────────────────────────────────────────

class TutorialControllerProvider extends InheritedWidget {
  final TutorialController controller;

  const TutorialControllerProvider({
    super.key,
    required this.controller,
    required super.child,
  });

  static TutorialController? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<TutorialControllerProvider>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(TutorialControllerProvider old) =>
      controller != old.controller;
}

// ── TutorialOverlay — the full-screen story layer ───────────────────────────

class TutorialOverlay extends StatefulWidget {
  final TutorialController controller;
  final Widget child;

  const TutorialOverlay({
    super.key,
    required this.controller,
    required this.child,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with TickerProviderStateMixin {

  // Spotlight tween
  late final AnimationController _spotCtrl;
  late Animation<double> _spotProgress;
  Rect? _fromRect;
  Rect? _toRect;

  // Tooltip fade+slide
  late final AnimationController _tooltipCtrl;
  late final Animation<double> _tooltipOpacity;
  late final Animation<Offset> _tooltipSlide;

  // Arrow draw
  late final AnimationController _arrowCtrl;
  late final Animation<double> _arrowProgress;

  // Attention pulse on spotlight border
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseGlow;

  // Overlay fade (for enter/exit)
  late final AnimationController _overlayCtrl;
  late final Animation<double> _overlayOpacity;

  @override
  void initState() {
    super.initState();

    _spotCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _spotProgress = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _spotCtrl, curve: Curves.easeOutCubic));

    _tooltipCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _tooltipOpacity = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _tooltipCtrl, curve: Curves.easeOutCubic));
    _tooltipSlide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
        CurvedAnimation(parent: _tooltipCtrl, curve: Curves.easeOutCubic));

    _arrowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _arrowProgress = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _arrowCtrl, curve: Curves.easeOutCubic));

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _pulseGlow = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _overlayCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 240));
    _overlayOpacity = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _overlayCtrl, curve: Curves.easeOut));

    widget.controller.addListener(_onControllerChanged);

    if (widget.controller.isActive) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _enterCurrentStep(first: true));
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _spotCtrl.dispose();
    _tooltipCtrl.dispose();
    _arrowCtrl.dispose();
    _pulseCtrl.dispose();
    _overlayCtrl.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (!widget.controller.isActive) {
      _exitOverlay();
    } else {
      setState(() {});
      SchedulerBinding.instance.addPostFrameCallback((_) => _enterCurrentStep());
    }
  }

  void _enterCurrentStep({bool first = false}) {
    if (!mounted) return;
    final step   = widget.controller.currentStep;
    final newRect = widget.controller.rectFor(step);

    _fromRect = _toRect;
    _toRect   = newRect;

    if (first) {
      _overlayCtrl.forward();
      _pulseCtrl.repeat(reverse: true);
    }

    _tooltipCtrl.reverse().then((_) {
      _spotCtrl.forward(from: 0).then((_) {
        Future.delayed(const Duration(milliseconds: 140), () {
          if (mounted) {
            _arrowCtrl.forward(from: 0);
            _tooltipCtrl.forward();
          }
        });
      });
    });
  }

  Future<void> _exitOverlay() async {
    _pulseCtrl.stop();
    await _overlayCtrl.reverse();
    if (mounted) setState(() {});
  }

  void _advance() {
    widget.controller.advance();
  }

  void _skip() {
    widget.controller.skip();
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ctrl       = widget.controller;
    final isActive   = ctrl.isActive;
    final overlayOn  = _overlayCtrl.value > 0;

    return Stack(
      children: [
        widget.child,
        if (isActive || overlayOn)
          AnimatedBuilder(
            animation: Listenable.merge(
                [_overlayCtrl, _spotCtrl, _tooltipCtrl, _arrowCtrl, _pulseCtrl]),
            builder: (context, _) {
              if (_overlayCtrl.value == 0) return const SizedBox.shrink();

              final size = MediaQuery.of(context).size;
              final data = ctrl.currentData;

              // Interpolated spotlight rect
              Rect spotRect;
              if (_toRect != null) {
                final from = _fromRect ?? Rect.fromCenter(
                    center: size.center(Offset.zero),
                    width: size.width,
                    height: size.height);
                spotRect = Rect.lerp(from, _toRect!, _spotProgress.value)!;
                // Add comfortable padding around the target
                spotRect = spotRect.inflate(12);
              } else {
                // Welcome step: no specific target
                spotRect = Rect.fromCenter(
                    center: size.center(Offset.zero),
                    width: 0,
                    height: 0);
              }

              final pulseWidth = _pulseGlow.value * 8.0; // 0→8px glow
              final isLast = ctrl.stepIndex == ctrl.totalSteps - 1;

              return Opacity(
                opacity: _overlayOpacity.value,
                child: Stack(
                  children: [
                    // 1. Scrim with cutout
                    CustomPaint(
                      size: size,
                      painter: _SpotlightPainter(
                        spotRect:    spotRect,
                        pulseWidth:  pulseWidth,
                        pulseOpacity: _pulseGlow.value,
                      ),
                    ),

                    // 2. Arrow
                    if (data.arrowDirection != ArrowDirection.none && _toRect != null)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _ArrowPainter(
                            spotRect:  spotRect,
                            direction: data.arrowDirection,
                            progress:  _arrowProgress.value,
                          ),
                        ),
                      ),

                    // 3. Tooltip card
                    _buildTooltip(context, data, spotRect, size, isLast),

                    // 4. Skip button (top right)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 16,
                      right: 20,
                      child: GestureDetector(
                        onTap: _skip,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(18),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                                color: Colors.white.withAlpha(35), width: 0.6),
                          ),
                          child: const Text(
                            'Skip tour',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 5. Step counter (bottom left)
                    Positioned(
                      bottom: MediaQuery.of(context).padding.bottom + 28,
                      left: 24,
                      child: Text(
                        '${ctrl.stepIndex + 1} / ${ctrl.totalSteps}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildTooltip(
    BuildContext context,
    TutorialStepData data,
    Rect spotRect,
    Size screenSize,
    bool isLast,
  ) {
    const tooltipWidth  = 280.0;
    const tooltipHeight = 160.0;
    const arrowClearance = 56.0; // space for the drawn arrow

    // Position: prefer above spotlight, fall back to below
    double top;
    double left;

    if (data.arrowDirection == ArrowDirection.up ||
        data.tooltipAnchor == Alignment.topCenter) {
      // Tooltip above spotlight
      top = spotRect.top - tooltipHeight - arrowClearance;
    } else {
      // Tooltip below spotlight
      top = spotRect.bottom + arrowClearance;
    }

    // Center horizontally over spotlight, clamp to screen
    left = spotRect.center.dx - tooltipWidth / 2;
    left = left.clamp(16.0, screenSize.width - tooltipWidth - 16);
    top  = top.clamp(
        MediaQuery.of(context).padding.top + 16,
        screenSize.height - tooltipHeight - 80);

    return Positioned(
      top:  top,
      left: left,
      width: tooltipWidth,
      child: FadeTransition(
        opacity: _tooltipOpacity,
        child: SlideTransition(
          position: _tooltipSlide,
          child: _TooltipCard(
            data:   data,
            isLast: isLast,
            onNext: _advance,
            onSkip: _skip,
          ),
        ),
      ),
    );
  }
}

// ── Tooltip glass card ───────────────────────────────────────────────────────────

class _TooltipCard extends StatelessWidget {
  final TutorialStepData data;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _TooltipCard({
    required this.data,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(18),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.gold.withAlpha(80),
              width: 0.6,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data.title,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                data.body,
                style: const TextStyle(
                  color: Color(0xFFCBD5E1),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: onNext,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withAlpha(30),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: AppColors.gold.withAlpha(100),
                          width: 0.6,
                        ),
                      ),
                      child: Text(
                        isLast ? 'Let\'s go →' : 'Got it',
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Spotlight painter ────────────────────────────────────────────────────────────

class _SpotlightPainter extends CustomPainter {
  final Rect spotRect;
  final double pulseWidth;
  final double pulseOpacity;

  _SpotlightPainter({
    required this.spotRect,
    required this.pulseWidth,
    required this.pulseOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(
        spotRect, const Radius.circular(18));

    // Scrim: dark overlay with cutout hole
    final scrimPaint = Paint()
      ..color = Colors.black.withAlpha(200)
      ..blendMode = BlendMode.srcOver;

    final path = Path()
      ..addRect(fullRect)
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, scrimPaint);

    // Pulse border around spotlight
    if (pulseWidth > 0) {
      final pulsePaint = Paint()
        ..color = AppColors.gold.withAlpha((pulseOpacity * 160).round())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..maskFilter = MaskFilter.blur(
            BlurStyle.normal, pulseWidth);
      canvas.drawRRect(rrect, pulsePaint);

      // Solid hairline border
      final borderPaint = Paint()
        ..color = AppColors.gold.withAlpha(90)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;
      canvas.drawRRect(rrect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.spotRect   != spotRect   ||
      old.pulseWidth != pulseWidth ||
      old.pulseOpacity != pulseOpacity;
}

// ── Arrow painter ─────────────────────────────────────────────────────────────────

class _ArrowPainter extends CustomPainter {
  final Rect spotRect;
  final ArrowDirection direction;
  final double progress; // 0..1, animates arrow length

  _ArrowPainter({
    required this.spotRect,
    required this.direction,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;

    const arrowLength = 40.0;
    const headSize    = 8.0;
    const color       = AppColors.gold;

    Offset start;
    Offset end;

    switch (direction) {
      case ArrowDirection.down:
        // Arrow points downward from tooltip to spotlight top
        start = Offset(spotRect.center.dx,
            spotRect.top - 8 - arrowLength * (1 - progress));
        end   = Offset(spotRect.center.dx, spotRect.top - 8);
        break;
      case ArrowDirection.up:
        // Arrow points upward from tooltip to spotlight bottom
        start = Offset(spotRect.center.dx, spotRect.bottom + 8);
        end   = Offset(spotRect.center.dx,
            spotRect.bottom + 8 + arrowLength * progress);
        break;
      case ArrowDirection.left:
        start = Offset(spotRect.right + 8, spotRect.center.dy);
        end   = Offset(
            spotRect.right + 8 + arrowLength * progress, spotRect.center.dy);
        break;
      case ArrowDirection.right:
        start = Offset(
            spotRect.left - 8 - arrowLength * (1 - progress), spotRect.center.dy);
        end   = Offset(spotRect.left - 8, spotRect.center.dy);
        break;
      case ArrowDirection.none:
        return;
    }

    final paint = Paint()
      ..color       = color.withAlpha(200)
      ..strokeWidth = 1.5
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;

    canvas.drawLine(start, end, paint);

    // Arrowhead
    final headPaint = Paint()
      ..color = color.withAlpha(200)
      ..style = PaintingStyle.fill;

    final dir = (end - start).direction;
    final path = Path();
    path.moveTo(end.dx, end.dy);
    path.lineTo(
        end.dx - headSize * math.cos(dir - 0.4),
        end.dy - headSize * math.sin(dir - 0.4));
    path.lineTo(
        end.dx - headSize * math.cos(dir + 0.4),
        end.dy - headSize * math.sin(dir + 0.4));
    path.close();
    canvas.drawPath(path, headPaint);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) =>
      old.progress  != progress  ||
      old.spotRect  != spotRect  ||
      old.direction != direction;
}
