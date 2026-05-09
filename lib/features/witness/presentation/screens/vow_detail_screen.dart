import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/friend_service.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/vyoma_tokens.dart' show VyType;
import '../../data/witness_models.dart';
import '../../domain/witness_service.dart';

// The detail/check-in screen. The point of this screen is the day-grid: a
// stark visualisation of which days you kept and which you missed. The
// asymmetric weight of "missing" comes from looking at it.
class VowDetailScreen extends StatelessWidget {
  const VowDetailScreen({super.key, required this.vowId});

  final String vowId;

  @override
  Widget build(BuildContext context) {
    final witness = context.read<WitnessService>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Text('your vow', style: VyType.heading),
      ),
      body: StreamBuilder<List<WitnessVow>>(
        stream: witness.streamMyVows(),
        builder: (context, snap) {
          final vows = snap.data ?? const <WitnessVow>[];
          final vow = vows.where((v) => v.id == vowId).firstOrNull;
          if (vow == null) {
            return Center(
              child: Text(
                'this vow no longer exists.',
                style: VyType.bodyMuted,
              ),
            );
          }
          return _Body(vow: vow);
        },
      ),
    );
  }
}

extension on Iterable<WitnessVow> {
  WitnessVow? get firstOrNull => isEmpty ? null : first;
}

class _Body extends StatelessWidget {
  const _Body({required this.vow});

  final WitnessVow vow;

  Future<void> _checkIn(BuildContext context) async {
    HapticFeedback.lightImpact();
    final witness = context.read<WitnessService>();
    try {
      await witness.checkInToday(vow.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('could not check in: $e')),
      );
    }
  }

  Future<void> _confirmBreak(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: Text('break this vow?', style: VyType.heading),
        content: Text(
          'your witness will be notified. that is the cost.',
          style: VyType.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('keep going', style: VyType.accent),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'break',
              style: VyType.accent.copyWith(color: AppColors.errorColor),
            ),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<WitnessService>().breakVow(vow.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final elapsed = vow.daysElapsed(now);
    final missed = vow.daysMissed(now);
    final checkedToday = vow.checkedInToday(now);
    final isActive = vow.status == VowStatus.active;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WitnessRow(witnessUid: vow.witnessUid),
          const SizedBox(height: 24),
          Text(
            vow.vowText,
            style: TextStyle(
              fontFamily: 'CormorantGaramond',
              fontSize: 28,
              fontWeight: FontWeight.w400,
              height: 1.3,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _Stat(label: 'KEPT', value: '${vow.checkIns.length}'),
              const SizedBox(width: 24),
              _Stat(label: 'MISSED', value: '$missed'),
              const SizedBox(width: 24),
              _Stat(label: 'OF', value: '${vow.durationDays}'),
            ],
          ),
          const SizedBox(height: 28),
          _DayGrid(vow: vow, elapsed: elapsed),
          const SizedBox(height: 32),
          if (isActive) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: checkedToday ? null : () => _checkIn(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: checkedToday
                        ? AppColors.borderSubtle
                        : AppColors.gold,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text(
                  checkedToday ? 'KEPT TODAY' : 'I KEPT IT TODAY',
                  style: VyType.accent.copyWith(
                    letterSpacing: 2.5,
                    color: checkedToday
                        ? AppColors.textMuted
                        : AppColors.gold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => _confirmBreak(context),
                child: Text(
                  'break this vow',
                  style: VyType.caption.copyWith(
                    color: AppColors.errorColor,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ] else
            Center(
              child: Text(
                vow.status == VowStatus.completed
                    ? 'completed.'
                    : 'broken.',
                style: VyType.bodyMuted,
              ),
            ),
        ],
      ),
    );
  }
}

class _WitnessRow extends StatelessWidget {
  const _WitnessRow({required this.witnessUid});

  final String witnessUid;

  @override
  Widget build(BuildContext context) {
    final friends = context.read<FriendService>();
    return StreamBuilder<List<UserProfile>>(
      stream: friends.streamProfiles([witnessUid]),
      builder: (context, snapshot) {
        final profile = snapshot.data?.isNotEmpty == true
            ? snapshot.data!.first
            : null;
        final name = profile?.displayName.isNotEmpty == true
            ? profile!.displayName
            : (profile?.username ?? '...');
        return Row(
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: AppColors.gold,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'WITNESSED BY ${name.toUpperCase()}',
              style: VyType.sectionLabel.copyWith(fontSize: 11),
            ),
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: VyType.sectionLabel.copyWith(fontSize: 10)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'CormorantGaramond',
            fontSize: 28,
            fontWeight: FontWeight.w400,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// Renders one cell per day of the vow. Filled = kept. Empty = missed or
// upcoming. Today is outlined. The grid is the lived record of the vow.
class _DayGrid extends StatelessWidget {
  const _DayGrid({required this.vow, required this.elapsed});

  final WitnessVow vow;
  final int elapsed;

  static const _cellSize = 14.0;
  static const _gap = 4.0;

  @override
  Widget build(BuildContext context) {
    final keptSet = vow.checkIns.toSet();
    final cells = <Widget>[];
    for (int day = 0; day < vow.durationDays; day++) {
      final date = vow.startedAt.add(Duration(days: day));
      final key =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final isToday = day == elapsed;
      final isPast = day < elapsed;
      final isKept = keptSet.contains(key);

      Color color;
      Border? border;
      if (isKept) {
        color = AppColors.gold;
      } else if (isPast) {
        color = AppColors.surface2;
      } else {
        color = AppColors.background;
      }
      if (isToday) {
        border = Border.all(color: AppColors.gold, width: 1.2);
      } else {
        border = Border.all(color: AppColors.borderSubtle, width: 0.6);
      }

      cells.add(
        Container(
          width: _cellSize,
          height: _cellSize,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            border: border,
          ),
        ),
      );
    }
    return Wrap(
      spacing: _gap,
      runSpacing: _gap,
      children: cells,
    );
  }
}
