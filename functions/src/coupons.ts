import * as admin from 'firebase-admin'
import { FieldValue, Timestamp } from 'firebase-admin/firestore'
import { applySubscriptionDays } from './subscription'

export type CouponType = 'free_month'

type PromoDoc = {
  type: CouponType
  durationDays: number
  active: boolean
  maxRedemptions: number
  redemptionCount: number
  expiresAt?: Timestamp
  note?: string
}

function normalizeCode(raw: string): string {
  return raw.trim().toUpperCase().replace(/\s+/g, '-')
}

export async function redeemPromoCode(uid: string, rawCode: string) {
  const code = normalizeCode(rawCode)
  if (code.length < 4) {
    throw new Error('Invalid coupon code')
  }

  const db = admin.firestore()
  const promoRef = db.collection('promo_codes').doc(code)
  const redemptionRef = promoRef.collection('redemptions').doc(uid)

  await db.runTransaction(async (tx) => {
    const [promoSnap, redemptionSnap] = await Promise.all([tx.get(promoRef), tx.get(redemptionRef)])

    if (!promoSnap.exists) {
      throw new Error('Coupon not found')
    }

    const promo = promoSnap.data() as PromoDoc

    if (!promo.active) {
      throw new Error('This coupon is no longer active')
    }

    if (promo.expiresAt && promo.expiresAt.toDate() < new Date()) {
      throw new Error('This coupon has expired')
    }

    if (promo.redemptionCount >= promo.maxRedemptions) {
      throw new Error('This coupon has reached its redemption limit')
    }

    if (redemptionSnap.exists) {
      throw new Error('You have already used this coupon')
    }

    tx.update(promoRef, { redemptionCount: FieldValue.increment(1) })
    tx.set(redemptionRef, {
      uid,
      redeemedAt: FieldValue.serverTimestamp(),
    })
  })

  const promoSnap = await promoRef.get()
  const promo = promoSnap.data() as PromoDoc
  const durationDays = promo.type === 'free_month' ? promo.durationDays || 30 : promo.durationDays
  const subscriptionPlan = promo.type === 'free_month' ? 'monthly_trial' : 'promo'

  const subscriptionExpiresAt = await applySubscriptionDays(uid, {
    durationDays,
    subscriptionPlan,
    source: 'coupon',
    couponCode: code,
  })

  return {
    success: true,
    code,
    durationDays,
    subscriptionPlan,
    subscriptionExpiresAt: subscriptionExpiresAt.toDate().toISOString(),
  }
}
