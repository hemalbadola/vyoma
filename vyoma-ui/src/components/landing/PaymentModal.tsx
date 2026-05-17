type PlanId = 'weekly' | 'monthly' | 'semester'

export type PricingPlan = {
  id: PlanId
  name: string
  price: string
  cta: string
  razorpayUrl: string
}

type PaymentModalProps = {
  plan: PricingPlan | null
  onClose: () => void
}

export default function PaymentModal({ plan, onClose }: PaymentModalProps) {
  if (!plan) return null

  const handlePay = () => {
    window.open(plan.razorpayUrl, '_blank', 'noopener,noreferrer')
  }

  return (
    <div className="vyoma-modal-overlay" role="dialog" aria-modal="true" aria-labelledby="payment-modal-title">
      <button type="button" className="vyoma-modal-backdrop" onClick={onClose} aria-label="Close payment modal" />
      <div className="vyoma-modal vyoma-payment-modal">
        <img src="/vyoma-logo.png" alt="" className="vyoma-payment-modal__logo" />
        <p className="vyoma-payment-modal__eyebrow">Complete your subscription</p>
        <h2 id="payment-modal-title" className="vyoma-payment-modal__plan font-cormorant">
          {plan.name}
        </h2>
        <p className="vyoma-payment-modal__price">{plan.price}</p>
        <button type="button" className="vyoma-btn-gold vyoma-payment-modal__pay" onClick={handlePay}>
          Pay with Razorpay
        </button>
        <button type="button" className="vyoma-modal-dismiss" onClick={onClose}>
          Cancel
        </button>
      </div>
    </div>
  )
}
