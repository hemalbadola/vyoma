/** Parse comma-separated API keys from Heroku env (add keys there — no code changes). */

export function parseEnvKeyList(
  csvVar: string | undefined,
  legacyVars: (string | undefined)[],
): string[] {
  const fromCsv = (csvVar ?? '')
    .split(',')
    .map((k) => k.trim())
    .filter((k) => k.length > 0);
  if (fromCsv.length > 0) return fromCsv;

  const keys: string[] = [];
  for (const v of legacyVars) {
    const t = v?.trim();
    if (t) keys.push(t);
  }
  return keys;
}

export function createKeyRotator(getKeys: () => string[], label: string) {
  let index = 0;
  return function nextKey(): string {
    const keys = getKeys();
    if (keys.length === 0) {
      throw new Error(`${label} API keys not configured on server`);
    }
    const usedIndex = index % keys.length;
    const key = keys[usedIndex]!;
    index = (index + 1) % keys.length;
    console.log(`[${label}] key ${usedIndex + 1}/${keys.length}`);
    return key;
  };
}

export function isRetryableProviderError(status: number, body: unknown): boolean {
  if (status === 429) return true;
  if (status !== 401 && status !== 403) return false;
  const msg = JSON.stringify(body).toLowerCase();
  return (
    msg.includes('unauthorized') ||
    msg.includes('invalid') ||
    msg.includes('api key') ||
    msg.includes('forbidden') ||
    msg.includes('api_key')
  );
}

export function isModelUnavailableError(status: number, body: unknown): boolean {
  if (status === 404 || status === 410) return true;
  const msg = JSON.stringify(body).toLowerCase();
  return (
    msg.includes('model') &&
    (msg.includes('not found') ||
      msg.includes('unknown') ||
      msg.includes('retired') ||
      msg.includes('end of life') ||
      msg.includes('does not exist'))
  );
}
