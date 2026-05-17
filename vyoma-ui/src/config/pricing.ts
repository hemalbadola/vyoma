import type { PricingPlan } from '../components/landing/PaymentModal'
import plansJson from './subscription_plans.json'

export const PRICING_PLANS: PricingPlan[] = plansJson.plans.map((plan) => ({
  id: plan.id as PricingPlan['id'],
  name: plan.name,
  price: plan.priceLabel,
  cta: plan.cta,
  amountPaise: plan.amountPaise,
  durationDays: plan.durationDays,
}))
