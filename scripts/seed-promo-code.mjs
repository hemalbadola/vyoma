#!/usr/bin/env node
/**
 * Create a promo code in Firestore (requires Firebase Admin credentials).
 *
 * Usage:
 *   GOOGLE_APPLICATION_CREDENTIALS=path/to/serviceAccount.json \
 *   node scripts/seed-promo-code.mjs VYOMA-VIP-1MONTH
 *
 * Or with Firebase CLI logged in:
 *   node scripts/seed-promo-code.mjs VYOMA-VIP-1MONTH --max 50
 */

import { initializeApp, applicationDefault } from 'firebase-admin/app'
import { getFirestore, FieldValue } from 'firebase-admin/firestore'

const code = process.argv[2]?.trim().toUpperCase().replace(/\s+/g, '-')
const maxIdx = process.argv.indexOf('--max')
const maxRedemptions = maxIdx >= 0 ? Number(process.argv[maxIdx + 1]) || 100 : 100

if (!code) {
  console.error('Usage: node scripts/seed-promo-code.mjs CODE [--max N]')
  process.exit(1)
}

initializeApp({ credential: applicationDefault() })
const db = getFirestore()

await db.collection('promo_codes').doc(code).set({
  type: 'free_month',
  durationDays: 30,
  active: true,
  maxRedemptions,
  redemptionCount: 0,
  note: '1 month free trial for VIP users',
  createdAt: FieldValue.serverTimestamp(),
})

console.log(`Created promo_codes/${code} — ${maxRedemptions} redemptions, 30-day trial`)
