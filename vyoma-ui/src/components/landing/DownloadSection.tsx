import { useEffect, useState, type MouseEvent } from 'react'
import {
  fetchDownloadStats,
  formatDownloadCount,
  trackAndOpenApkDownload,
  type DownloadStats,
} from '../../lib/downloadStats'
import {
  fetchReleaseManifest,
  manifestAppVersion,
  SITE_BUILD_VERSION,
  type PlatformId,
  type ReleaseManifest,
} from '../../lib/releases'

const PLATFORM_ORDER: PlatformId[] = ['android', 'windows', 'macos']

const PLATFORM_HINT: Record<PlatformId, string> = {
  android: 'APK · Sideload',
  windows: 'Windows 10+',
  macos: 'Apple Silicon & Intel',
}

const showDownloadStats = import.meta.env.VITE_SHOW_DOWNLOAD_STATS !== 'false'

export default function DownloadSection() {
  const [manifest, setManifest] = useState<ReleaseManifest | null>(null)
  const [stats, setStats] = useState<DownloadStats | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    fetchReleaseManifest()
      .then((data) => {
        if (!cancelled) setManifest(data)
      })
      .catch((err: unknown) => {
        if (!cancelled) {
          setError(err instanceof Error ? err.message : 'Could not load release info')
        }
      })
    return () => {
      cancelled = true
    }
  }, [])

  useEffect(() => {
    if (!showDownloadStats) return
    let cancelled = false
    fetchDownloadStats()
      .then((data) => {
        if (!cancelled) setStats(data)
      })
      .catch(() => {
        if (!cancelled) setStats({ android: 0, updatedAt: null })
      })
    return () => {
      cancelled = true
    }
  }, [])

  const latestApp = manifest ? manifestAppVersion(manifest) : SITE_BUILD_VERSION

  const handleAndroidDownload = (url: string) => (e: MouseEvent) => {
    e.preventDefault()
    void trackAndOpenApkDownload(url)
  }

  return (
    <section className="content-section vyoma-download-section" aria-labelledby="download-heading">
      <div className="vyoma-download-section__header">
        <p className="act-label">Downloads</p>
        <h2 id="download-heading" className="vyoma-download-bar__title">
          Get Vyoma on your device
        </h2>
        <p className="vyoma-download-bar__sub">
          Latest app release <strong className="accent-gold">v{latestApp}</strong>
          {manifest?.releasedAt ? ` · ${manifest.releasedAt}` : ''}
        </p>
        {showDownloadStats && stats != null && (
          <p className="vyoma-download-stats" role="status">
            <span className="vyoma-download-stats__value">{formatDownloadCount(stats.android)}</span>
            {' '}total APK downloads from vyomai.app
          </p>
        )}
        {manifest?.releaseNotes && (
          <p className="vyoma-download-release-notes">{manifest.releaseNotes}</p>
        )}
        {error && <p className="vyoma-download-error">{error}</p>}
      </div>

      <div className="vyoma-download-grid">
        {PLATFORM_ORDER.map((id) => {
          const platform = manifest?.platforms[id]
          const label = platform?.label ?? (id === 'macos' ? 'macOS' : id.charAt(0).toUpperCase() + id.slice(1))
          const available = platform?.available && Boolean(platform.url)
          const url = platform?.url ?? '#'

          return (
            <div key={id} className={`vyoma-download-card${available ? '' : ' vyoma-download-card--soon'}`}>
              <span className="vyoma-download-card__platform">{label}</span>
              <span className="vyoma-download-card__hint">{PLATFORM_HINT[id]}</span>
              {available ? (
                id === 'android' ? (
                  <a
                    href={url}
                    className="vyoma-download-btn"
                    onClick={handleAndroidDownload(url)}
                  >
                    Download
                    <span className="vyoma-download-btn__arrow" aria-hidden="true">
                      →
                    </span>
                  </a>
                ) : (
                  <a href={url} className="vyoma-download-btn" download>
                    Download
                    <span className="vyoma-download-btn__arrow" aria-hidden="true">
                      →
                    </span>
                  </a>
                )
              ) : (
                <span className="vyoma-download-soon">Coming soon</span>
              )}
            </div>
          )
        })}
      </div>

      <p className="vyoma-download-footnote">
        Every push to <code>main</code> builds a new APK and updates this page automatically.
      </p>
    </section>
  )
}
