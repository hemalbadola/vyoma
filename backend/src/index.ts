import express from 'express';
import cors from 'cors';
import { initFirebaseAdmin } from './firebaseAdmin';
import { paymentRouter } from './payments/razorpayRoutes';
import { generateWithProviderPriority } from './aiProvider';
import { getGeminiKeys, getNvidiaKeys } from './aiKeys';
import { requireAuthedUser } from './requireAuth';
import { getDownloadStats, recordApkDownload } from './downloadStats';
import { GEMINI_MODEL, NIM_TEXT_MODELS, NIM_VISION_MODELS } from './nimConfig';
import { nextGeminiKey } from './aiKeys';
import { isRetryableProviderError } from './apiKeyPool';

initFirebaseAdmin();

const app = express();
app.use(cors());
app.use(express.json({ limit: '25mb' }));

const port = process.env.PORT || 3000;

app.get('/api/stats/downloads', getDownloadStats);
app.post('/api/stats/apk-download', recordApkDownload);

/**
 * Unified AI gateway: NVIDIA (all keys, model fallbacks) → Gemini (all keys).
 * Add keys in Heroku only — comma-separated NVIDIA_API_KEYS / GEMINI_API_KEYS.
 */
app.post('/api/ai/generate', async (req, res) => {
  try {
    const uid = await requireAuthedUser(req, res);
    if (!uid) return;

    const { textPrompt, imageBase64, imageMimeType } = req.body ?? {};
    if (!textPrompt || typeof textPrompt !== 'string') {
      return res.status(400).json({ error: 'textPrompt is required' });
    }

    const result = await generateWithProviderPriority({
      textPrompt,
      imageBase64: typeof imageBase64 === 'string' ? imageBase64 : undefined,
      imageMimeType: typeof imageMimeType === 'string' ? imageMimeType : 'image/jpeg',
    });

    if (result.ok) {
      return res.json({
        provider: result.provider,
        model: result.model,
        text: result.text,
      });
    }

    return res.status(result.status).json({
      error: result.error,
      nvidiaAttempts: result.nvidiaAttempts,
      geminiAttempts: result.geminiAttempts,
    });
  } catch (error: any) {
    console.error('[AI] Error:', error);
    res.status(500).json({ error: 'Internal Server Error', detail: error?.message });
  }
});

/** @deprecated Prefer POST /api/ai/generate — kept for older app builds. */
app.post('/api/nvidia/generate', async (req, res) => {
  try {
    const uid = await requireAuthedUser(req, res);
    if (!uid) return;

    const messages = req.body?.messages;
    const model = req.body?.model;
    if (!Array.isArray(messages) || !model) {
      return res.status(400).json({ error: 'model and messages required' });
    }

    let textPrompt = '';
    let imageBase64: string | undefined;
    for (const msg of messages) {
      const content = msg?.content;
      if (typeof content === 'string') {
        textPrompt = content;
      } else if (Array.isArray(content)) {
        for (const part of content) {
          if (part?.type === 'text') textPrompt = part.text ?? textPrompt;
          if (part?.type === 'image_url') {
            const url = part.image_url?.url ?? '';
            const match = url.match(/^data:[^;]+;base64,(.+)$/);
            if (match) imageBase64 = match[1];
          }
        }
      }
    }

    const result = await generateWithProviderPriority({
      textPrompt,
      imageBase64,
    });

    if (result.ok && result.provider === 'nvidia') {
      return res.json({
        choices: [{ message: { role: 'assistant', content: result.text } }],
        model: result.model,
      });
    }

    return res.status(502).json({ error: 'NVIDIA unavailable', detail: result });
  } catch (error: any) {
    res.status(500).json({ error: error?.message });
  }
});

/** @deprecated Prefer POST /api/ai/generate */
app.post('/api/gemini/generate', async (req, res) => {
  try {
    const uid = await requireAuthedUser(req, res);
    if (!uid) return;

    const keys = getGeminiKeys();
    if (keys.length === 0) {
      return res.status(503).json({ error: 'Gemini API not configured on server' });
    }

    const { modelName = GEMINI_MODEL } = req.body;
    const maxRetries = Math.min(keys.length * 2, 8);

    for (let attempt = 0; attempt < maxRetries; attempt++) {
      const apiKey = nextGeminiKey();
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${apiKey}`;

      const geminiRes = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(req.body.payload || req.body),
      });

      const data: any = await geminiRes.json();

      if (geminiRes.ok) return res.status(geminiRes.status).json(data);

      if (isRetryableProviderError(geminiRes.status, data)) {
        console.warn(`[Gemini] ${geminiRes.status} attempt ${attempt + 1}, rotating…`);
        continue;
      }

      const errMsg = data?.error?.message || '';
      if (
        (geminiRes.status === 400 || geminiRes.status === 403) &&
        String(errMsg).toLowerCase().includes('api key')
      ) {
        continue;
      }

      return res.status(geminiRes.status).json(data);
    }

    return res.status(502).json({ error: 'All Gemini key attempts failed' });
  } catch (error: any) {
    res.status(500).json({ error: error?.message });
  }
});

app.use('/api/supermemory', async (req, res) => {
  try {
    const uid = await requireAuthedUser(req, res);
    if (!uid) return;

    const apiKey = process.env.VYOMA_SUPERMEMORY_API_KEY || process.env.SUPERMEMORY_API_KEY;
    if (!apiKey) return res.status(500).json({ error: 'Supermemory key not configured on server' });

    const targetUrl = `https://api.supermemory.ai/v3${req.path}`;
    const fetchHeaders: Record<string, string> = {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
      'x-sm-project': `vyoma_${uid}`,
    };

    const fetchOptions: RequestInit = { method: req.method, headers: fetchHeaders };
    if (req.method !== 'GET' && req.method !== 'HEAD' && Object.keys(req.body).length > 0) {
      fetchOptions.body = JSON.stringify(req.body);
    }

    const queryStr = new URLSearchParams(req.query as Record<string, string>).toString();
    const finalUrl = queryStr ? `${targetUrl}?${queryStr}` : targetUrl;

    const smRes = await fetch(finalUrl, fetchOptions);
    const textData = await smRes.text();
    let data: unknown;
    try {
      data = JSON.parse(textData);
    } catch {
      data = { message: textData };
    }

    return res.status(smRes.status).json(data);
  } catch (error: any) {
    res.status(500).json({ error: error?.message });
  }
});

app.use('/api', paymentRouter);

app.get('/health', (_req, res) => {
  res.json({
    status: 'ok',
    version: '1.1.0',
    ai: {
      nvidiaKeys: getNvidiaKeys().length,
      geminiKeys: getGeminiKeys().length,
      nimTextModels: NIM_TEXT_MODELS,
      nimVisionModels: NIM_VISION_MODELS,
      geminiModel: GEMINI_MODEL,
    },
    payments: Boolean(process.env.RAZORPAY_KEY_ID),
  });
});

app.listen(port, () => {
  console.log(`Vyoma Backend running on port ${port}`);
});
