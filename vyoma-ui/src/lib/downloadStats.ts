const API_BASE =
  import.meta.env.VITE_API_BASE_URL?.replace(/\/$/, '') ||
  'https://vyoma-api-backend-9629c91b8aad.herokuapp.com/api'

export type DownloadStats = {
  android: number
  updatedAt: string | null
}

export async function fetchDownloadStats(): Promise<DownloadStats> {
  const res = await fetch(`${API_BASE}/stats/downloads`, { cache: 'no-store' })
  if (!res.ok) {
    return { android: 0, updatedAt: null }
  }
  const data = (await res.json()) as DownloadStats
  return {
    android: typeof data.android === 'number' ? data.android : 0,
    updatedAt: data.updatedAt ?? null,
  }
}

/** Counts a website download click, then opens the APK URL. */
export async function trackAndOpenApkDownload(apkUrl: string): Promise<void> {
  try {
    await fetch(`${API_BASE}/stats/apk-download`, { method: 'POST' })
  } catch {
    // Still open the APK if stats fail
  }
  window.location.href = apkUrl
}

export function formatDownloadCount(n: number): string {
  return new Intl.NumberFormat('en-US').format(n)
}
