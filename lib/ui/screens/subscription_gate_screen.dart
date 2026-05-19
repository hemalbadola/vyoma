import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/subscription_access.dart';
import '../../core/user_service.dart';
import 'subscription_screen.dart';

/// Full-screen paywall until subscription or coupon is active.
class SubscriptionGateScreen extends StatelessWidget {
  const SubscriptionGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Consumer<UserService>(
        builder: (context, userSvc, _) {
          final reason = SubscriptionAccess.inactiveReason(userSvc.currentProfile);
          return SubscriptionScreen(
            gateMessage: reason,
            showSignOut: true,
          );
        },
      ),
    );
  }
}
