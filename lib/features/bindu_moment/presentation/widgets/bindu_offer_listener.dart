import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/agitation_detector.dart';
import '../screens/bindu_moment_screen.dart';

// Subscribes to [AgitationDetector] and surfaces a quiet snackbar offering a
// Bindu Moment. Never modal, never blocking — the user can ignore it.
//
// Mount this once near the top of the app tree (e.g. inside HomeScreen).
class BinduOfferListener extends StatefulWidget {
  const BinduOfferListener({super.key, required this.child});

  final Widget child;

  @override
  State<BinduOfferListener> createState() => _BinduOfferListenerState();
}

class _BinduOfferListenerState extends State<BinduOfferListener> {
  AgitationDetector? _detector;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context.read<AgitationDetector>();
    if (identical(next, _detector)) return;
    _detector?.removeListener(_onChange);
    _detector = next..addListener(_onChange);
  }

  @override
  void dispose() {
    _detector?.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    final detector = _detector;
    if (detector == null) return;
    if (!detector.shouldOfferBindu) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 8),
            backgroundColor: AppColors.surface1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.goldDim),
            ),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'pause for thirty seconds?',
                    style: TextStyle(
                      fontFamily: 'CormorantGaramond',
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'YES',
              textColor: AppColors.gold,
              onPressed: () {
                detector.acknowledged();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => const BinduMomentScreen(),
                  ),
                );
              },
            ),
            onVisible: () {},
          ),
        )
        .closed
        .then((reason) {
          if (reason != SnackBarClosedReason.action) {
            detector.dismissed();
          }
        });
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
