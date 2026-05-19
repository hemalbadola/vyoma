#!/usr/bin/env node
/**
 * Sync vyoma-ui/public/releases.json (and package.json) from pubspec.yaml + git message.
 *
 * Env:
 *   RELEASE_NOTES  — override notes (e.g. GitHub Release body)
 *   GITHUB_COMMIT_MESSAGE — set by Actions
 *   APP_VERSION — override semver (default: pubspec name before +)
 */
import { execSync } from 'node:child_process'
import { appendFileSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const pubspecPath = join(root, 'pubspec.yaml')
const manifestPath = join(root, 'vyoma-ui/public/releases.json')
const packagePath = join(root, 'vyoma-ui/package.json')

function readPubspecVersion() {
  const text = readFileSync(pubspecPath, 'utf8')
  const m = text.match(/^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+(\d+))?/m)
  if (!m) throw new Error('Could not parse version from pubspec.yaml')
  return { semver: m[1], build: m[2] ?? null }
}

function readGitCommitMessage() {
  if (process.env.RELEASE_NOTES?.trim()) {
    return process.env.RELEASE_NOTES.trim()
  }
  if (process.env.GITHUB_COMMIT_MESSAGE?.trim()) {
    return sanitizeCommitMessage(process.env.GITHUB_COMMIT_MESSAGE)
  }
  try {
    return sanitizeCommitMessage(
      execSync('git log -1 --format=%B', { cwd: root, encoding: 'utf8' }),
    )
  } catch {
    return ''
  }
}

/** Drop merge boilerplate; use first non-empty paragraph. */
function sanitizeCommitMessage(raw) {
  let text = raw.trim()
  if (text.startsWith('Merge ')) {
    const lines = text.split('\n').map((l) => l.trim()).filter(Boolean)
    text = lines.length > 1 ? lines.slice(1).join('\n') : text
  }
  const para = text.split(/\n\n+/).find((p) => p.trim().length > 0) ?? text
  return para.trim().slice(0, 500)
}

function main() {
  const { semver } = readPubspecVersion()
  const buildNumber = process.env.BUILD_NUMBER?.trim()
  const releaseTag = process.env.RELEASE_TAG?.trim()
  const version =
    process.env.DISPLAY_VERSION?.trim() ||
    process.env.APP_VERSION?.trim() ||
    (buildNumber ? `${semver}+${buildNumber}` : semver)
  const notes = readGitCommitMessage()

  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'))
  const pkg = JSON.parse(readFileSync(packagePath, 'utf8'))

  const prev = manifest.appVersion ?? manifest.webVersion ?? manifest.version
  manifest.appVersion = version
  manifest.webVersion = version
  delete manifest.version
  if (buildNumber) manifest.buildNumber = parseInt(buildNumber, 10)
  if (releaseTag) manifest.releaseTag = releaseTag
  manifest.releasedAt = new Date().toISOString().slice(0, 10)
  if (notes) manifest.releaseNotes = notes
  manifest.source = 'github'
  if (process.env.GITHUB_SHA) manifest.commitSha = process.env.GITHUB_SHA

  const tagForUrl = releaseTag || `v${semver}`
  const androidUrl =
    process.env.ANDROID_DOWNLOAD_URL?.trim() ||
    (process.env.GITHUB_REPOSITORY
      ? `https://github.com/${process.env.GITHUB_REPOSITORY}/releases/download/${tagForUrl}/vyoma.apk`
      : '')
  if (androidUrl && manifest.platforms?.android) {
    manifest.platforms.android.url = androidUrl
    manifest.platforms.android.available = true
    manifest.platforms.android.fileName = 'vyoma.apk'
  }

  pkg.version = version

  writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`)
  writeFileSync(packagePath, `${JSON.stringify(pkg, null, 2)}\n`)

  console.log(`Synced releases.json → v${version} (was v${prev ?? '?'})`)
  if (notes) console.log(`Release notes: ${notes.slice(0, 120)}${notes.length > 120 ? '…' : ''}`)

  if (process.env.GITHUB_OUTPUT) {
    appendFileSync(process.env.GITHUB_OUTPUT, `app_version=${version}\n`)
    if (releaseTag) appendFileSync(process.env.GITHUB_OUTPUT, `release_tag=${releaseTag}\n`)
  }
}

main()
