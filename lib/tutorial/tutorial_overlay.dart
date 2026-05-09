import 'dart:math' as math;
import 'package:vyoma/agent_debug_log.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:vyoma/ui/theme/vyoma_colors.dart';

import 'tutorial_controller.dart';
import 'tutorial_step.dart';

const Color _kTutorialDim = Color(0xB8000000); // black ~0.72

/// Full-screen tutorial spotlight with animated hole, arrow, and tooltip card.
class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({
    super.key,
    required this.controller,
  });

  final TutorialController controller;

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> with TickerProviderStateMixin {
  Rect _previousHole = Rect.zero;
  late AnimationController _fadeController;

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

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
    widget.controller.addListener(_onCtrl);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onCtrl);
    _fadeController.dispose();
    super.dispose();
  }

  void _onCtrl() {
    if (!mounted) return;
    _fadeController.forward(from: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  Rect? _measureHole(BuildContext context, TutorialStep step) {
    final ctx = step.targetWidgetKey.currentContext;
    final ro = ctx?.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) {
      _debugLog(
        hypothesisId: 'H1',
        location: 'tutorial_overlay.dart:_measureHole',
        message: 'Target key has no RenderBox',
        data: {'stepId': step.stepId, 'hasContext': ctx != null},
      );
      return null;
    }
    final offset = ro.localToGlobal(Offset.zero);
    final size = ro.size;
    var rect = offset & size;

    switch (step.highlightShape) {
      case TutorialHighlightShape.rectangle:
        rect = rect.inflate(8);
        break;
      case TutorialHighlightShape.circle:
        final r = math.max(rect.width, rect.height) / 2 + 12;
        rect = Rect.fromCircle(center: rect.center, radius: r);
        break;
    }
    return rect;
  }

  Offset _arrowPivot(Rect hole, TutorialArrowDirection dir) {
    switch (dir) {
      case TutorialArrowDirection.top:
        return Offset(hole.center.dx, hole.top);
      case TutorialArrowDirection.bottom:
        return Offset(hole.center.dx, hole.bottom);
      case TutorialArrowDirection.left:
        return Offset(hole.left, hole.center.dy);
      case TutorialArrowDirection.right:
        return Offset(hole.right, hole.center.dy);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.isActive) {
      return const SizedBox.shrink();
    }

    final step = widget.controller.currentStep;
    final media = MediaQuery.of(context);
    final screen = media.size;

    _debugLog(
      hypothesisId: 'H1',
      location: 'tutorial_overlay.dart:build',
      message: 'Tutorial overlay active',
      data: {
        'stepId': step.stepId,
        'stepIndex': widget.controller.currentStepIndex,
      },
    );
    return _buildFrame(context, step, screen, media.padding);
  }

  Widget _buildFrame(
    BuildContext context,
    TutorialStep step,
    Size screen,
    EdgeInsets padding,
  ) {
    final measured = _measureHole(context, step);
    final target = measured ??
        Rect.fromCenter(
          center: Offset(screen.width / 2, screen.height / 2),
          width: 120,
          height: 120,
        );
    if (measured == null) {
      _debugLog(
        hypothesisId: 'H2',
        location: 'tutorial_overlay.dart:_buildFrame',
        message: 'Fallback target rect used',
        data: {'stepId': step.stepId},
      );
    }

    final begin = _previousHole == Rect.zero ? target : _previousHole;

    return Material(
      color: Colors.transparent,
      child: TweenAnimationBuilder<Rect?>(
        tween: RectTween(begin: begin, end: target),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        onEnd: () => _previousHole = target,
        builder: (context, hole, _) {
          final activeHole = hole ?? target;
          final pivot = _arrowPivot(activeHole, step.arrowDirection);

          final cardWidth = math.min(340.0, screen.width - 32);
          const cardEstimatedHeight = 280.0;
          double cardLeft = (screen.width - cardWidth) / 2;
          double cardTop = screen.height - padding.bottom - cardEstimatedHeight - 28;

          cardTop = cardTop.clamp(padding.top + 12, screen.height - padding.bottom - 120);

          final cardCenter = Offset(cardLeft + cardWidth / 2, cardTop + 70);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                size: screen,
                painter: _SpotlightPainter(hole: activeHole, shape: step.highlightShape),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: true,
                  child: CustomPaint(
                    painter: _ArrowPainter(
                      from: cardCenter,
                      to: pivot,
                      direction: step.arrowDirection,
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutCubic,
                left: cardLeft,
                top: cardTop,
                width: cardWidth,
                child: FadeTransition(
                  opacity: CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
                  child: _TutorialTooltipCard(
                      title: step.title,
                      description: step.description,
                      isLastStep:
                          widget.controller.currentStepIndex >= widget.controller.steps.length - 1,
                      canSkip: step.canSkip,
                      onNext: widget.controller.next,
                      onSkip: widget.controller.skip,
                    ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({required this.hole, required this.shape});

  final Rect hole;
  final TutorialHighlightShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    Path cutout;
    switch (shape) {
      case TutorialHighlightShape.circle:
        cutout = Path()
          ..addOval(Rect.fromCircle(center: hole.center, radius: hole.width / 2));
        break;
      case TutorialHighlightShape.rectangle:
        cutout = Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              hole,
              const Radius.circular(14),
            ),
          );
        break;
    }
    final overlay = Path.combine(PathOperation.difference, full, cutout);
    canvas.drawPath(overlay, Paint()..color = _kTutorialDim);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.hole != hole || oldDelegate.shape != shape;
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter({
    required this.from,
    required this.to,
    required this.direction,
  });

  final Offset from;
  final Offset to;
  final TutorialArrowDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Shorten line so it does not overlap card / hole
    final dir = (to - from);
    final len = dir.distance;
    if (len < 24) return;
    final unit = dir / len;
    final start = from + unit * 18;
    final end = to - unit * 14;

    final ctrl = _controlPoint(start, end, direction);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);
    canvas.drawPath(path, paint);

    final headSize = 11.0;
    final tip = end;
    final back = end - unit * headSize;
    final perp = Offset(-unit.dy, unit.dx) * (headSize * 0.55);
    final arrowPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(back.dx + perp.dx, back.dy + perp.dy)
      ..lineTo(back.dx - perp.dx, back.dy - perp.dy)
      ..close();
    canvas.drawPath(
      arrowPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.fill,
    );
  }

  Offset _controlPoint(Offset a, Offset b, TutorialArrowDirection dir) {
    final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    switch (dir) {
      case TutorialArrowDirection.top:
      case TutorialArrowDirection.bottom:
        final delta = a.dy - b.dy;
        final magnitude = delta.abs() < 40 ? (delta.isNegative ? -40.0 : 40.0) : delta;
        return Offset(mid.dx + magnitude * 0.3, mid.dy);
      case TutorialArrowDirection.left:
      case TutorialArrowDirection.right:
        final delta = a.dx - b.dx;
        final magnitude = delta.abs() < 40 ? (delta.isNegative ? -40.0 : 40.0) : delta;
        return Offset(mid.dx, mid.dy + magnitude * 0.3);
    }
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) {
    return oldDelegate.from != from || oldDelegate.to != to || oldDelegate.direction != direction;
  }
}

class _TutorialTooltipCard extends StatelessWidget {
  const _TutorialTooltipCard({
    required this.title,
    required this.description,
    required this.isLastStep,
    required this.canSkip,
    required this.onNext,
    required this.onSkip,
  });

  final String title;
  final String description;
  final bool isLastStep;
  final bool canSkip;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: BoxDecoration(
              color: const Color(0xE6161B26),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (canSkip)
                      TextButton(
                        onPressed: onSkip,
                        child: Text(
                          'Skip Tutorial',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                        ),
                      )
                    else
                      const SizedBox(width: 8),
                    const Spacer(),
                    FilledButton(
                      onPressed: onNext,
                      style: FilledButton.styleFrom(
                        backgroundColor: VyomaColors.accent,
                        foregroundColor: VyomaColors.textOnAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(isLastStep ? 'Done' : 'Next'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
