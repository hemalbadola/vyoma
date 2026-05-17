#!/usr/bin/env node
/**
 * Bump patch version in public/releases.json
 * Usage: node scripts/bump-release.mjs [patch|minor|major] "Release notes here"
 */
import { readFileSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const manifestPath = join(__dirname, '../public/releases.json')

const bump = process.argv[2] ?? 'patch'
const notes = process.argv.slice(3).join(' ').trim()

const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'))
const parts = manifest.version.split('.').map((n) => parseInt(n, 10) || 0)

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

manifest.version = parts.join('.')
manifest.releasedAt = new Date().toISOString().slice(0, 10)
if (notes) manifest.releaseNotes = notes

writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`)
console.log(`releases.json → v${manifest.version}`)
