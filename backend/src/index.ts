import express from 'express';
import cors from 'cors';
import { GoogleGenerativeAI } from '@google/generative-ai';
import admin from 'firebase-admin';

// Initialize Firebase Admin (uses explicit projectId for verifyIdToken)
admin.initializeApp({
  projectId: 'vyoma-in'
});

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

    // 3. Forward request directly to Gemini API
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      console.error('Server configuration error: GEMINI_API_KEY not found');
      return res.status(500).json({ error: 'Server configuration error' });
    }

    const { modelName = 'gemini-2.5-flash' } = req.body;
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${apiKey}`;

    const geminiRes = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(req.body.payload || req.body),
    });

    const data = await geminiRes.json();
    res.status(geminiRes.status).json(data);

  } catch (error) {
    console.error('API Error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
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

  } catch (error) {
    console.error('Nvidia API Error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// API endpoint for Grok
app.post('/api/grok/generate', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Unauthorized: Missing or invalid token' });
    }

    const idToken = authHeader.split('Bearer ')[1];
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    if (!decodedToken.uid) return res.status(401).json({ error: 'Unauthorized' });

    const apiKey = process.env.GROK_API_KEY;
    if (!apiKey) return res.status(500).json({ error: 'Server configuration error' });

    const grokRes = await fetch('https://api.x.ai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`
      },
      body: JSON.stringify(req.body),
    });

    const data = await grokRes.json();
    res.status(grokRes.status).json(data);

  } catch (error) {
    console.error('Grok API Error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

app.get('/health', (req, res) => {
    res.json({ status: 'ok', version: '1.0.0' });
});

app.listen(port, () => {
  console.log(`Vyoma Backend running on port ${port}`);
});
