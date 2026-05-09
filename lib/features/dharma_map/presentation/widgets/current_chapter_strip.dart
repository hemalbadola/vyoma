import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/vyoma_tokens.dart' show VyType;
import '../../domain/dharma_map_service.dart';
import '../screens/dharma_map_screen.dart';

// Quiet line on Today: "chapter: rigor". Tap opens the dharma map.
// Hidden when no chapter is open — pre-onboarding noise.
class CurrentChapterStrip extends StatelessWidget {
  const CurrentChapterStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<DharmaMapService>();
    if (!svc.isInitialized) return const SizedBox.shrink();
    final ch = svc.currentChapter;
    if (ch == null) return const SizedBox.shrink();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DharmaMapScreen()),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 6, 28, 0),
        child: Row(
          children: [
            Text(
              'CHAPTER',
              style: VyType.sectionLabel.copyWith(
                fontSize: 9,
                letterSpacing: 2,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              ch.themeWord,
              style: TextStyle(
                fontFamily: 'CormorantGaramond',
                fontSize: 13,
                color: AppColors.gold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
