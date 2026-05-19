/// NVIDIA NIM model IDs for Vyoma (integrate.api.nvidia.com).
///
/// Rate limit is ~40 req/min per API key; backend rotates [NVIDIA_API_KEYS].
class NimModels {
  NimModels._();

  /// Primary chat / instruction model (Nemotron Super 49B v1.5).
  static const text = 'nvidia/llama-3.3-nemotron-super-49b-v1.5';

  /// Fallback if primary text model errors (retired, quota, etc.).
  static const textFallback = 'meta/llama-3.3-70b-instruct';

  /// Best image+text model on NIM catalog for timetables / screenshots.
  static const vision = 'meta/llama-3.2-90b-vision-instruct';

  /// Lighter vision fallback when 90B is slow or unavailable.
  static const visionFallback = 'meta/llama-3.2-11b-vision-instruct';
}
