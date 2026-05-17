import crypto from 'node:crypto'
import { Router, type Request, type Response } from 'express'
import Razorpay from 'razorpay'
import admin from 'firebase-admin'
import { FieldValue } from 'firebase-admin/firestore'
import { redeemPromoCode } from './coupons'
import { DEFAULT_CURRENCY, getPlan, type PlanId } from './plans'
import { applySubscriptionDays } from './subscription'

export const paymentRouter = Router()

function getRazorpayKeyId(): string {
  const id = process.env.RAZORPAY_KEY_ID
  if (!id) throw new Error('RAZORPAY_KEY_ID not configured on server')
  return id
}

function getRazorpaySecret(): string {
  const secret = process.env.RAZORPAY_KEY_SECRET
  if (!secret) throw new Error('RAZORPAY_KEY_SECRET not configured on server')
  return secret
}

function createRazorpayClient(): Razorpay {
  return new Razorpay({
    key_id: getRazorpayKeyId(),
    key_secret: getRazorpaySecret(),
  })
}

/** Razorpay receipt: max 40 chars, alphanumeric (avoids API / checkout validation errors). */
function sanitizeReceipt(raw: string, planId?: string): string {
  const fallback = `vyoma${(planId ?? 'custom').replace(/[^a-z0-9]/gi, '')}${Date.now()}`
  const cleaned = (raw || fallback).replace(/[^a-zA-Z0-9]/g, '')
  return (cleaned || fallback).slice(0, 40)
}

async function resolveUid(req: Request): Promise<string | null> {
  const authHeader = req.headers.authorization
  if (!authHeader?.startsWith('Bearer ')) {
    return typeof req.body?.uid === 'string' ? req.body.uid : null
  }
  try {
    const decoded = await admin.auth().verifyIdToken(authHeader.slice(7))
    return decoded.uid
  } catch {
    return null
  }
}

async function requireUid(req: Request, res: Response): Promise<string | null> {
  const uid = await resolveUid(req)
  if (!uid) {
    res.status(401).json({ error: 'Sign in required' })
    return null
  }
  return uid
}

paymentRouter.post('/create-order', async (req, res) => {
  try {
    const { planId, currency = DEFAULT_CURRENCY, amount, receipt } = req.body ?? {}
    let amountPaise = typeof amount === 'number' ? amount : Number(amount)

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
    const razorpay = createRazorpayClient()
    const order = await razorpay.orders.create({
      amount: Math.round(amountPaise),
      currency,
      receipt: sanitizeReceipt(
        typeof receipt === 'string' ? receipt : '',
        typeof planId === 'string' ? planId : undefined
      ),
      notes: { planId: planId ?? '', uid: uid ?? '' },
    })

    res.json({
      order_id: order.id,
      amount: order.amount,
      currency: order.currency,
      key_id: getRazorpayKeyId(),
      planId: planId ?? null,
    })
  } catch (err: unknown) {
    console.error('[create-order]', err)
    const statusCode =
      err && typeof err === 'object' && 'statusCode' in err
        ? Number((err as { statusCode: number }).statusCode)
        : 500
    if (statusCode === 401) {
      res.status(401).json({ error: 'Razorpay authentication failed' })
      return
    }
    res.status(500).json({ error: 'Failed to create order' })
  }
})

paymentRouter.post('/verify-payment', async (req, res) => {
  const { razorpay_order_id, razorpay_payment_id, razorpay_signature } = req.body ?? {}

  if (!razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
    res.status(400).json({ error: 'Missing payment verification fields' })
    return
  }

  try {
    const expected = crypto
      .createHmac('sha256', getRazorpaySecret())
      .update(`${razorpay_order_id}|${razorpay_payment_id}`)
      .digest('hex')

    if (expected !== razorpay_signature) {
      res.status(400).json({ error: 'Invalid payment signature', success: false })
      return
    }

    const razorpay = createRazorpayClient()
    const order = await razorpay.orders.fetch(razorpay_order_id)
    const planId = (order.notes?.planId as PlanId | undefined) ?? undefined
    const notesUid = typeof order.notes?.uid === 'string' ? order.notes.uid : ''
    const uid = (await resolveUid(req)) ?? (notesUid || null)

    let subscriptionExpiresAt: string | null = null
    if (uid && planId) {
      const plan = getPlan(planId)
      if (plan) {
        const ts = await applySubscriptionDays(uid, {
          durationDays: plan.durationDays,
          subscriptionPlan: planId,
          source: 'payment',
          paymentId: razorpay_payment_id,
          orderId: razorpay_order_id,
        })
        subscriptionExpiresAt = ts.toDate().toISOString()
      }
    }

    await admin.firestore().collection('payment_records').doc(razorpay_payment_id).set({
      orderId: razorpay_order_id,
      paymentId: razorpay_payment_id,
      planId: planId ?? null,
      uid,
      amount: order.amount,
      currency: order.currency,
      verifiedAt: FieldValue.serverTimestamp(),
    })

    res.json({
      success: true,
      planId: planId ?? null,
      uid,
      subscriptionExpiresAt,
    })
  } catch (err) {
    console.error('[verify-payment]', err)
    res.status(500).json({ error: 'Payment verification failed', success: false })
  }
})

paymentRouter.post('/redeem-coupon', async (req, res) => {
  const uid = await requireUid(req, res)
  if (!uid) return

  const code = req.body?.code as string | undefined
  if (!code?.trim()) {
    res.status(400).json({ error: 'Coupon code is required' })
    return
  }

  try {
    const result = await redeemPromoCode(uid, code)
    res.json(result)
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
    if (status === 500) console.error('[redeem-coupon]', err)
    res.status(status).json({ error: message, success: false })
  }
})
