import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/ai_service.dart';
import '../../core/memory_service.dart';
import '../war_room_viewmodel.dart';

class IntelTab extends StatelessWidget {
  const IntelTab({super.key});

  static const kSurface = Color(0xFF060809);
  static const kCardBg = Color(0xFF0E1114);
  static const kBorder = Color(0xFF1E2430);
  static const kAccent = Color(0xFF10B981);
  static const kAccentLight = Color(0xFF34D399);
  static const kWarm = Color(0xFFF59E0B);
  static const kRose = Color(0xFFF43F5E);
  static const kBlue = Color(0xFF3B82F6);
  static const kText = Color(0xFFFFFFFF);
  static const kTextSecondary = Color(0xFFA3A3A3);
  static const kTextMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WarRoomViewModel>();
    final memory = context.watch<MemoryService>();

    final metrics = vm.currentMetrics;
    final logs = memory.getAllLogs();
    final entries = vm.recentJournalEntries;
    final pendingDebriefs = memory.getPendingDebriefs();

    final insights = _deriveInsights(logs, entries);
    final clarity = _deriveClarityScore(
      logs: logs,
      entries: entries,
      metrics: metrics,
      pendingDebriefs: pendingDebriefs.length,
      streakDays: vm.journalStreakDays,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Progress',
                style: GoogleFonts.inter(
                  color: kText,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your weekly performance overview',
                style: GoogleFonts.inter(color: kTextMuted, fontSize: 13),
              ),
              const SizedBox(height: 24),

              // Momentum Ring
              _buildMomentumCard(clarity, metrics),
              const SizedBox(height: 16),

              // Metric Cards Row
              _buildMetricRow(metrics, insights),
              const SizedBox(height: 24),

              // AI Coach Digest
              _buildCoachDigest(insights, metrics, vm.journalStreakDays),
              const SizedBox(height: 24),

              // Activity Log
              _buildActivitySection(logs),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMomentumCard(_ClarityScore clarity, ProductivityMetrics metrics) {
    final score = int.tryParse(clarity.scoreLabel) ?? 0;
    final hasScore = clarity.scoreLabel != 'Baseline pending';
    final progress = hasScore ? (score / 100).clamp(0.0, 1.0) : 0.0;

    final ringColor = score >= 70
        ? kAccent
        : score >= 40
            ? kWarm
            : kRose;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ringColor.withValues(alpha: 0.06),
            kCardBg,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ringColor.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          // Momentum Ring
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CustomPaint(
                    painter: _RingPainter(
                      progress: progress,
                      color: ringColor,
                      bgColor: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hasScore ? '$score' : '—',
                      style: GoogleFonts.inter(
                        color: kText,
                        fontSize: hasScore ? 24 : 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (hasScore)
                      Text(
                        '%',
                        style: GoogleFonts.inter(
                          color: kTextMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MOMENTUM',
                  style: GoogleFonts.inter(
                    color: kTextMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  hasScore
                      ? _momentumLabel(score)
                      : 'Building baseline',
                  style: GoogleFonts.inter(
                    color: kText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  hasScore
                      ? clarity.rationale
                      : 'Complete a focus session and one reflection to start tracking.',
                  style: GoogleFonts.inter(
                    color: kTextSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.03);
  }

  String _momentumLabel(int score) {
    if (score >= 80) return 'On fire 🔥';
    if (score >= 60) return 'Strong momentum';
    if (score >= 40) return 'Building up';
    if (score >= 20) return 'Getting started';
    return 'Warming up';
  }

  Widget _buildMetricRow(ProductivityMetrics metrics, _IntelInsights insights) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _MetricData(
            icon: Icons.bolt_rounded,
            label: 'Focus',
            value: '${(metrics.focusMinutes / 60).toStringAsFixed(1)}h',
            delta: insights.focusDeltaText,
            color: kAccent,
            trend: _trendFromDelta(insights.focusDeltaText),
          ),
          _MetricData(
            icon: Icons.check_circle_outline_rounded,
            label: 'Tasks',
            value: '${metrics.tasksCompleted}',
            delta: insights.taskDeltaText,
            color: kBlue,
            trend: _trendFromDelta(insights.taskDeltaText),
          ),
          _MetricData(
            icon: Icons.warning_amber_rounded,
            label: 'Distractions',
            value: '${metrics.distractionCount}',
            delta: insights.distractionDeltaText,
            color: kRose,
            trend: _trendFromDelta(insights.distractionDeltaText, invert: true),
          ),
        ];

        final compact = constraints.maxWidth < 600;

        if (compact) {
          return Column(
            children: cards.asMap().entries.map((e) {
              return Padding(
                padding: EdgeInsets.only(bottom: e.key < cards.length - 1 ? 10 : 0),
                child: _buildMetricCard(e.value),
              ).animate(delay: (80 * e.key).ms).fadeIn();
            }).toList(),
          );
        }

        return Row(
          children: cards.asMap().entries.map((e) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: e.key < cards.length - 1 ? 10 : 0),
                child: _buildMetricCard(e.value),
              ).animate(delay: (80 * e.key).ms).fadeIn(),
            );
          }).toList(),
        );
      },
    );
  }

  int _trendFromDelta(String delta, {bool invert = false}) {
    if (delta.contains('up')) return invert ? -1 : 1;
    if (delta.contains('down')) return invert ? 1 : -1;
    return 0;
  }

  Widget _buildMetricCard(_MetricData data) {
    final trendIcon = data.trend > 0
        ? Icons.trending_up_rounded
        : data.trend < 0
            ? Icons.trending_down_rounded
            : Icons.trending_flat_rounded;
    final trendColor = data.trend > 0
        ? kAccent
        : data.trend < 0
            ? kRose
            : kTextMuted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(data.icon, size: 16, color: data.color),
              ),
              Icon(trendIcon, size: 16, color: trendColor),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            data.value,
            style: GoogleFonts.jetBrainsMono(
              color: kText,
              fontSize: 26,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.label,
            style: GoogleFonts.inter(
              color: kTextSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.delta,
            style: GoogleFonts.inter(
              color: kTextMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachDigest(_IntelInsights insights, ProductivityMetrics metrics, int streakDays) {
    final digestLines = <_DigestLine>[];

    // Focus window insight
    if (insights.bestFocusWindow != 'Build baseline this week') {
      digestLines.add(_DigestLine(
        icon: Icons.wb_sunny_outlined,
        text: 'You focus best in the ${insights.bestFocusWindow.toLowerCase()}.',
        color: kAccent,
      ));
    }

    // Task completion
    if (metrics.tasksCompleted > 0) {
      digestLines.add(_DigestLine(
        icon: Icons.task_alt_rounded,
        text: '${metrics.tasksCompleted} task${metrics.tasksCompleted > 1 ? 's' : ''} completed — ${insights.taskDeltaText}.',
        color: kBlue,
      ));
    }

    // Primary friction
    if (insights.primaryFriction != 'Log 3 outcomes to reveal friction') {
      digestLines.add(_DigestLine(
        icon: Icons.report_gmailerrorred_rounded,
        text: 'Top friction: "${insights.primaryFriction}" — address this to unlock flow.',
        color: kWarm,
      ));
    }

    // Journal streak
    if (streakDays > 0) {
      digestLines.add(_DigestLine(
        icon: Icons.local_fire_department_rounded,
        text: '$streakDays-day journal streak. Consistency builds clarity.',
        color: kRose,
      ));
    }

    // Dominant theme
    if (insights.dominantTheme != 'Capture first vault entry') {
      digestLines.add(_DigestLine(
        icon: Icons.tag_rounded,
        text: 'Recurring theme: "${insights.dominantTheme}" — this needs your attention.',
        color: kTextSecondary,
      ));
    }

    // Fallback if no insights yet
    if (digestLines.isEmpty) {
      digestLines.add(_DigestLine(
        icon: Icons.lightbulb_outline_rounded,
        text: 'Complete a few focus sessions and journal entries to unlock personalized insights.',
        color: kTextMuted,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI COACH',
          style: GoogleFonts.inter(
            color: kTextMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder, width: 0.5),
          ),
          child: Column(
            children: digestLines.asMap().entries.map((e) {
              final line = e.value;
              final isLast = e.key == digestLines.length - 1;

              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: line.color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(line.icon, size: 14, color: line.color.withValues(alpha: 0.7)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        line.text,
                        style: GoogleFonts.inter(
                          color: kTextSecondary,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildActivitySection(List<AgentLog> logs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RECENT ACTIVITY',
          style: GoogleFonts.inter(
            color: kTextMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        if (logs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No activity yet',
                  style: GoogleFonts.inter(
                    color: kText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Start with these:\n• Schedule a focus block\n• Complete one task\n• Write a journal reflection',
                  style: GoogleFonts.inter(
                    color: kTextSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          )
        else
          ...logs.take(10).toList().asMap().entries.map((e) {
            final log = e.value;
            final success = log.outcome.toLowerCase() == 'success';
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: success
                        ? kAccent.withValues(alpha: 0.12)
                        : kRose.withValues(alpha: 0.12),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: (success ? kAccent : kRose).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        success ? Icons.check_rounded : Icons.close_rounded,
                        size: 14,
                        color: success ? kAccent : kRose,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        log.actionType,
                        style: GoogleFonts.inter(
                          color: kText.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}',
                      style: GoogleFonts.jetBrainsMono(
                        color: kTextMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ).animate(delay: (40 * e.key).ms).fadeIn();
          }),
      ],
    ).animate().fadeIn(delay: 400.ms);
  }

  // --- Data Derivation (preserved logic) ---

  _IntelInsights _deriveInsights(List<AgentLog> logs, List<JournalEntry> entries) {
    final now = DateTime.now();
    final last7 = logs.where((l) => now.difference(l.timestamp).inDays < 7).toList();
    final prev7 = logs
        .where((l) => now.difference(l.timestamp).inDays >= 7 && now.difference(l.timestamp).inDays < 14)
        .toList();

    int successCount(List<AgentLog> items) =>
        items.where((e) => e.outcome.toLowerCase() == 'success').length;
    int failCount(List<AgentLog> items) =>
        items.where((e) => e.outcome.toLowerCase() != 'success').length;
    int energyScore(List<AgentLog> items) => items.fold(0, (sum, e) => sum + e.energyImpact);

    String deltaText(int current, int previous, {bool invertGood = false}) {
      if (current == 0 && previous == 0) return 'no data yet';
      final diff = current - previous;
      if (diff == 0) return 'flat vs last week';
      final up = diff > 0;
      final positive = invertGood ? !up : up;
      return '${positive ? '↑' : '↓'} ${diff.abs()} vs last week';
    }

    final focusDelta = deltaText(energyScore(last7), energyScore(prev7));
    final taskDelta = deltaText(successCount(last7), successCount(prev7));
    final distractionDelta = deltaText(failCount(last7), failCount(prev7), invertGood: true);

    final successByBand = <String, int>{};
    for (final l in last7.where((e) => e.outcome.toLowerCase() == 'success')) {
      final band = _band(l.timestamp.hour);
      successByBand[band] = (successByBand[band] ?? 0) + 1;
    }

    String bestBand = 'Build baseline this week';
    if (successByBand.isNotEmpty) {
      final ordered = successByBand.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      bestBand = ordered.first.key;
    }

    final failureActions = <String, int>{};
    for (final l in last7.where((e) => e.outcome.toLowerCase() != 'success')) {
      failureActions[l.actionType] = (failureActions[l.actionType] ?? 0) + 1;
    }

    String primaryFriction = 'Log 3 outcomes to reveal friction';
    if (failureActions.isNotEmpty) {
      final ordered = failureActions.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      primaryFriction = ordered.first.key;
    }

    final tagFrequency = <String, int>{};
    for (final e in entries.take(20)) {
      for (final tag in e.tags) {
        tagFrequency[tag] = (tagFrequency[tag] ?? 0) + 1;
      }
    }

    String dominantTheme = 'Capture first vault entry';
    if (tagFrequency.isNotEmpty) {
      final ordered = tagFrequency.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      dominantTheme = ordered.first.key;
    }

    return _IntelInsights(
      focusDeltaText: focusDelta,
      taskDeltaText: taskDelta,
      distractionDeltaText: distractionDelta,
      bestFocusWindow: bestBand,
      primaryFriction: primaryFriction,
      dominantTheme: dominantTheme,
    );
  }

  _ClarityScore _deriveClarityScore({
    required List<AgentLog> logs,
    required List<JournalEntry> entries,
    required ProductivityMetrics metrics,
    required int pendingDebriefs,
    required int streakDays,
  }) {
    final totalActions = logs.length;
    final successCount = logs.where((l) => l.outcome.toLowerCase() == 'success').length;
    final completionRate = totalActions == 0 ? 0.0 : successCount / totalActions;

    final distractionPenalty = metrics.distractionCount * 25;
    final focusSignalBase = metrics.focusMinutes + distractionPenalty;
    final focusQuality = focusSignalBase == 0 ? 0.0 : metrics.focusMinutes / focusSignalBase;

    final debriefedEvents = logs.where((l) => l.eventId != null && l.eventId!.isNotEmpty).length;
    final debriefBase = debriefedEvents + pendingDebriefs;
    final debriefRate = debriefBase == 0 ? 0.0 : debriefedEvents / debriefBase;

    final vaultConsistency = (streakDays / 5).clamp(0, 1).toDouble();

    final hasSignal = totalActions > 0 || entries.isNotEmpty || metrics.focusMinutes > 0 || metrics.distractionCount > 0;
    if (!hasSignal) {
      return const _ClarityScore(
        scoreLabel: 'Baseline pending',
        rationale: 'Complete one focus session and one reflection to establish your score.',
      );
    }

    final weighted = (completionRate * 0.35) + (focusQuality * 0.30) + (debriefRate * 0.20) + (vaultConsistency * 0.15);
    final score = (weighted * 100).round().clamp(0, 100);

    return _ClarityScore(
      scoreLabel: '$score',
      rationale: 'Completion ${(completionRate * 100).round()}% • Focus ${(focusQuality * 100).round()}% • Debrief ${(debriefRate * 100).round()}% • Journal ${streakDays}d streak',
    );
  }

  String _band(int hour) {
    if (hour >= 5 && hour < 12) return 'Morning';
    if (hour >= 12 && hour < 17) return 'Afternoon';
    if (hour >= 17 && hour < 22) return 'Evening';
    return 'Night';
  }
}

// --- Custom Painter for Ring ---

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bgColor;

  _RingPainter({required this.progress, required this.color, required this.bgColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    const strokeWidth = 5.5;

    // Background ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = bgColor,
    );

    // Progress arc
    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(
        rect,
        -math.pi / 2, // Start from top
        2 * math.pi * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}

// --- Data Classes ---

class _IntelInsights {
  final String focusDeltaText;
  final String taskDeltaText;
  final String distractionDeltaText;
  final String bestFocusWindow;
  final String primaryFriction;
  final String dominantTheme;

  _IntelInsights({
    required this.focusDeltaText,
    required this.taskDeltaText,
    required this.distractionDeltaText,
    required this.bestFocusWindow,
    required this.primaryFriction,
    required this.dominantTheme,
  });
}

class _ClarityScore {
  final String scoreLabel;
  final String rationale;

  const _ClarityScore({required this.scoreLabel, required this.rationale});
}

class _MetricData {
  final IconData icon;
  final String label;
  final String value;
  final String delta;
  final Color color;
  final int trend; // 1 = up (good), -1 = down (bad), 0 = flat

  const _MetricData({
    required this.icon,
    required this.label,
    required this.value,
    required this.delta,
    required this.color,
    required this.trend,
  });
}

class _DigestLine {
  final IconData icon;
  final String text;
  final Color color;

  const _DigestLine({required this.icon, required this.text, required this.color});
}
