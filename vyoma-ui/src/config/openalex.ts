/**
 * OpenAlex API Configuration
 * 
 * Using Walden Rewrite (Launched Nov 3, 2025)
 * - 190M+ new works including datasets, software, dissertations
 * - Better metadata quality (references, OA detection, languages, licenses)
 * - Faster performance and more complete coverage
 * 
 * Documentation: https://docs.openalex.org/
 */

export const OPENALEX_CONFIG = {
  baseUrl: 'https://api.openalex.org',

  // Walden API parameters (Nov 2025)
  defaultParams: {
    'data-version': '2',        // Use Walden rewrite (new engine)
    'include_xpac': 'true',     // Include expanded content from DataCite
  },

  // Polite pool - add your email for faster rate limits
  email: 'support@vyoma.com',
} as const;

/**
 * Build OpenAlex API URL with Walden parameters
 */
export function buildOpenAlexUrl(endpoint: string, additionalParams?: Record<string, string>): string {
  const url = new URL(`${OPENALEX_CONFIG.baseUrl}${endpoint}`);

  // Add Walden parameters
  Object.entries(OPENALEX_CONFIG.defaultParams).forEach(([key, value]) => {
    url.searchParams.set(key, value);
  });

  // Add email for polite pool
  if (OPENALEX_CONFIG.email) {
    url.searchParams.set('mailto', OPENALEX_CONFIG.email);
  }

  // Add any additional parameters
  if (additionalParams) {
    Object.entries(additionalParams).forEach(([key, value]) => {
      url.searchParams.set(key, value);
    });
  }

  return url.toString();
}

/**
 * Fetch from OpenAlex with Walden parameters
 */
export async function fetchFromOpenAlex(endpoint: string, params?: Record<string, string>): Promise<Response> {
  const url = buildOpenAlexUrl(endpoint, params);
  return fetch(url);
}
