import { useEffect, useState } from 'react'
import { doc, onSnapshot } from 'firebase/firestore'
import { onAuthStateChanged } from 'firebase/auth'
import { auth, db } from '../firebase'
import { compareVersions, SITE_BUILD_VERSION } from '../lib/releases'

const UPDATE_SITE = 'https://vyomai.app'

export type AppUpdateNotice = {
  version: string
  message: string
  url: string
}

/**
 * Listens to Firestore config/app_version (same as Flutter) and surfaces update UI on the web.
 */
export function useAppUpdateNotice(): AppUpdateNotice | null {
  const [notice, setNotice] = useState<AppUpdateNotice | null>(null)

  useEffect(() => {
    let unsubDoc: (() => void) | undefined

    const unsubAuth = onAuthStateChanged(auth, (user) => {
      unsubDoc?.()
      unsubDoc = undefined
      if (!user) {
        setNotice(null)
        return
      }

      unsubDoc = onSnapshot(doc(db, 'config', 'app_version'), (snap) => {
        if (!snap.exists()) return
        const data = snap.data()
        const latest = String(data.latest_version ?? '').trim()
        if (!latest) return
        if (compareVersions(latest, SITE_BUILD_VERSION) <= 0) return

        const notes = String(data.release_notes ?? '').trim()
        setNotice({
          version: latest,
          message:
            notes.length > 0
              ? notes
              : `Version ${latest} is available.`,
          url: String(data.download_url ?? UPDATE_SITE),
        })
      })
    })

    return () => {
      unsubAuth()
      unsubDoc?.()
    }
  }, [])

  return notice
}
