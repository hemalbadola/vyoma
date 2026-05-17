export type PlatformId = 'android' | 'windows' | 'macos'

export type PlatformRelease = {
  label: string
  url: string
  available: boolean
  fileName?: string
}

export type ReleaseManifest = {
  version: string
  releasedAt: string
  releaseNotes: string
  platforms: Record<PlatformId, PlatformRelease>
}

const ENV_URLS: Partial<Record<PlatformId, string | undefined>> = {
  android: import.meta.env.VITE_VYOMA_APK_URL,
  windows: import.meta.env.VITE_VYOMA_WINDOWS_URL,
  macos: import.meta.env.VITE_VYOMA_MAC_URL,
}

/** Version baked in at build time; bump when you ship a new web build. */
export const SITE_BUILD_VERSION =
  import.meta.env.VITE_APP_VERSION ?? import.meta.env.PACKAGE_VERSION ?? '1.0.0'

export function compareVersions(a: string, b: string): number {
  const pa = a.split('.').map((n) => parseInt(n, 10) || 0)
  const pb = b.split('.').map((n) => parseInt(n, 10) || 0)
  const len = Math.max(pa.length, pb.length)
  for (let i = 0; i < len; i += 1) {
    const diff = (pa[i] ?? 0) - (pb[i] ?? 0)
    if (diff !== 0) return diff > 0 ? 1 : -1
  }
  return 0
}

function applyEnvOverrides(manifest: ReleaseManifest): ReleaseManifest {
  const platforms = { ...manifest.platforms }
  for (const id of Object.keys(ENV_URLS) as PlatformId[]) {
    const envUrl = ENV_URLS[id]?.trim()
    if (!envUrl) continue
    platforms[id] = {
      ...platforms[id]!,
      url: envUrl,
      available: true,
    }
  }
  return { ...manifest, platforms }
}

export async function fetchReleaseManifest(): Promise<ReleaseManifest> {
  const res = await fetch(`/releases.json?t=${Date.now()}`, { cache: 'no-store' })
  if (!res.ok) {
    throw new Error(`Failed to load releases.json (${res.status})`)
  }
  const data = (await res.json()) as ReleaseManifest
  return applyEnvOverrides(data)
}
