import Razorpay from 'razorpay'

function requireEnv(name: string): string {
  const value = process.env[name]
  if (!value) {
    throw new Error(`Missing environment variable: ${name}`)
  }
  return value
}

export function getRazorpayKeyId(): string {
  return requireEnv('RAZORPAY_KEY_ID')
}

export function createRazorpayClient(): Razorpay {
  return new Razorpay({
    key_id: getRazorpayKeyId(),
    key_secret: requireEnv('RAZORPAY_KEY_SECRET'),
  })
}
