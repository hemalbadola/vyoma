export type RazorpaySuccessResponse = {
  razorpay_payment_id: string
  razorpay_order_id: string
  razorpay_signature: string
}

export type RazorpayOptions = {
  key: string
  /** Required without order_id; optional when order_id is set (Razorpay reads amount from order). */
  amount?: number
  currency: string
  name: string
  description?: string
  order_id: string
  prefill?: {
    name?: string
    email?: string
    contact?: string
  }
  theme?: { color?: string }
  config?: {
    display?: {
      blocks?: Record<string, { name: string; instruments: Array<{ method: string }> }>
      sequence?: string[]
      preferences?: { show_default_blocks?: boolean }
      hide?: Array<{ method: string; flows?: string[] }>
    }
  }
  method?: Record<string, boolean>
  handler: (response: RazorpaySuccessResponse) => void
  modal?: {
    ondismiss?: () => void
  }
}

export type RazorpayInstance = {
  open: () => void
  on: (event: 'payment.failed', handler: (response: { error: { description?: string } }) => void) => void
}

declare global {
  interface Window {
    Razorpay?: new (options: RazorpayOptions) => RazorpayInstance
  }
}

export {}
