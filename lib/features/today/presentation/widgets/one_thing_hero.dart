import 'package:flutter/material.dart';

import '../../../../core/models/daily_stats.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/vyoma_tokens.dart' show VyType;

// The wedge of the entire app: one question, full-screen presence when unset,
// a quiet anchor when set. Tapping always opens the editor sheet.
//
// Design philosophy: the screen IS the question. Everything else on Today is
// secondary and earns its place by supporting this single intent.
class OneThingHero extends StatelessWidget {
  const OneThingHero({
    super.key,
    required this.stats,
    required this.onChange,
  });

  final DailyStats stats;
  final ValueChanged<String> onChange;

  bool get _hasOneThing =>
      stats.oneThing != null && stats.oneThing!.trim().isNotEmpty;

  Future<void> _edit(BuildContext context) async {
    final controller = TextEditingController(text: stats.oneThing ?? '');
    final result = await showDialog<String>(
      context: context,
      barrierColor: AppColors.background.withValues(alpha: 0.85),
      builder: (context) => Dialog(
        backgroundColor: AppColors.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("today's one thing", style: VyType.heading),
                const SizedBox(height: 4),
                Text(
                  'restraint is the practice. one is enough.',
                  style: VyType.caption,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 3,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  style: VyType.body,
                  decoration: InputDecoration(
                    hintText: 'finish chapter 3 draft',
                    hintStyle: VyType.bodyMuted,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_hasOneThing)
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(''),
                        child: Text('clear',
                            style: VyType.accent.copyWith(
                              color: AppColors.textMuted,
                              letterSpacing: 1.5,
                            )),
                      ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      child: Text('cancel',
                          style: VyType.accent.copyWith(
                            color: AppColors.textMuted,
                            letterSpacing: 1.5,
                          )),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).pop(controller.text.trim()),
                      child: Text(
                        _hasOneThing ? 'save' : 'commit',
                        style: VyType.accent.copyWith(letterSpacing: 1.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null) return;
    onChange(result);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasOneThing) {
      return _CompactState(
        oneThing: stats.oneThing!.trim(),
        onTap: () => _edit(context),
      );
    }
    return _UnsetState(onTap: () => _edit(context));
  }
}

// When no one-thing is set, the hero takes the full Today canvas.
// This is the "wedge" -- the screen literally IS the question.
class _UnsetState extends StatelessWidget {
  const _UnsetState({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 48, 28, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The bindu — silent invitation, not a button.
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.gold,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'what is the one thing\ntoday?',
              style: TextStyle(
                fontFamily: 'CormorantGaramond',
                fontSize: 38,
                fontWeight: FontWeight.w300,
                letterSpacing: 0.2,
                height: 1.15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'restraint is the practice.\nname one. nothing else.',
              style: TextStyle(
                fontFamily: 'CormorantGaramond',
                fontSize: 16,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.1,
                height: 1.55,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 40),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.goldDim),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'NAME IT',
                        style: TextStyle(
                          fontFamily: 'CormorantGaramond',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 2.5,
                          color: AppColors.gold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: AppColors.gold,
                      ),
                    ],
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

// When set, the hero compresses into a quiet anchor: gold bindu, label,
// the commitment itself, edit pencil. Still tappable to revise.
class _CompactState extends StatelessWidget {
  const _CompactState({required this.oneThing, required this.onTap});

  final String oneThing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TODAY',
                    style: TextStyle(
                      fontFamily: 'CormorantGaramond',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    oneThing,
                    style: TextStyle(
                      fontFamily: 'CormorantGaramond',
                      fontSize: 24,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.2,
                      height: 1.3,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Icon(
                Icons.edit_outlined,
                color: AppColors.textMuted,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
