import { useEffect, useState } from 'react'
import {
  compareVersions,
  fetchReleaseManifest,
  manifestWebVersion,
  SITE_BUILD_VERSION,
} from '../../lib/releases'

export default function UpdateBanner() {
  const [message, setMessage] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    fetchReleaseManifest()
      .then((manifest) => {
        if (cancelled) return
        const latestWeb = manifestWebVersion(manifest)
        if (compareVersions(latestWeb, SITE_BUILD_VERSION) > 0) {
          setMessage(`A newer web build (v${latestWeb}) is available — refresh to update.`)
        }
      })
      .catch(() => {})
    return () => {
      cancelled = true
    }
  }, [])

  if (!message) return null

  return (
    <div className="vyoma-update-banner vyoma-update-banner--floating" role="status">
      <span>{message}</span>
      <button type="button" className="vyoma-update-banner__refresh" onClick={() => window.location.reload()}>
        Refresh now
      </button>
    </div>
  )
}
