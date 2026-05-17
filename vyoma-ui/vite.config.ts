import { readFileSync } from 'node:fs'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

const pkg = JSON.parse(readFileSync('./package.json', 'utf8')) as { version: string }

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  define: {
    'import.meta.env.PACKAGE_VERSION': JSON.stringify(pkg.version),
  },
  server: {
    proxy: {
      '/api': {
        target: 'http://127.0.0.1:5001/vyoma-in/asia-south1',
        changeOrigin: true,
        rewrite: (path) => {
          if (path.includes('create-order')) return '/createOrder'
          if (path.includes('verify-payment')) return '/verifyPayment'
          if (path.includes('redeem-coupon')) return '/redeemCoupon'
          return path
        },
      },
    },
  },
})
