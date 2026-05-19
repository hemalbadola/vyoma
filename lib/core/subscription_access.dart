import 'models/user_profile.dart';

/// Server-mirrored entitlement check (Firestore `users/{uid}`).
abstract final class SubscriptionAccess {
  static bool hasActive(UserProfile? profile) {
    if (profile == null) return false;
    if (profile.subscriptionStatus != 'active') return false;
    final expires = profile.subscriptionExpiresAt;
    if (expires == null) return false;
    return expires.isAfter(DateTime.now());
  }

  static String? inactiveReason(UserProfile? profile) {
    if (profile == null) return 'Sign in and choose a plan or redeem a coupon.';
    if (profile.subscriptionStatus != 'active') {
      return 'No active subscription. Subscribe or redeem a 1-month coupon.';
    }
    final expires = profile.subscriptionExpiresAt;
    if (expires == null) return 'Subscription expiry missing. Contact support.';
    if (!expires.isAfter(DateTime.now())) {
      return 'Your subscription expired. Renew at vyomai.app to continue.';
    }
    return null;
  }
}
