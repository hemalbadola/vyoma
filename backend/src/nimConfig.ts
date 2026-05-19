/** NVIDIA NIM + Gemini model selection (server-side — change here, not in Heroku). */

export const NIM_TEXT_MODELS = [
  'nvidia/llama-3.3-nemotron-super-49b-v1.5',
  'meta/llama-3.3-70b-instruct',
] as const;

export const NIM_VISION_MODELS = [
  'meta/llama-3.2-90b-vision-instruct',
  'meta/llama-3.2-11b-vision-instruct',
] as const;

export const GEMINI_MODEL = 'gemini-2.5-flash';

export const NVIDIA_CHAT_URL = 'https://integrate.api.nvidia.com/v1/chat/completions';
