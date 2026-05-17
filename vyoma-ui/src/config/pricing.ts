import type { PricingPlan } from '../components/landing/PaymentModal'

const RAZORPAY_BASE = import.meta.env.VITE_RAZORPAY_CHECKOUT_URL ?? 'https://razorpay.com/payment-button/plc_placeholder'

export const PRICING_PLANS: PricingPlan[] = [
  {
    id: 'weekly',
    name: 'Weekly',
    price: '₹29 / week',
    cta: 'Start this week',
    razorpayUrl: import.meta.env.VITE_RAZORPAY_WEEKLY_URL ?? RAZORPAY_BASE,
  },
  {
    id: 'monthly',
    name: 'Monthly',
    price: '₹99 / month',
    cta: 'Start free—14 days',
    razorpayUrl: import.meta.env.VITE_RAZORPAY_MONTHLY_URL ?? RAZORPAY_BASE,
  },
  {
    id: 'semester',
    name: 'Semester',
    price: '₹449 / 6 months',
    cta: 'Start free—14 days',
    razorpayUrl: import.meta.env.VITE_RAZORPAY_SEMESTER_URL ?? RAZORPAY_BASE,
  },
]
