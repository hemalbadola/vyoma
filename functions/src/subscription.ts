import * as admin from 'firebase-admin'
import { FieldValue, Timestamp } from 'firebase-admin/firestore'

export function addDays(date: Date, days: number): Date {
  const next = new Date(date)
  next.setDate(next.getDate() + days)
  return next
}

export async function applySubscriptionDays(
  uid: string,
  opts: {
    durationDays: number
    subscriptionPlan: string
    source: 'payment' | 'coupon'
    paymentId?: string
    orderId?: string
    couponCode?: string
  }
): Promise<Timestamp> {
  const userRef = admin.firestore().collection('users').doc(uid)
  const snap = await userRef.get()
  const existingExpiry = snap.data()?.subscriptionExpiresAt as Timestamp | undefined
  const base =
    existingExpiry && existingExpiry.toDate() > new Date() ? existingExpiry.toDate() : new Date()
  const expires = addDays(base, opts.durationDays)
  const subscriptionExpiresAt = Timestamp.fromDate(expires)

  await userRef.set(
    {
      subscriptionPlan: opts.subscriptionPlan,
      subscriptionStatus: 'active',
      subscriptionActiveAt: FieldValue.serverTimestamp(),
      subscriptionExpiresAt,
      subscriptionSource: opts.source,
      ...(opts.paymentId ? { lastPaymentId: opts.paymentId } : {}),
      ...(opts.orderId ? { lastOrderId: opts.orderId } : {}),
      ...(opts.couponCode ? { lastCouponCode: opts.couponCode } : {}),
    },
    { merge: true }
  )

  return subscriptionExpiresAt
}
