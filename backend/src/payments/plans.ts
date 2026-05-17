import plansJson from '../../config/subscription_plans.json'

export type PlanId = 'weekly' | 'monthly' | 'semester'

export type SubscriptionPlan = {
  id: PlanId
  name: string
  priceLabel: string
  cta: string
  amountPaise: number
  durationDays: number
}

const plans = plansJson.plans as SubscriptionPlan[]

export const SUBSCRIPTION_PLANS: Record<PlanId, SubscriptionPlan> = plans.reduce(
  (acc, plan) => {
    acc[plan.id] = plan
    return acc
  },
  {} as Record<PlanId, SubscriptionPlan>
)

export const DEFAULT_CURRENCY = plansJson.currency || 'INR'

export function getPlan(planId: string): SubscriptionPlan | undefined {
  return SUBSCRIPTION_PLANS[planId as PlanId]
}
