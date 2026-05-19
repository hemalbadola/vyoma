import { useCallback, useState } from 'react'
import { auth } from '../../firebase'
import { useAuth } from '../../contexts/AuthContext'
import { redeemCoupon } from '../../services/coupon'
import { createOrder, openRazorpayCheckout, verifyPayment } from '../../services/razorpay'
import type { RazorpaySuccessResponse } from '../../types/razorpay'

type PlanId = 'weekly' | 'monthly' | 'semester'

export type PricingPlan = {
  id: PlanId
  name: string
  price: string
  cta: string
  amountPaise: number
  durationDays: number
}

type PaymentModalProps = {
  plan: PricingPlan | null
  onClose: () => void
  onSuccess?: (plan: PricingPlan) => void
}

export default function PaymentModal({ plan, onClose, onSuccess }: PaymentModalProps) {
  const { user, getApiToken } = useAuth()
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState(false)
  const [couponCode, setCouponCode] = useState('')
  const [redeeming, setRedeeming] = useState(false)
  const [couponExpiry, setCouponExpiry] = useState<string | null>(null)

  const handlePay = useCallback(async () => {
    if (!plan) return
    setError(null)
    setLoading(true)

    try {
      const authToken = await getApiToken()
      const order = await createOrder(plan, { uid: user?.uid, authToken })
      setLoading(false)

      openRazorpayCheckout({
        plan,
        order,
        prefill: {
          name: user?.displayName ?? undefined,
          email: user?.email ?? undefined,
        },
        onSuccess: async (response: RazorpaySuccessResponse) => {
          setLoading(true)
          setError(null)
          try {
            await verifyPayment(response, authToken)
            await auth.currentUser?.getIdToken(true)
            setSuccess(true)
            onSuccess?.(plan)
          } catch (err) {
            setError(err instanceof Error ? err.message : 'Verification failed')
          } finally {
            setLoading(false)
          }
        },
        onDismiss: () => {
          setError('Payment cancelled')
        },
        onFailed: (message) => {
          setError(message)
        },
      })
    } catch (err) {
      setLoading(false)
      setError(err instanceof Error ? err.message : 'Could not start checkout')
    }
  }, [plan, user, getApiToken, onSuccess])

  const handleRedeemCoupon = useCallback(async () => {
    if (!couponCode.trim()) {
      setError('Enter a coupon code')
      return
    }
    if (!user) {
      setError('Sign in to redeem a coupon (use the app or /login)')
      return
    }
    setRedeeming(true)
    setError(null)
    try {
      const authToken = await getApiToken()
      const result = await redeemCoupon(couponCode, authToken)
      await auth.currentUser?.getIdToken(true)
      setSuccess(true)
      setError(null)
      if (result.subscriptionExpiresAt) setCouponExpiry(result.subscriptionExpiresAt)
      if (plan) onSuccess?.(plan)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not redeem coupon')
    } finally {
      setRedeeming(false)
    }
  }, [couponCode, user, getApiToken, plan, onSuccess])

  if (!plan) return null

  return (
    <div className="vyoma-modal-overlay" role="dialog" aria-modal="true" aria-labelledby="payment-modal-title">
      <button type="button" className="vyoma-modal-backdrop" onClick={onClose} aria-label="Close payment modal" />
      <div className="vyoma-modal vyoma-payment-modal">
        <img src="/vyomaicon.png" alt="" className="vyoma-payment-modal__logo" />
        <p className="vyoma-payment-modal__eyebrow">Complete your subscription</p>
        <h2 id="payment-modal-title" className="vyoma-payment-modal__plan font-cormorant">
          {plan.name}
        </h2>
        <p className="vyoma-payment-modal__price">{plan.price}</p>
        {success ? (
          <p className="vyoma-payment-modal__success">
            {couponExpiry
              ? `Coupon applied — access until ${new Date(couponExpiry).toLocaleDateString()}.`
              : 'Payment verified. Welcome to Vyoma.'}
          </p>
        ) : (
          <>
            <button
              type="button"
              className="vyoma-btn-gold vyoma-payment-modal__pay"
              onClick={handlePay}
              disabled={loading || redeeming}
            >
              {loading ? 'Processing…' : 'Pay with Razorpay'}
            </button>
            <div className="vyoma-payment-modal__coupon">
              <input
                type="text"
                className="vyoma-payment-modal__coupon-input"
                placeholder="Coupon code"
                value={couponCode}
                onChange={(e) => setCouponCode(e.target.value.toUpperCase())}
                disabled={redeeming}
              />
              <button
                type="button"
                className="vyoma-payment-modal__coupon-btn"
                onClick={handleRedeemCoupon}
                disabled={redeeming || loading}
              >
                {redeeming ? 'Applying…' : 'Redeem 1-month trial'}
              </button>
            </div>
          </>
        )}
        {error && <p className="vyoma-payment-modal__error">{error}</p>}
        <button type="button" className="vyoma-modal-dismiss" onClick={onClose}>
          {success ? 'Close' : 'Cancel'}
        </button>
      </div>
    </div>
  )
}
