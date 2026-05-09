import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/memory_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/vyoma_tokens.dart' show VyType;

// A 30-second contemplative pause primitive. Three phases:
//   1. Three breath cycles (inhale 4s, hold 2s, exhale 6s, hold 2s) = ~42s
//   2. A short reflection prompt: "name one feeling, one thing you avoid"
//   3. Silent save as a journal entry tagged `bindu_moment`.
//
// Tone is everything. The screen is dark, near-empty, and no progress bar
// keeps reminding the user how far they have to go. The ring breathes.
class BinduMomentScreen extends StatefulWidget {
  const BinduMomentScreen({super.key});

  @override
  State<BinduMomentScreen> createState() => _BinduMomentScreenState();
}

enum _Phase { inhale, holdIn, exhale, holdOut }

class _BreathSegment {
  const _BreathSegment(this.phase, this.duration, this.label);
  final _Phase phase;
  final Duration duration;
  final String label;
}

class _BinduMomentScreenState extends State<BinduMomentScreen>
    with SingleTickerProviderStateMixin {
  // 14s per cycle * 3 cycles = ~42s. Fits inside the "30 second" promise
  // without rushing the user. The user can exit at any time.
  static const _segments = <_BreathSegment>[
    _BreathSegment(_Phase.inhale, Duration(seconds: 4), 'breathe in'),
    _BreathSegment(_Phase.holdIn, Duration(seconds: 2), 'hold'),
    _BreathSegment(_Phase.exhale, Duration(seconds: 6), 'breathe out'),
    _BreathSegment(_Phase.holdOut, Duration(seconds: 2), 'hold'),
  ];
  static const _totalCycles = 3;

  int _cycle = 0;
  int _segIdx = 0;
  Timer? _segTimer;
  bool _showReflection = false;
  final _reflectionController = TextEditingController();

  late AnimationController _ring;

  @override
  void initState() {
    super.initState();
    _ring = AnimationController(vsync: this);
    _startSegment();
  }

  void _startSegment() {
    final seg = _segments[_segIdx];
    _ring.duration = seg.duration;
    if (seg.phase == _Phase.inhale) {
      _ring.forward(from: 0);
    } else if (seg.phase == _Phase.exhale) {
      _ring.reverse(from: 1);
    }
    HapticFeedback.selectionClick();
    _segTimer?.cancel();
    _segTimer = Timer(seg.duration, _advance);
    if (mounted) setState(() {});
  }

  void _advance() {
    if (!mounted) return;
    _segIdx++;
    if (_segIdx >= _segments.length) {
      _segIdx = 0;
      _cycle++;
    }
    if (_cycle >= _totalCycles) {
      setState(() => _showReflection = true);
      return;
    }
    _startSegment();
  }

  Future<void> _save() async {
    final memory = context.read<MemoryService>();
    final reflection = _reflectionController.text.trim();
    final entry = JournalEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      text: reflection.isEmpty ? '(silent bindu moment)' : reflection,
      mood: 'bindu',
      tags: const ['bindu_moment'],
      actionableCount: 0,
      acceptedInsights: const [],
    );
    await memory.addJournalEntry(entry);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _segTimer?.cancel();
    _ring.dispose();
    _reflectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textMuted,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Center(
              child: _showReflection
                  ? _ReflectionView(
                      controller: _reflectionController,
                      onSave: _save,
                    )
                  : _BreathView(
                      ring: _ring,
                      label: _segments[_segIdx].label,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreathView extends StatelessWidget {
  const _BreathView({required this.ring, required this.label});

  final AnimationController ring;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: ring,
          builder: (context, _) {
            final eased = Curves.easeInOut.transform(ring.value);
            final size = 80 + eased * 140;
            return SizedBox(
              width: 240,
              height: 240,
              child: Center(
                child: CustomPaint(
                  size: Size(size, size),
                  painter: _BinduRingPainter(progress: ring.value),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 56),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            label,
            key: ValueKey(label),
            style: TextStyle(
              fontFamily: 'CormorantGaramond',
              fontSize: 22,
              fontWeight: FontWeight.w300,
              letterSpacing: 0.2,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _BinduRingPainter extends CustomPainter {
  _BinduRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 1;
    final ringPaint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.35 + progress * 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius, ringPaint);
    final dotPaint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _BinduRingPainter old) =>
      old.progress != progress;
}

class _ReflectionView extends StatelessWidget {
  const _ReflectionView({required this.controller, required this.onSave});

  final TextEditingController controller;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'one feeling.\none thing you are avoiding.',
            style: TextStyle(
              fontFamily: 'CormorantGaramond',
              fontSize: 24,
              fontWeight: FontWeight.w300,
              height: 1.4,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: controller,
            autofocus: true,
            maxLines: 4,
            minLines: 2,
            style: VyType.body,
            decoration: InputDecoration(
              hintText: 'whatever surfaces.',
              hintStyle: VyType.bodyMuted,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              TextButton(
                onPressed: onSave,
                child: Text(
                  'skip',
                  style: VyType.accent.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: onSave,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.gold),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text(
                  'KEEP',
                  style: VyType.accent.copyWith(letterSpacing: 2.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
