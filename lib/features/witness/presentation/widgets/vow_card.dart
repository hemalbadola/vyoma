import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/friend_service.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/vyoma_tokens.dart' show VyType;
import '../../data/witness_models.dart';

// Compact representation of an active vow. Tapping the card opens the
// detail/check-in screen via [onTap].
class VowCard extends StatelessWidget {
  const VowCard({
    super.key,
    required this.vow,
    required this.onTap,
  });

  final WitnessVow vow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final elapsed = vow.daysElapsed(now);
    final missed = vow.daysMissed(now);
    final checkedToday = vow.checkedInToday(now);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: missed > 2 ? AppColors.errorColor : AppColors.goldDim,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: checkedToday ? AppColors.gold : AppColors.goldDim,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text('VOW', style: VyType.sectionLabel.copyWith(fontSize: 10)),
                const Spacer(),
                Text(
                  '$elapsed/${vow.durationDays} DAYS',
                  style: VyType.sectionLabel.copyWith(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              vow.vowText,
              style: TextStyle(
                fontFamily: 'CormorantGaramond',
                fontSize: 20,
                fontWeight: FontWeight.w400,
                height: 1.3,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _WitnessLabel(witnessUid: vow.witnessUid),
                const Spacer(),
                if (missed > 0)
                  Text(
                    '$missed missed',
                    style: VyType.caption.copyWith(
                      color: AppColors.errorColor,
                      fontSize: 12,
                    ),
                  )
                else if (checkedToday)
                  Text(
                    'kept today',
                    style: VyType.caption.copyWith(
                      color: AppColors.gold,
                      fontSize: 12,
                    ),
                  )
                else
                  Text(
                    'check in →',
                    style: VyType.caption.copyWith(
                      color: AppColors.gold,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Looks up the witness's display name in real time so the card reads as
// "witnessed by anya" rather than a UID.
class _WitnessLabel extends StatelessWidget {
  const _WitnessLabel({required this.witnessUid});

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
        return Text(
          'witnessed by $name',
          style: VyType.caption.copyWith(
            fontSize: 12,
            color: AppColors.textMuted,
          ),
        );
      },
    );
  }
}
