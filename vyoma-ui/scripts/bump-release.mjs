#!/usr/bin/env node
/**
 * Bump app + web versions in releases.json and package.json
 * Usage: node scripts/bump-release.mjs [patch|minor|major] "Release notes"
 */
import { readFileSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const manifestPath = join(__dirname, '../public/releases.json')
const packagePath = join(__dirname, '../package.json')

const bump = process.argv[2] ?? 'patch'
const notes = process.argv.slice(3).join(' ').trim()

const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'))
const pkg = JSON.parse(readFileSync(packagePath, 'utf8'))

const current = manifest.appVersion ?? manifest.webVersion ?? manifest.version ?? pkg.version
const parts = current.split('.').map((n) => parseInt(n, 10) || 0)

if (bump === 'major') {
  parts[0] += 1
  parts[1] = 0
  parts[2] = 0
} else if (bump === 'minor') {
  parts[1] += 1
  parts[2] = 0
} else {
  parts[2] += 1
}

const next = parts.join('.')
manifest.appVersion = next
manifest.webVersion = next
delete manifest.version
manifest.releasedAt = new Date().toISOString().slice(0, 10)
if (notes) manifest.releaseNotes = notes

pkg.version = next

writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`)
writeFileSync(packagePath, `${JSON.stringify(pkg, null, 2)}\n`)
console.log(`releases.json + package.json → v${next}`)
