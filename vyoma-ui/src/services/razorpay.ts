import { RAZORPAY_CHECKOUT_CONFIG, RAZORPAY_CHECKOUT_METHODS } from '../config/razorpayCheckout'
import type { PricingPlan } from '../components/landing/PaymentModal'
import type { RazorpaySuccessResponse } from '../types/razorpay'
import { buildOrderReceipt, buildRazorpayPrefill } from './razorpayPrefill'

const HEROKU_API = 'https://vyoma-api-backend-9629c91b8aad.herokuapp.com/api'

function resolveApiBase(): string {
  const raw = (import.meta.env.VITE_API_BASE_URL ?? HEROKU_API).trim().replace(/\/$/, '')
  try {
    new URL(raw)
    return raw
  } catch {
    return HEROKU_API
  }
}

const API_BASE = resolveApiBase()
const KEY_ID = (import.meta.env.VITE_RAZORPAY_KEY_ID ?? '').trim()

function isMobileCheckout(): boolean {
  if (typeof navigator === 'undefined') return false
  return /iPhone|iPad|iPod|Android/i.test(navigator.userAgent)
}

export type CreateOrderResponse = {
  order_id: string
  amount: number
  currency: string
  key_id: string
  planId: string | null
}

export type VerifyPaymentResponse = {
  success: boolean
  planId?: string | null
  subscriptionExpiresAt?: string | null
  error?: string
}

function assertCheckoutReady() {
  if (!KEY_ID) {
    throw new Error('Payment is not configured (missing VITE_RAZORPAY_KEY_ID).')
  }
  if (!window.Razorpay) {
    throw new Error('Razorpay checkout script failed to load.')
  }
}

export async function createOrder(
  plan: PricingPlan,
  options?: { uid?: string; authToken?: string }
): Promise<CreateOrderResponse> {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' }
  if (options?.authToken) {
    headers.Authorization = `Bearer ${options.authToken}`
  }

  const res = await fetch(`${API_BASE}/create-order`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      planId: plan.id,
      receipt: buildOrderReceipt(plan.id),
      uid: options?.uid,
    }),
  })

  if (!res.ok) {
    const body = (await res.json().catch(() => ({}))) as { error?: string }
    if (res.status === 404) {
      throw new Error('Payment API not found (404). Check Heroku backend is deployed with Razorpay routes.')
    }
    throw new Error(body.error ?? `Could not create order (${res.status})`)
  }

  return res.json() as Promise<CreateOrderResponse>
}

export async function verifyPayment(
  payload: RazorpaySuccessResponse,
  authToken?: string
): Promise<VerifyPaymentResponse> {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' }
  if (authToken) {
    headers.Authorization = `Bearer ${authToken}`
  }

  const res = await fetch(`${API_BASE}/verify-payment`, {
    method: 'POST',
    headers,
    body: JSON.stringify(payload),
  })

  const body = (await res.json()) as VerifyPaymentResponse
  if (!res.ok || !body.success) {
    throw new Error(body.error ?? 'Payment verification failed')
  }

  return body
}

export function openRazorpayCheckout(params: {
  plan: PricingPlan
  order: CreateOrderResponse
  prefill?: { name?: string; email?: string }
  onSuccess: (response: RazorpaySuccessResponse) => void
  onDismiss?: () => void
  onFailed?: (message: string) => void
}) {
  assertCheckoutReady()

  const key = (params.order.key_id || KEY_ID).trim()
  const orderId = params.order.order_id?.trim() ?? ''
  if (!orderId || !/^order_[A-Za-z0-9]+$/.test(orderId)) {
    throw new Error('Invalid payment order from server. Try again.')
  }
  if (!/^rzp_(test|live)_/.test(key)) {
    throw new Error('Invalid Razorpay key from server. Check backend configuration.')
  }

  const prefill = buildRazorpayPrefill(params.prefill)
  const mobile = isMobileCheckout()

  const amount = Number(params.order.amount)
  if (!Number.isFinite(amount) || amount < 100) {
    throw new Error('Invalid payment amount from server.')
  }

  const rzp = new window.Razorpay!({
    key,
    amount,
    currency: params.order.currency || 'INR',
    name: 'VYOMA',
    description: `${params.plan.name} subscription`,
    order_id: orderId,
    ...(prefill ? { prefill } : {}),
    theme: { color: '#d4af37' },
    method: { ...RAZORPAY_CHECKOUT_METHODS },
    // Advanced display.hide breaks UPI on some mobile WebKit builds.
    ...(!mobile ? { config: { ...RAZORPAY_CHECKOUT_CONFIG } } : {}),
    handler: params.onSuccess,
    modal: {
      ondismiss: params.onDismiss,
    },
  })

  rzp.on('payment.failed', (response) => {
    params.onFailed?.(response.error?.description ?? 'Payment failed')
  })

  rzp.open()
}
