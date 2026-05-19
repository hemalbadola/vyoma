import {
  isModelUnavailableError,
  isRetryableProviderError,
} from './apiKeyPool';
import { getGeminiKeys, getNvidiaKeys, nextGeminiKey, nextNvidiaKey } from './aiKeys';
import {
  GEMINI_MODEL,
  NIM_TEXT_MODELS,
  NIM_VISION_MODELS,
  NVIDIA_CHAT_URL,
} from './nimConfig';

export type AiGenerateInput = {
  textPrompt: string;
  imageBase64?: string;
  imageMimeType?: string;
};

export type AiGenerateSuccess = {
  ok: true;
  provider: 'nvidia' | 'gemini';
  model: string;
  text: string;
};

export type AiGenerateFailure = {
  ok: false;
  status: number;
  error: string;
  nvidiaAttempts: string[];
  geminiAttempts: string[];
};

export type AiGenerateResult = AiGenerateSuccess | AiGenerateFailure;

function buildNvidiaMessages(
  textPrompt: string,
  imageBase64?: string,
  imageMimeType = 'image/jpeg',
): Record<string, unknown>[] {
  if (imageBase64) {
    return [
      {
        role: 'user',
        content: [
          { type: 'text', text: textPrompt },
          {
            type: 'image_url',
            image_url: { url: `data:${imageMimeType};base64,${imageBase64}` },
          },
        ],
      },
    ];
  }
  return [{ role: 'user', content: textPrompt }];
}

function buildGeminiPayload(
  textPrompt: string,
  imageBase64?: string,
  imageMimeType = 'image/jpeg',
): Record<string, unknown> {
  const parts: Record<string, unknown>[] = [{ text: textPrompt }];
  if (imageBase64) {
    parts.push({ inlineData: { mimeType: imageMimeType, data: imageBase64 } });
  }
  return {
    contents: [{ role: 'user', parts }],
    safetySettings: [
      { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_NONE' },
      { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_NONE' },
      { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_NONE' },
      { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_NONE' },
    ],
    generationConfig: { maxOutputTokens: 16384 },
  };
}

function extractNvidiaText(data: any): string | null {
  const text = data?.choices?.[0]?.message?.content;
  return typeof text === 'string' && text.length > 0 ? text : null;
}

function extractGeminiText(data: any): string | null {
  const parts = data?.candidates?.[0]?.content?.parts;
  if (!Array.isArray(parts) || parts.length === 0) return null;
  const text = parts[0]?.text;
  return typeof text === 'string' && text.length > 0 ? text : null;
}

async function tryNvidia(
  input: AiGenerateInput,
  attempts: string[],
): Promise<AiGenerateSuccess | null> {
  const nvidiaKeys = getNvidiaKeys();
  if (nvidiaKeys.length === 0) return null;

  const models = input.imageBase64 ? [...NIM_VISION_MODELS] : [...NIM_TEXT_MODELS];
  const messages = buildNvidiaMessages(
    input.textPrompt,
    input.imageBase64,
    input.imageMimeType,
  );
  const maxKeyAttempts = Math.min(nvidiaKeys.length * 2, 8);

  for (const model of models) {
    for (let attempt = 0; attempt < maxKeyAttempts; attempt++) {
      const apiKey = nextNvidiaKey();
      const res = await fetch(NVIDIA_CHAT_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify({ model, messages }),
      });

      const data = await res.json().catch(() => ({}));

      if (res.ok) {
        const text = extractNvidiaText(data);
        if (text) {
          return { ok: true, provider: 'nvidia', model, text };
        }
        attempts.push(`nvidia/${model}: empty response`);
        break;
      }

      const detail =
        (data as any)?.error?.message ||
        (data as any)?.detail ||
        JSON.stringify(data).slice(0, 120);
      attempts.push(`nvidia/${model}: HTTP ${res.status} ${detail}`);

      if (isModelUnavailableError(res.status, data)) {
        console.warn(`[AI] NVIDIA model unavailable: ${model}`);
        break;
      }
      if (isRetryableProviderError(res.status, data)) {
        continue;
      }
      break;
    }
  }

  return null;
}

async function tryGemini(
  input: AiGenerateInput,
  attempts: string[],
): Promise<AiGenerateSuccess | null> {
  const geminiKeys = getGeminiKeys();
  if (geminiKeys.length === 0) return null;

  const payload = buildGeminiPayload(
    input.textPrompt,
    input.imageBase64,
    input.imageMimeType,
  );
  const maxKeyAttempts = Math.min(geminiKeys.length * 2, 8);

  for (let attempt = 0; attempt < maxKeyAttempts; attempt++) {
    const apiKey = nextGeminiKey();
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${apiKey}`;

    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });

    const data = await res.json().catch(() => ({}));

    if (res.ok) {
      const text = extractGeminiText(data);
      if (text) {
        return { ok: true, provider: 'gemini', model: GEMINI_MODEL, text };
      }
      attempts.push(`gemini/${GEMINI_MODEL}: empty or blocked response`);
      continue;
    }

    const errMsg = (data as any)?.error?.message || JSON.stringify(data).slice(0, 120);
    attempts.push(`gemini/${GEMINI_MODEL}: HTTP ${res.status} ${errMsg}`);

    if (isRetryableProviderError(res.status, data)) {
      continue;
    }
    if (
      res.status === 400 &&
      String(errMsg).toLowerCase().includes('api key not valid')
    ) {
      continue;
    }
    break;
  }

  return null;
}

/** NVIDIA (all keys × models) → Gemini (all keys). Keys only in Heroku env. */
export async function generateWithProviderPriority(
  input: AiGenerateInput,
): Promise<AiGenerateResult> {
  const nvidiaAttempts: string[] = [];
  const geminiAttempts: string[] = [];

  const nvidia = await tryNvidia(input, nvidiaAttempts);
  if (nvidia) return nvidia;

  console.log('[AI] NVIDIA exhausted — falling back to Gemini');
  const gemini = await tryGemini(input, geminiAttempts);
  if (gemini) return gemini;

  const hasNvidia = getNvidiaKeys().length > 0;
  const hasGemini = getGeminiKeys().length > 0;
  let error = 'All AI providers failed.';
  if (!hasNvidia && !hasGemini) {
    error = 'No API keys configured (set NVIDIA_API_KEYS and GEMINI_API_KEYS on Heroku).';
  } else if (!hasNvidia) {
    error = 'NVIDIA_API_KEYS not set; Gemini also failed.';
  } else if (!hasGemini) {
    error = 'GEMINI_API_KEYS not set; NVIDIA also failed.';
  }

  return {
    ok: false,
    status: 502,
    error,
    nvidiaAttempts,
    geminiAttempts,
  };
}
