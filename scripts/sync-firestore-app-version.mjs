#!/usr/bin/env node
/**
 * Write config/app_version in Firestore (triggers broadcastAppUpdate FCM).
 * Requires FIREBASE_SERVICE_ACCOUNT_JSON (GitHub secret).
 *
 * Env: APP_VERSION, RELEASE_NOTES, GITHUB_SHA (optional)
 */
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)
const admin = require(join(dirname(fileURLToPath(import.meta.url)), '../functions/node_modules/firebase-admin'))

const UPDATE_SITE = 'https://vyomai.app'

async function main() {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON
  if (!raw?.trim()) {
    console.log('FIREBASE_SERVICE_ACCOUNT_JSON not set — skipping Firestore sync.')
    process.exit(0)
  }

  const version = process.env.APP_VERSION?.trim()
  if (!version) {
    console.error('APP_VERSION is required')
    process.exit(1)
  }

  const notes = (process.env.RELEASE_NOTES ?? '').trim()
  const sa = JSON.parse(raw)

  if (!admin.apps.length) {
    admin.initializeApp({ credential: admin.credential.cert(sa) })
  }

  await admin
    .firestore()
    .collection('config')
    .doc('app_version')
    .set(
      {
        latest_version: version,
        release_notes: notes || `Update available at ${UPDATE_SITE}`,
        mandatory: false,
        download_url: UPDATE_SITE,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
        source: 'github_actions',
        commit_sha: process.env.GITHUB_SHA ?? null,
      },
      { merge: true },
    )

  console.log(`Firestore config/app_version → v${version}`)
}

main().catch((err) => {
  console.error(err)
  process.exit(1)
})
