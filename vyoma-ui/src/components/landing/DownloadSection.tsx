import { useEffect, useState } from 'react'
import {
  compareVersions,
  fetchReleaseManifest,
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

export default function DownloadSection() {
  const [manifest, setManifest] = useState<ReleaseManifest | null>(null)
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

  const latestVersion = manifest?.version ?? SITE_BUILD_VERSION
  const updateAvailable = manifest ? compareVersions(manifest.version, SITE_BUILD_VERSION) > 0 : false

  return (
    <section className="content-section vyoma-download-section" aria-labelledby="download-heading">
      <div className="vyoma-download-section__header">
        <p className="act-label">Downloads</p>
        <h2 id="download-heading" className="vyoma-download-bar__title">
          Get Vyoma on your device
        </h2>
        <p className="vyoma-download-bar__sub">
          Latest release <strong className="accent-gold">v{latestVersion}</strong>
          {manifest?.releasedAt ? ` · ${manifest.releasedAt}` : ''}
        </p>
        {updateAvailable && (
          <p className="vyoma-update-banner" role="status">
            A newer version (v{manifest!.version}) is available — refresh or download the latest build below.
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
                <a href={url} className="vyoma-download-btn" download={id === 'android' ? true : undefined}>
                  Download
                  <span className="vyoma-download-btn__arrow" aria-hidden="true">
                    →
                  </span>
                </a>
              ) : (
                <span className="vyoma-download-soon">Coming soon</span>
              )}
            </div>
          )
        })}
      </div>

      <p className="vyoma-download-footnote">
        To publish a new build: update <code>vyoma-ui/public/releases.json</code>, upload installers to Hosting or
        GitHub Releases, then redeploy.
      </p>
    </section>
  )
}
