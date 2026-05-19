import type { Request, Response } from 'express';
import admin from 'firebase-admin';

const STATS_DOC = 'stats/downloads';

export async function getDownloadStats(_req: Request, res: Response): Promise<void> {
  try {
    const snap = await admin.firestore().doc(STATS_DOC).get();
    const data = snap.data() ?? {};
    res.json({
      android: typeof data.android === 'number' ? data.android : 0,
      updatedAt: data.updatedAt?.toDate?.()?.toISOString?.() ?? null,
    });
  } catch (e) {
    console.error('[Stats] read failed:', e);
    res.status(503).json({ error: 'Stats unavailable', android: 0 });
  }
}

export async function recordApkDownload(req: Request, res: Response): Promise<void> {
  try {
    const ref = admin.firestore().doc(STATS_DOC);
    await ref.set(
      {
        android: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastPlatform: 'android',
      },
      { merge: true },
    );
    const snap = await ref.get();
    const total = snap.data()?.android ?? 0;
    console.log(`[Stats] APK download recorded (total ~${total})`);
    res.json({ ok: true, android: total });
  } catch (e) {
    console.error('[Stats] increment failed:', e);
    res.status(503).json({ error: 'Could not record download' });
  }
}
