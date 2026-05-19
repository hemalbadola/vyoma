import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/vyoma_tokens.dart' show VyType;
import '../../../../ui/theme/vyoma_colors.dart';
import 'focus_clock_utils.dart';

/// 24-hour analog clock: day's focus blocks on the outer ring, live session + timer inside.
class FocusDayClock extends StatelessWidget {
  const FocusDayClock({
    super.key,
    required this.size,
    required this.dayArcs,
    this.liveArc,
    this.sessionProgress,
    required this.centerTitle,
    required this.centerSubtitle,
    this.centerDetail,
    this.showNowHand = true,
  });

  final double size;
  final List<FocusClockArc> dayArcs;
  final FocusClockArc? liveArc;
  /// 0–1 for timed modes; null = indeterminate pulse ring.
  final double? sessionProgress;
  final String centerTitle;
  final String centerSubtitle;
  final String? centerDetail;
  final bool showNowHand;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _FocusDayClockPainter(
              dayArcs: dayArcs,
              liveArc: liveArc,
              sessionProgress: sessionProgress,
              showNowHand: showNowHand,
            ),
          ),
          SizedBox(
            width: size * 0.46,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  centerTitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: VyType.display.copyWith(
                    fontSize: size * 0.11,
                    fontWeight: FontWeight.w300,
                    height: 1.1,
                  ),
                ),
                if (centerSubtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    centerSubtitle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VyType.caption.copyWith(
                      color: VyomaColors.accent,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
                if (centerDetail != null && centerDetail!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    centerDetail!,
                    textAlign: TextAlign.center,
                    style: VyType.caption.copyWith(
                      color: VyomaColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusDayClockPainter extends CustomPainter {
  _FocusDayClockPainter({
    required this.dayArcs,
    this.liveArc,
    this.sessionProgress,
    required this.showNowHand,
  });

  final List<FocusClockArc> dayArcs;
  final FocusClockArc? liveArc;
  final double? sessionProgress;
  final bool showNowHand;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2 - 4;
    final blockOuter = outerR - 2;
    final blockInner = outerR - 22;
    final innerOuter = blockInner - 10;
    final innerInner = innerOuter - 14;

    _drawRing(
      canvas,
      center,
      blockInner,
      blockOuter,
      AppColors.surface2,
      const Color(0xFF2A2820),
    );

    for (final arc in dayArcs) {
      if (liveArc != null && arc.label == liveArc!.label) continue;
      _drawArcSegment(
        canvas,
        center,
        blockInner,
        blockOuter,
        arc,
        strokeWidth: 18,
      );
    }

    if (liveArc != null) {
      _drawArcSegment(
        canvas,
        center,
        blockInner,
        blockOuter,
        liveArc!,
        strokeWidth: 20,
        glow: true,
      );
    }

    _drawHourTicks(canvas, center, blockOuter + 6, outerR);

    _drawRing(
      canvas,
      center,
      innerInner,
      innerOuter,
      AppColors.surface2.withValues(alpha: 0.6),
      AppColors.borderSubtle,
    );

    if (sessionProgress != null) {
      final sweep = 2 * math.pi * sessionProgress!.clamp(0.0, 1.0);
      final progressPaint = Paint()
        ..color = VyomaColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = innerOuter - innerInner
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: (innerInner + innerOuter) / 2),
        -math.pi / 2,
        sweep,
        false,
        progressPaint,
      );
    } else if (liveArc != null) {
      final pulse = Paint()
        ..color = VyomaColors.accent.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = innerOuter - innerInner;
      canvas.drawCircle(center, (innerInner + innerOuter) / 2, pulse);
    }

    if (showNowHand) {
      final now = DateTime.now();
      final angle = minutesToRadians(minutesSinceMidnight(now));
      final handEnd = Offset(
        center.dx + math.cos(angle) * (blockOuter - 4),
        center.dy + math.sin(angle) * (blockOuter - 4),
      );
      final handPaint = Paint()
        ..color = VyomaColors.textPrimary.withValues(alpha: 0.55)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(center, handEnd, handPaint);
      canvas.drawCircle(
        handEnd,
        3,
        Paint()..color = VyomaColors.textPrimary.withValues(alpha: 0.7),
      );
    }
  }

  void _drawRing(
    Canvas canvas,
    Offset center,
    double inner,
    double outer,
    Color fill,
    Color border,
  ) {
    final paint = Paint()
      ..color = fill
      ..style = PaintingStyle.stroke
      ..strokeWidth = outer - inner;
    canvas.drawCircle(center, (inner + outer) / 2, paint);
    final edge = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawCircle(center, outer, edge);
    canvas.drawCircle(center, inner, edge);
  }

  void _drawArcSegment(
    Canvas canvas,
    Offset center,
    double inner,
    double outer,
    FocusClockArc arc, {
    required double strokeWidth,
    bool glow = false,
  }) {
    var start = minutesToRadians(arc.startMinutes);
    var end = minutesToRadians(arc.endMinutes);
    var sweep = end - start;
    if (sweep <= 0) sweep += 2 * math.pi;

    final radius = (inner + outer) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    if (glow) {
      final glowPaint = Paint()
        ..color = arc.color.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 8
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, start, sweep, false, glowPaint);
    }

    final paint = Paint()
      ..color = arc.isLive ? arc.color : arc.color.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, sweep, false, paint);
  }

  void _drawHourTicks(
    Canvas canvas,
    Offset center,
    double inner,
    double outer,
  ) {
    const labels = {0: '0', 6: '6', 12: '12', 18: '18'};
    final tickPaint = Paint()
      ..color = VyomaColors.textMuted.withValues(alpha: 0.35)
      ..strokeWidth = 1;

    for (var h = 0; h < 24; h++) {
      final angle = minutesToRadians(h * 60);
      final major = h % 6 == 0;
      final len = major ? 8.0 : 4.0;
      final p1 = Offset(
        center.dx + math.cos(angle) * (inner - len),
        center.dy + math.sin(angle) * (inner - len),
      );
      final p2 = Offset(
        center.dx + math.cos(angle) * inner,
        center.dy + math.sin(angle) * inner,
      );
      canvas.drawLine(p1, p2, tickPaint);

      if (labels.containsKey(h)) {
        final tp = TextPainter(
          text: TextSpan(
            text: labels[h],
            style: TextStyle(
              color: VyomaColors.textMuted.withValues(alpha: 0.7),
              fontSize: 9,
              fontFamily: 'CormorantGaramond',
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        final labelR = outer + 2;
        final lp = Offset(
          center.dx + math.cos(angle) * labelR - tp.width / 2,
          center.dy + math.sin(angle) * labelR - tp.height / 2,
        );
        tp.paint(canvas, lp);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FocusDayClockPainter old) {
    return old.dayArcs != dayArcs ||
        old.liveArc != liveArc ||
        old.sessionProgress != sessionProgress;
  }
}

String formatFocusDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
  if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
  return '${s}s';
}

String formatTotalMinutes(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

String formatClockTime(DateTime dt) => DateFormat('HH:mm').format(dt);
