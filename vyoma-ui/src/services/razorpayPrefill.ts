/** Razorpay prefill values must match strict patterns on mobile Safari. */

export type RazorpayPrefillInput = {
  name?: string | null
  email?: string | null
  contact?: string | null
}

export type RazorpayPrefill = {
  name?: string
  email?: string
  contact?: string
}

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

/** E.164 India: +91 followed by 10 digits (Razorpay checkout expectation). */
export function formatIndiaContact(phone?: string | null): string | undefined {
  if (!phone?.trim()) return undefined
  const digits = phone.replace(/\D/g, '')
  if (digits.length < 10) return undefined
  const local = digits.length > 10 ? digits.slice(-10) : digits
  if (!/^\d{10}$/.test(local)) return undefined
  return `+91${local}`
}

export function buildRazorpayPrefill(input?: RazorpayPrefillInput): RazorpayPrefill | undefined {
  if (!input) return undefined

  const prefill: RazorpayPrefill = {}
  const name = input.name?.trim()
  if (name) prefill.name = name

  const email = input.email?.trim()
  if (email && EMAIL_RE.test(email)) prefill.email = email

  const contact = formatIndiaContact(input.contact)
  if (contact) prefill.contact = contact

  return Object.keys(prefill).length > 0 ? prefill : undefined
}

/** Receipt: max 40 chars, alphanumeric only (Razorpay validation). */
export function buildOrderReceipt(planId: string): string {
  const base = `vyoma${planId.replace(/[^a-z0-9]/gi, '')}${Date.now()}`
  return base.slice(0, 40)
}
