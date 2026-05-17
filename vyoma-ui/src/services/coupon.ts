const HEROKU_API = 'https://vyoma-api-backend-9629c91b8aad.herokuapp.com/api'
const API_BASE = (import.meta.env.VITE_API_BASE_URL ?? HEROKU_API).replace(/\/$/, '')

export type RedeemCouponResponse = {
  success: boolean
  code?: string
  durationDays?: number
  subscriptionPlan?: string
  subscriptionExpiresAt?: string
  error?: string
}

export async function redeemCoupon(code: string, authToken?: string): Promise<RedeemCouponResponse> {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' }
  if (authToken) {
    headers.Authorization = `Bearer ${authToken}`
  }

  const res = await fetch(`${API_BASE}/redeem-coupon`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ code: code.trim() }),
  })

  const body = (await res.json()) as RedeemCouponResponse
  if (!res.ok || !body.success) {
    throw new Error(body.error ?? 'Could not redeem coupon')
  }
  return body
}
