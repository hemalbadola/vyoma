import { createKeyRotator, parseEnvKeyList } from './apiKeyPool';

export const getNvidiaKeys = (): string[] =>
  parseEnvKeyList(process.env.NVIDIA_API_KEYS, [
    process.env.NVIDIA_API_KEY,
    process.env.NVIDIA_API_KEY_2,
  ]);

export const getGeminiKeys = (): string[] =>
  parseEnvKeyList(process.env.GEMINI_API_KEYS, [process.env.GEMINI_API_KEY]);

export const nextNvidiaKey = createKeyRotator(getNvidiaKeys, 'NVIDIA');
export const nextGeminiKey = createKeyRotator(getGeminiKeys, 'Gemini');
