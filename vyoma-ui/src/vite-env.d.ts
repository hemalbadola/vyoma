/// <reference types="vite/client" />

declare global {
  interface ImportMetaEnv {
    readonly VITE_BACKEND_URL?: string
    readonly VITE_RAZORPAY_KEY_ID?: string
    readonly VITE_API_BASE_URL?: string
    readonly VITE_VYOMA_APK_URL?: string
    readonly VITE_VYOMA_WINDOWS_URL?: string
    readonly VITE_VYOMA_MAC_URL?: string
    readonly VITE_APP_VERSION?: string
    readonly VITE_AMBIENT_VOLUME?: string
  }

  interface ImportMeta {
    readonly env: ImportMetaEnv
  }
}
