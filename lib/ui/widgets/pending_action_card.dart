// Structured UX card for actions that need user confirmation.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vyoma/core/policy_engine.dart';
import 'package:vyoma/core/models/ai_action_proposal.dart';
import 'package:vyoma/ui/theme/vyoma_colors.dart';

class PendingActionCard extends StatefulWidget {
  const PendingActionCard({
    super.key,
    required this.pendingActions,
    required this.onApprove,
    required this.onDeny,
  });

  final List<ActionDecision> pendingActions;
  final VoidCallback onApprove;
  final VoidCallback onDeny;

  @override
  State<PendingActionCard> createState() => _PendingActionCardState();
}

class _PendingActionCardState extends State<PendingActionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  IconData _iconForType(AIActionType type) {
    switch (type) {
      case AIActionType.calendarCreate:
        return Icons.calendar_today_rounded;
      case AIActionType.calendarMove:
        return Icons.schedule_rounded;
      case AIActionType.calendarDelete:
        return Icons.event_busy_rounded;
      case AIActionType.timetableReplaceDay:
        return Icons.table_chart_rounded;
      case AIActionType.timetableClearDay:
        return Icons.clear_all_rounded;
      case AIActionType.reminderCreate:
        return Icons.notifications_active_rounded;
      case AIActionType.metricsIncrement:
        return Icons.trending_up_rounded;
    }
  }

  String _titleLine(AIAction action) {
    final title = action.title ?? 'Untitled';
    switch (action.type) {
      case AIActionType.calendarCreate:
        return title;
      case AIActionType.calendarMove:
        return 'Move "$title"';
      case AIActionType.calendarDelete:
        return 'Delete "$title"';
      case AIActionType.timetableReplaceDay:
        return 'Update ${action.weekday ?? "day"} timetable';
      case AIActionType.timetableClearDay:
        return 'Clear ${action.weekday ?? "day"} timetable';
      case AIActionType.reminderCreate:
        return 'Remind: "$title"';
      case AIActionType.metricsIncrement:
        return 'Update ${action.scope ?? "metrics"}';
    }
  }

  String? _timeLine(AIAction action) {
    if (action.startTime == null) return null;
    return _formatTime(action.startTime!);
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = CurvedAnimation(parent: _pulse, curve: Curves.easeInOut).value;
        final glow = VyomaColors.warning.withValues(alpha: 0.35 + t * 0.35);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: VyomaColors.bgCardElevated.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: glow, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: VyomaColors.warning.withValues(alpha: 0.12 + t * 0.12),
                blurRadius: 18,
                spreadRadius: t * 0.5,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Vyoma wants to do this:',
                style: GoogleFonts.inter(
                  color: VyomaColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ...widget.pendingActions.map((decision) {
                final action = decision.action;
                final time = _timeLine(action);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _iconForType(action.type),
                        color: action.type.isDestructive
                            ? VyomaColors.error.withValues(alpha: 0.75)
                            : VyomaColors.textMuted,
                        size: 16,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• ${_titleLine(action)}',
                              style: GoogleFonts.inter(
                                color: VyomaColors.textPrimary.withValues(alpha: 0.9),
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                            if (time != null)
                              Text(
                                time,
                                style: GoogleFonts.jetBrainsMono(
                                  color: VyomaColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onDeny,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: VyomaColors.textSecondary,
                        side: BorderSide(color: VyomaColors.borderDefault),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        'Cancel ✗',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: widget.onApprove,
                      style: FilledButton.styleFrom(
                        backgroundColor: VyomaColors.accent,
                        foregroundColor: VyomaColors.textOnAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        'Approve ✓',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
