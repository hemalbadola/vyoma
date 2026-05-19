import { useEffect, useState } from 'react'
import {
  compareVersions,
  fetchReleaseManifest,
  manifestWebVersion,
  SITE_BUILD_VERSION,
} from '../../lib/releases'
import { useAppUpdateNotice } from '../../hooks/useAppUpdateNotice'

const DEFAULT_UPDATE_URL = 'https://vyomai.app'

export default function UpdateBanner() {
  const remoteNotice = useAppUpdateNotice()
  const [manifestMessage, setManifestMessage] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    fetchReleaseManifest()
      .then((manifest) => {
        if (cancelled) return
        const latestWeb = manifestWebVersion(manifest)
        if (compareVersions(latestWeb, SITE_BUILD_VERSION) > 0) {
          setManifestMessage(`A newer web build (v${latestWeb}) is available.`)
        }
      })
      .catch(() => {})
    return () => {
      cancelled = true
    }
  }, [])

  const message = remoteNotice?.message ?? manifestMessage
  if (!message) return null

  const version = remoteNotice?.version
  const updateUrl = remoteNotice?.url ?? DEFAULT_UPDATE_URL

  return (
    <div className="vyoma-update-banner vyoma-update-banner--floating" role="status">
      <span>
        {version ? `Vyoma v${version}: ` : ''}
        {message}
      </span>
      <a
        className="vyoma-update-banner__refresh"
        href={updateUrl}
        target="_blank"
        rel="noopener noreferrer"
      >
        Open vyomai.app
      </a>
    </div>
  )
}
