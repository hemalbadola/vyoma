import * as admin from 'firebase-admin'
import { FieldValue, Timestamp } from 'firebase-admin/firestore'
import { onRequest } from 'firebase-functions/v2/https'
import * as crypto from 'node:crypto'
import { redeemPromoCode } from './coupons'
import { DEFAULT_CURRENCY, getPlan, type PlanId } from './plans'
import { createRazorpayClient, getRazorpayKeyId } from './razorpay'
import { applySubscriptionDays } from './subscription'
import { broadcastAppUpdate } from './app_version_broadcast'

admin.initializeApp()

export { broadcastAppUpdate }

const REGION = 'asia-south1'

const corsOrigins = [
  'https://vyoma-in.web.app',
  'https://vyomai.app',
  'http://localhost:5173',
  'http://127.0.0.1:5173',
]

function setCors(res: { set: (key: string, value: string) => void }, origin?: string) {
  const allowed = origin && corsOrigins.includes(origin) ? origin : corsOrigins[0]
  res.set('Access-Control-Allow-Origin', allowed)
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS')
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization')
}

async function resolveUid(req: { headers: { authorization?: string }; body: { uid?: string } }): Promise<string | null> {
  const authHeader = req.headers.authorization
  if (authHeader?.startsWith('Bearer ')) {
    const token = authHeader.slice(7)
    try {
      const decoded = await admin.auth().verifyIdToken(token)
      return decoded.uid
    } catch {
      return null
    }
  }
  return typeof req.body.uid === 'string' && req.body.uid.length > 0 ? req.body.uid : null
}

export const createOrder = onRequest({ region: REGION, cors: corsOrigins }, async (req, res) => {
  setCors(res, req.headers.origin as string | undefined)

  if (req.method === 'OPTIONS') {
    res.status(204).send('')
    return
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' })
    return
  }

  try {
    const body = req.body ?? {}
    const planId = body.planId as string | undefined
    const currency = (body.currency as string | undefined) ?? DEFAULT_CURRENCY
    let amountPaise = typeof body.amount === 'number' ? body.amount : Number(body.amount)

    if (planId) {
      const plan = getPlan(planId)
      if (!plan) {
        res.status(400).json({ error: 'Invalid planId' })
        return
      }
      amountPaise = plan.amountPaise
    }

    if (!Number.isFinite(amountPaise) || amountPaise < 100) {
      res.status(400).json({ error: 'Amount must be at least 100 paise' })
      return
    }

    const uid = await resolveUid(req)
    const receipt =
      typeof body.receipt === 'string' && body.receipt.length > 0
        ? body.receipt
        : `vyoma_${planId ?? 'custom'}_${Date.now()}`

    const razorpay = createRazorpayClient()
    const order = await razorpay.orders.create({
      amount: Math.round(amountPaise),
      currency,
      receipt,
      notes: {
        planId: planId ?? '',
        uid: uid ?? '',
      },
    })

    res.status(200).json({
      order_id: order.id,
      amount: order.amount,
      currency: order.currency,
      key_id: getRazorpayKeyId(),
      planId: planId ?? null,
    })
  } catch (err: unknown) {
    const statusCode =
      err && typeof err === 'object' && 'statusCode' in err
        ? Number((err as { statusCode: number }).statusCode)
        : 500

    if (statusCode === 401) {
      res.status(401).json({ error: 'Razorpay authentication failed' })
      return
    }

    console.error('[createOrder]', err)
    res.status(500).json({ error: 'Failed to create order' })
  }
})

export const verifyPayment = onRequest({ region: REGION, cors: corsOrigins }, async (req, res) => {
  setCors(res, req.headers.origin as string | undefined)

  if (req.method === 'OPTIONS') {
    res.status(204).send('')
    return
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' })
    return
  }

  const body = req.body ?? {}
  const orderId = body.razorpay_order_id as string | undefined
  const paymentId = body.razorpay_payment_id as string | undefined
  const signature = body.razorpay_signature as string | undefined

  if (!orderId || !paymentId || !signature) {
    res.status(400).json({ error: 'Missing payment verification fields' })
    return
  }

  try {
    const secret = process.env.RAZORPAY_KEY_SECRET
    if (!secret) {
      res.status(500).json({ error: 'Server misconfigured' })
      return
    }

    const expected = crypto.createHmac('sha256', secret).update(`${orderId}|${paymentId}`).digest('hex')

    if (expected !== signature) {
      res.status(400).json({ error: 'Invalid payment signature', success: false })
      return
    }

    const razorpay = createRazorpayClient()
    const order = await razorpay.orders.fetch(orderId)
    const planId = (order.notes?.planId as PlanId | undefined) ?? undefined
    const notesUid = typeof order.notes?.uid === 'string' ? order.notes.uid : ''
    const uid = (await resolveUid(req)) ?? (notesUid || null)

    let subscriptionExpiresAt: Timestamp | null = null
    if (uid && planId) {
      const plan = getPlan(planId)
      if (plan) {
        subscriptionExpiresAt = await applySubscriptionDays(uid, {
          durationDays: plan.durationDays,
          subscriptionPlan: planId,
          source: 'payment',
          paymentId,
          orderId,
        })
      }
    }

    await admin.firestore().collection('payment_records').doc(paymentId).set({
      orderId,
      paymentId,
      planId: planId ?? null,
      uid,
      amount: order.amount,
      currency: order.currency,
      verifiedAt: FieldValue.serverTimestamp(),
    })

    res.status(200).json({
      success: true,
      planId: planId ?? null,
      uid,
      subscriptionExpiresAt: subscriptionExpiresAt?.toDate().toISOString() ?? null,
    })
  } catch (err) {
    console.error('[verifyPayment]', err)
    res.status(500).json({ error: 'Payment verification failed', success: false })
  }
})

export const redeemCoupon = onRequest({ region: REGION, cors: corsOrigins }, async (req, res) => {
  setCors(res, req.headers.origin as string | undefined)

  if (req.method === 'OPTIONS') {
    res.status(204).send('')
    return
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' })
    return
  }

  const uid = await resolveUid(req)
  if (!uid) {
    res.status(401).json({ error: 'Sign in required to redeem a coupon' })
    return
  }

  const code = (req.body?.code as string | undefined) ?? ''
  if (!code.trim()) {
    res.status(400).json({ error: 'Coupon code is required' })
    return
  }

  try {
    const result = await redeemPromoCode(uid, code)
    res.status(200).json(result)
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Could not redeem coupon'
    const clientErrors = [
      'Coupon not found',
      'This coupon is no longer active',
      'This coupon has expired',
      'This coupon has reached its redemption limit',
      'You have already used this coupon',
      'Invalid coupon code',
    ]
    const status = clientErrors.includes(message) ? 400 : 500
    if (status === 500) {
      console.error('[redeemCoupon]', err)
    }
    res.status(status).json({ error: message, success: false })
  }
})
