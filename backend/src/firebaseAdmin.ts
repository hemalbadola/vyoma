import admin from 'firebase-admin'

const PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'vyoma-in'

function normalizePrivateKey(raw: string): string {
  return raw.replace(/\\n/g, '\n')
}

function initFromSplitEnv(): boolean {
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL?.trim()
  const privateKey = process.env.FIREBASE_PRIVATE_KEY?.trim()

  if (!clientEmail || !privateKey) {
    return false
  }

  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: PROJECT_ID,
      clientEmail,
      privateKey: normalizePrivateKey(privateKey),
    }),
    projectId: PROJECT_ID,
  })
  console.log('[Firebase] Admin initialized from FIREBASE_CLIENT_EMAIL + FIREBASE_PRIVATE_KEY')
  return true
}

function initFromJsonEnv(): boolean {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON?.trim()
  if (!raw) return false

  admin.initializeApp({
    credential: admin.credential.cert(JSON.parse(raw) as admin.ServiceAccount),
    projectId: PROJECT_ID,
  })
  console.log('[Firebase] Admin initialized from FIREBASE_SERVICE_ACCOUNT_JSON')
  return true
}

export function initFirebaseAdmin(): void {
  if (admin.apps.length > 0) return

  if (initFromJsonEnv() || initFromSplitEnv()) {
    return
  }

  admin.initializeApp({ projectId: PROJECT_ID })
  console.warn(
    '[Firebase] No service account configured. Set FIREBASE_SERVICE_ACCOUNT_JSON or FIREBASE_CLIENT_EMAIL + FIREBASE_PRIVATE_KEY for Firestore writes.'
  )
}
