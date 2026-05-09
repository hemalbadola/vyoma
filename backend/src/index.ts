import express from 'express';
import cors from 'cors';
import { GoogleGenerativeAI } from '@google/generative-ai';
import admin from 'firebase-admin';

// Initialize Firebase Admin with explicit projectId for Heroku
// (applicationDefault() fails on Heroku — no GOOGLE_APPLICATION_CREDENTIALS file)
// verifyIdToken() only needs projectId to validate JWTs against Google's public keys.
admin.initializeApp({
  projectId: 'vyoma-in',
});

let geminiKeyIndex = 0;

function getNextGeminiKey(): string {
  const envKeys = process.env.GEMINI_API_KEYS || '';
  let keys = envKeys.split(',').map((k: string) => k.trim()).filter((k: string) => k.length > 0);
  
  if (keys.length === 0) {
    // Fallback to initial hardcoded set if environment variables are not yet configured in Heroku Dashboard
    keys = [
      'REDACTED',
      'REDACTED',
      'REDACTED',
      'REDACTED',
      'REDACTED',
      'REDACTED',
      'REDACTED',
      'REDACTED',
      'REDACTED',
      'REDACTED',
      'REDACTED',
      'REDACTED',
      'REDACTED',
      'REDACTED',
      'REDACTED',
      'REDACTED',
      'REDACTED',
      'REDACTED',
      'REDACTED',
      'REDACTED',
    ];
  }

  if (geminiKeyIndex >= keys.length) {
    geminiKeyIndex = 0;
  }

  const key = keys[geminiKeyIndex];
  geminiKeyIndex = (geminiKeyIndex + 1) % keys.length;
  
  console.log(`[Gemini Rotator] Executed key index \${geminiKeyIndex - 1}`);
  return key;
}

const app = express();
app.use(cors());
// 25MB ceiling so vision requests with base64 images don't 413.
// Express default is 100KB which is < a single base64-encoded screenshot.
app.use(express.json({ limit: '25mb' }));

const port = process.env.PORT || 3000;

// Example API endpoint for Gemini
app.post('/api/gemini/generate', async (req, res) => {
  try {
    // 1. Require Authentication Header
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Unauthorized: Missing or invalid token' });
    }

    // 2. Verify Firebase Token
    const idToken = authHeader.split('Bearer ')[1];
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const userId = decodedToken.uid;

    if (!userId) {
        return res.status(401).json({ error: 'Unauthorized: Invalid token user' });
    }

    // 3. Forward request to Gemini API with key retry on bad keys
    const { modelName = 'gemini-2.5-flash' } = req.body;
    const maxRetries = 3;

    for (let attempt = 0; attempt < maxRetries; attempt++) {
      const apiKey = getNextGeminiKey();
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${apiKey}`;

      const geminiRes = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(req.body.payload || req.body),
      });

      const data: any = await geminiRes.json();

      // If Gemini says key is invalid, try next key
      if (geminiRes.status === 400 || geminiRes.status === 403) {
        const errMsg = data?.error?.message || '';
        if (errMsg.includes('API key not valid') || errMsg.includes('API_KEY_INVALID')) {
          console.warn(`[Gemini] Bad key on attempt ${attempt + 1}, rotating...`);
          continue;
        }
      }

      return res.status(geminiRes.status).json(data);
    }

    return res.status(502).json({ error: 'All Gemini key attempts failed' });

  } catch (error: any) {
    console.error('API Error:', error);
    const msg = error?.message || String(error);
    res.status(500).json({ error: 'Internal Server Error', detail: msg });
  }
});

// API endpoint for Nvidia
app.post('/api/nvidia/generate', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Unauthorized: Missing or invalid token' });
    }

    const idToken = authHeader.split('Bearer ')[1];
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    if (!decodedToken.uid) return res.status(401).json({ error: 'Unauthorized' });

    const apiKey = process.env.NVIDIA_API_KEY;
    if (!apiKey) return res.status(500).json({ error: 'Server configuration error' });

    const nvidiaRes = await fetch('https://integrate.api.nvidia.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`
      },
      body: JSON.stringify(req.body),
    });

    const data = await nvidiaRes.json();
    res.status(nvidiaRes.status).json(data);

  } catch (error: any) {
    console.error('Nvidia API Error:', error);
    const msg = error?.message || String(error);
    res.status(500).json({ error: 'Internal Server Error', detail: msg });
  }
});
// Supermemory Secure Proxy
app.use('/api/supermemory', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Unauthorized: Missing or invalid token' });
    }

    const idToken = authHeader.split('Bearer ')[1];
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const userId = decodedToken.uid;
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });

    const apiKey = process.env.VYOMA_SUPERMEMORY_API_KEY || process.env.SUPERMEMORY_API_KEY;
    if (!apiKey) return res.status(500).json({ error: 'Supermemory key not configured on server' });

    // In app.use, req.path is relative to the mount point (e.g. '/documents')
    const targetUrl = `https://api.supermemory.ai/v3${req.path}`;

    const fetchHeaders: any = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`,
      'x-sm-project': `vyoma_${userId}`
    };

    const fetchOptions: any = {
      method: req.method,
      headers: fetchHeaders,
    };

    if (req.method !== 'GET' && req.method !== 'HEAD' && Object.keys(req.body).length > 0) {
      fetchOptions.body = JSON.stringify(req.body);
    }
    
    // Support query parameters
    const queryStr = new URLSearchParams(req.query as any).toString();
    const finalUrl = queryStr ? `${targetUrl}?${queryStr}` : targetUrl;

    const smRes = await fetch(finalUrl, fetchOptions);
    const textData = await smRes.text();
    let data;
    try {
      data = JSON.parse(textData);
    } catch {
      data = { message: textData };
    }

    return res.status(smRes.status).json(data);

  } catch (error: any) {
    console.error('Supermemory Proxy Error:', error);
    const msg = error?.message || String(error);
    return res.status(500).json({ error: 'Internal Server Error', detail: msg });
  }
});

app.get('/health', (req, res) => {
    res.json({ status: 'ok', version: '1.0.1' });
});

app.listen(port, () => {
  console.log(`Vyoma Backend running on port ${port}`);
});
