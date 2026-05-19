import * as admin from 'firebase-admin'
import { onDocumentWritten } from 'firebase-functions/v2/firestore'

const UPDATE_SITE = 'https://vyomai.app'
const TOPIC = 'vyoma_releases'

/**
 * When `config/app_version` is updated (admin / CI), push to all clients on topic vyoma_releases.
 *
 * Document shape:
 * {
 *   latest_version: "1.12.0",
 *   release_notes: "...",
 *   mandatory: false,
 *   download_url: "https://vyomai.app"  // optional
 * }
 */
export const broadcastAppUpdate = onDocumentWritten(
  { document: 'config/app_version', region: 'asia-south1' },
  async (event) => {
    const after = event.data?.after
    if (!after?.exists) return

    const data = after.data()
    if (!data) return

    const version = String(data.latest_version ?? '').trim()
    if (!version) return

    const notes = String(data.release_notes ?? '').trim()
    const body =
      notes.length > 0
        ? notes
        : `Version ${version} is available. Open vyomai.app to update.`

    try {
      await admin.messaging().send({
        topic: TOPIC,
        notification: {
          title: `Vyoma v${version} is available`,
          body,
        },
        data: {
          type: 'app_update',
          version,
          url: String(data.download_url ?? UPDATE_SITE),
        },
        android: { priority: 'high' },
        apns: {
          payload: {
            aps: { sound: 'default' },
          },
        },
      })
      console.log(`[broadcastAppUpdate] sent v${version} to topic ${TOPIC}`)
    } catch (err) {
      console.error('[broadcastAppUpdate]', err)
    }
  },
)
