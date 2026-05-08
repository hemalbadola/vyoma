// ============================================================
// pending_action_card.dart
// Structured UX card for actions that need user confirmation.
// Replaces the "say go ahead" text pattern with tappable buttons.
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vyoma/core/policy_engine.dart';
import 'package:vyoma/core/models/ai_action_proposal.dart';

class PendingActionCard extends StatelessWidget {
  const PendingActionCard({
    super.key,
    required this.pendingActions,
    required this.onApprove,
    required this.onDeny,
  });

  final List<ActionDecision> pendingActions;
  final VoidCallback onApprove;
  final VoidCallback onDeny;

  static const _kSurface = Color(0xFF111518);
  static const _kBorder = Color(0xFF1E2A33);
  static const _kAccent = Color(0xFF10B981);
  static const _kDanger = Color(0xFFEF4444);

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

  String _labelForAction(AIAction action) {
    final title = action.title ?? 'Untitled';
    switch (action.type) {
      case AIActionType.calendarCreate:
        final time = action.startTime != null
            ? ' at ${_formatTime(action.startTime!)}'
            : '';
        return 'Create "$title"$time';
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

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kAccent.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: _kAccent.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _kAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.pending_actions_rounded,
                  color: _kAccent,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'PENDING ACTIONS',
                style: GoogleFonts.jetBrainsMono(
                  color: _kAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${pendingActions.length}',
                  style: GoogleFonts.jetBrainsMono(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Action list
          ...pendingActions.map((decision) {
            final action = decision.action;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    _iconForType(action.type),
                    color: action.type.isDestructive
                        ? _kDanger.withValues(alpha: 0.7)
                        : Colors.white38,
                    size: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _labelForAction(action),
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (decision.reason != null)
                    Tooltip(
                      message: decision.reason!,
                      child: Icon(
                        Icons.info_outline_rounded,
                        color: Colors.white24,
                        size: 14,
                      ),
                    ),
                ],
              ),
            );
          }),

          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: onDeny,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: _kBorder),
                    ),
                  ),
                  child: Text(
                    'CANCEL',
                    style: GoogleFonts.jetBrainsMono(
                      color: Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'EXECUTE',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
