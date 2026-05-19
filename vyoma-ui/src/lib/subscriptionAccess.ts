import type { VyomaUserProfile } from '../types/userProfile'

export function hasActiveSubscription(profile: VyomaUserProfile | null): boolean {
  if (!profile) return false
  if (profile.subscriptionStatus !== 'active') return false
  if (!profile.subscriptionExpiresAt) return false
  return profile.subscriptionExpiresAt.getTime() > Date.now()
}

export function subscriptionInactiveReason(profile: VyomaUserProfile | null): string {
  if (!profile) return 'Sign in and choose a plan or redeem a coupon.'
  if (profile.subscriptionStatus !== 'active') {
    return 'No active subscription. Subscribe or redeem your 1-month coupon.'
  }
  if (!profile.subscriptionExpiresAt) return 'Subscription data missing.'
  if (profile.subscriptionExpiresAt.getTime() <= Date.now()) {
    return 'Your subscription expired. Renew at vyomai.app.'
  }
  return ''
}
