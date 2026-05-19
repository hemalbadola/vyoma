import { initializeApp } from 'firebase/app'
import { getAuth } from 'firebase/auth'
import { getFirestore } from 'firebase/firestore'

/** Firebase web client config — set via vyoma-ui/.env (see .env.example). Not secret, but keep out of git. */
function requireEnv(name: string): string {
  const value = (import.meta.env[name] as string | undefined)?.trim()
  if (!value) {
    throw new Error(`Missing ${name}. Copy vyoma-ui/.env.example to vyoma-ui/.env and fill Firebase web config.`)
  }
  return value
}

const firebaseConfig = {
  apiKey: requireEnv('VITE_FIREBASE_API_KEY'),
  authDomain: requireEnv('VITE_FIREBASE_AUTH_DOMAIN'),
  projectId: requireEnv('VITE_FIREBASE_PROJECT_ID'),
  storageBucket: requireEnv('VITE_FIREBASE_STORAGE_BUCKET'),
  messagingSenderId: requireEnv('VITE_FIREBASE_MESSAGING_SENDER_ID'),
  appId: requireEnv('VITE_FIREBASE_APP_ID'),
}

export const app = initializeApp(firebaseConfig)
export const auth = getAuth(app)
export const db = getFirestore(app)
