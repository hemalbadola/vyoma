import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/friend_service.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/vyoma_tokens.dart' show VyType;
import '../../../../core/widgets/vy_loader.dart';
import '../../domain/witness_service.dart';

// A tightly-scripted ritual for creating a vow. Three steps in one screen:
// 1) the vow text, 2) the witness, 3) the duration. Submission disabled until
// all three are honest. The friction is deliberate — easy commitments are
// performance, not practice.
class CreateVowScreen extends StatefulWidget {
  const CreateVowScreen({super.key});

  @override
  State<CreateVowScreen> createState() => _CreateVowScreenState();
}

class _CreateVowScreenState extends State<CreateVowScreen> {
  final _vowController = TextEditingController();
  String? _witnessUid;
  int _durationDays = 30;
  bool _submitting = false;
  String? _error;

  static const _durationOptions = [7, 14, 30, 60, 90];

  bool get _canSubmit =>
      _vowController.text.trim().isNotEmpty &&
      _witnessUid != null &&
      !_submitting;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final witness = context.read<WitnessService>();
      await witness.createVow(
        witnessUid: _witnessUid!,
        vowText: _vowController.text.trim(),
        durationDays: _durationDays,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _submitting = false;
      });
    }
  }

  @override
  void dispose() {
    _vowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Text('a vow', style: VyType.heading),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'a vow is a commitment to one named person.\n'
                'they are not your peer. they are your holder.',
                style: VyType.bodyMuted.copyWith(height: 1.6),
              ),
              const SizedBox(height: 32),
              Text('THE VOW', style: VyType.sectionLabel),
              const SizedBox(height: 8),
              TextField(
                controller: _vowController,
                style: VyType.body,
                maxLines: 3,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText:
                      'i will write 1000 words a day for the next 30 days',
                ),
              ),
              const SizedBox(height: 28),
              Text('YOUR WITNESS', style: VyType.sectionLabel),
              const SizedBox(height: 8),
              _WitnessPicker(
                selectedUid: _witnessUid,
                onSelect: (uid) => setState(() => _witnessUid = uid),
              ),
              const SizedBox(height: 28),
              Text('DURATION', style: VyType.sectionLabel),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _durationOptions
                    .map(
                      (days) => _DurationChip(
                        days: days,
                        selected: days == _durationDays,
                        onTap: () => setState(() => _durationDays = days),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 36),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: VyType.caption.copyWith(color: AppColors.errorColor),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _canSubmit
                          ? AppColors.gold
                          : AppColors.borderSubtle,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 18, height: 18, child: VyLoader())
                      : Text(
                          'TAKE THE VOW',
                          style: VyType.accent.copyWith(letterSpacing: 2.5),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'your witness is notified when you skip a day.\n'
                'leaving the vow means telling them.',
                style: VyType.caption.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WitnessPicker extends StatelessWidget {
  const _WitnessPicker({required this.selectedUid, required this.onSelect});

  final String? selectedUid;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final friends = context.read<FriendService>();
    return StreamBuilder<List<String>>(
      stream: friends.getAcceptedFriendUidsStream(),
      builder: (context, uidsSnap) {
        if (uidsSnap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: VyLoader(),
          );
        }
        final uids = uidsSnap.data ?? const <String>[];
        if (uids.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borderSubtle),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'a vow needs a witness. add a friend first.',
              style: VyType.bodyMuted,
            ),
          );
        }
        return StreamBuilder<List<UserProfile>>(
          stream: friends.streamProfiles(uids),
          builder: (context, profSnap) {
            final profiles = profSnap.data ?? const <UserProfile>[];
            if (profiles.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: VyLoader(),
              );
            }
            return Column(
              children: profiles
                  .map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _WitnessOption(
                        profile: p,
                        selected: p.uid == selectedUid,
                        onTap: () => onSelect(p.uid),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        );
      },
    );
  }
}

class _WitnessOption extends StatelessWidget {
  const _WitnessOption({
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  final UserProfile profile;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              alignment: Alignment.center,
              child: Text(
                profile.displayName.isNotEmpty
                    ? profile.displayName[0].toUpperCase()
                    : (profile.username.isNotEmpty
                        ? profile.username[0].toUpperCase()
                        : '?'),
                style: VyType.body.copyWith(color: AppColors.gold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName.isNotEmpty
                        ? profile.displayName
                        : profile.username,
                    style: VyType.body,
                  ),
                  if (profile.username.isNotEmpty)
                    Text('@${profile.username}', style: VyType.caption),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded, color: AppColors.gold, size: 20),
          ],
        ),
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.days,
    required this.selected,
    required this.onTap,
  });

  final int days;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.border,
          ),
          color: selected
              ? AppColors.gold.withValues(alpha: 0.06)
              : Colors.transparent,
        ),
        child: Text(
          '$days days',
          style: VyType.body.copyWith(
            fontSize: 13,
            color: selected ? AppColors.gold : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
