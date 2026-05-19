import type { Request, Response } from 'express';
import admin from 'firebase-admin';
import { assertActiveSubscription, SubscriptionRequiredError } from './payments/subscriptionAccess';

export async function requireAuthedUser(
  req: Request,
  res: Response,
): Promise<string | null> {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Unauthorized: Missing or invalid token' });
    return null;
  }

  try {
    const idToken = authHeader.split('Bearer ')[1]!;
    const decoded = await admin.auth().verifyIdToken(idToken);
    if (!decoded.uid) {
      res.status(401).json({ error: 'Unauthorized' });
      return null;
    }
    await assertActiveSubscription(decoded.uid);
    return decoded.uid;
  } catch (e) {
    if (e instanceof SubscriptionRequiredError) {
      res.status(402).json({ error: e.message, code: 'SUBSCRIPTION_REQUIRED' });
      return null;
    }
    console.error('[Auth]', e);
    res.status(401).json({ error: 'Unauthorized' });
    return null;
  }
}
