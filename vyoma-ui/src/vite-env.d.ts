/// <reference types="vite/client" />

declare global {
  interface ImportMetaEnv {
    readonly VITE_BACKEND_URL?: string
    readonly VITE_RAZORPAY_CHECKOUT_URL?: string
    readonly VITE_RAZORPAY_WEEKLY_URL?: string
    readonly VITE_RAZORPAY_MONTHLY_URL?: string
    readonly VITE_RAZORPAY_SEMESTER_URL?: string
    readonly VITE_VYOMA_APK_URL?: string
    readonly VITE_AMBIENT_VOLUME?: string
  }

  interface ImportMeta {
    readonly env: ImportMetaEnv
  }
}
