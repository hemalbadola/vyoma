#!/usr/bin/env node
/**
 * CI-only: unique release tag per workflow run (every push → new GitHub Release).
 * Writes GITHUB_OUTPUT: semver, build_number, release_tag, display_version
 */
import { readFileSync, appendFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const pubspec = readFileSync(join(root, 'pubspec.yaml'), 'utf8')
const m = pubspec.match(/^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+(\d+))?/m)
if (!m) throw new Error('Could not parse pubspec version')

const semver = m[1]
const pubspecBuild = parseInt(m[2] ?? '0', 10)
const runBuild = parseInt(process.env.GITHUB_RUN_NUMBER ?? '0', 10)
const buildNumber = Math.max(pubspecBuild, runBuild, 1)
const releaseTag = `v${semver}-build.${buildNumber}`
const displayVersion = `${semver}+${buildNumber}`

console.log(`Release tag: ${releaseTag} (display ${displayVersion})`)

if (process.env.GITHUB_OUTPUT) {
  const out = process.env.GITHUB_OUTPUT
  appendFileSync(out, `semver=${semver}\n`)
  appendFileSync(out, `build_number=${buildNumber}\n`)
  appendFileSync(out, `release_tag=${releaseTag}\n`)
  appendFileSync(out, `display_version=${displayVersion}\n`)
}
