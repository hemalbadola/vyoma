import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/logic/memory_braid_engine.dart';
import '../../../../core/memory_service.dart';
import '../../../../core/models/daily_stats.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/vyoma_tokens.dart' show VyType;

// Surfaces a single relevant past journal entry tied to today's one-thing.
// Renders nothing when there is no one-thing, no past entries, or no match.
//
// This is the journal *talking back* — the differentiator that makes Vyoma's
// memory feel alive instead of a passive log.
class MemoryBraidCard extends StatelessWidget {
  const MemoryBraidCard({super.key, required this.stats, this.onOpenEntry});

  final DailyStats stats;
  final ValueChanged<JournalEntry>? onOpenEntry;

  static const _engine = MemoryBraidEngine();

  @override
  Widget build(BuildContext context) {
    final intent = stats.oneThing?.trim() ?? '';
    if (intent.isEmpty) return const SizedBox.shrink();

    final memory = context.watch<MemoryService>();
    final entries = memory.getJournalEntries();
    if (entries.isEmpty) return const SizedBox.shrink();

    final braid = _engine.braid(intent: intent, entries: entries);
    if (braid == null) return const SizedBox.shrink();

    final ageDays = DateTime.now().difference(braid.timestamp).inDays;
    final ageLabel = _formatAge(ageDays, braid.timestamp);
    final preview = _firstSentence(braid.text);

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpenEntry != null ? () => onOpenEntry!(braid) : null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: AppColors.goldDim,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'YOU WROTE THIS $ageLabel',
                    style: VyType.sectionLabel.copyWith(fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '"$preview"',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: VyType.body.copyWith(
                  fontSize: 15,
                  height: 1.5,
                  color: AppColors.textPrimary,
                ),
              ),
              if (onOpenEntry != null) ...[
                const SizedBox(height: 12),
                Text(
                  'open entry',
                  style: VyType.accent.copyWith(
                    fontSize: 11,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatAge(int days, DateTime when) {
    if (days < 7) return '$days DAYS AGO';
    if (days < 30) return '${(days / 7).floor()} WEEKS AGO';
    if (days < 365) return '${(days / 30).floor()} MONTHS AGO';
    return DateFormat('MMM yyyy').format(when).toUpperCase();
  }

  String _firstSentence(String text) {
    final clean = text.trim();
    final endIdx = clean.indexOf(RegExp(r'[.!?]'));
    if (endIdx == -1 || endIdx > 200) {
      return clean.length > 200 ? '${clean.substring(0, 200)}...' : clean;
    }
    return clean.substring(0, endIdx + 1);
  }
}
