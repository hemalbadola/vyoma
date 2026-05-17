/**
 * Razorpay Standard Checkout — UPI-first for INR (India).
 * @see https://razorpay.com/docs/payments/payment-gateway/web-integration/standard/configure-payment-methods/
 */
export const RAZORPAY_CHECKOUT_CONFIG = {
  display: {
    blocks: {
      upi: {
        name: 'Pay with UPI',
        instruments: [{ method: 'upi' }],
      },
    },
    sequence: ['block.upi'],
    preferences: {
      show_default_blocks: true,
    },
    hide: [{ method: 'upi', flows: ['collect'] }],
  },
}

/** Legacy method flags — UPI + wallets on; netbanking off. */
export const RAZORPAY_CHECKOUT_METHODS: Record<string, boolean> = {
  upi: true,
  card: true,
  wallet: true,
  netbanking: false,
  emi: false,
  paylater: false,
}
