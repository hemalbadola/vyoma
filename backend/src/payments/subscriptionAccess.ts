import admin from 'firebase-admin'

export class SubscriptionRequiredError extends Error {
  status = 402
  constructor(message = 'Active subscription required') {
    super(message)
    this.name = 'SubscriptionRequiredError'
  }
}

export function isSubscriptionActive(data: FirebaseFirestore.DocumentData | undefined): boolean {
  if (!data) return false
  if (data.subscriptionStatus !== 'active') return false
  const exp = data.subscriptionExpiresAt
  if (!exp || typeof (exp as { toDate?: () => Date }).toDate !== 'function') return false
  return (exp as FirebaseFirestore.Timestamp).toDate() > new Date()
}

export async function assertActiveSubscription(uid: string): Promise<void> {
  const snap = await admin.firestore().collection('users').doc(uid).get()
  if (!isSubscriptionActive(snap.data())) {
    throw new SubscriptionRequiredError()
  }
}

export async function syncSubscriptionClaims(uid: string): Promise<void> {
  const snap = await admin.firestore().collection('users').doc(uid).get()
  const data = snap.data()
  const active = isSubscriptionActive(data)
  const expiresAt = data?.subscriptionExpiresAt
  await admin.auth().setCustomUserClaims(uid, {
    subscriptionActive: active,
    subscriptionPlan: active ? (data?.subscriptionPlan as string) ?? null : null,
    subscriptionExpiresAt:
      expiresAt && typeof (expiresAt as { toDate?: () => Date }).toDate === 'function'
        ? (expiresAt as FirebaseFirestore.Timestamp).toDate().toISOString()
        : null,
  })
}
