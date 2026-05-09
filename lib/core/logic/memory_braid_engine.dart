import '../memory_service.dart';

// Surfaces ONE relevant past journal entry given a current intent string.
//
// v0 ranking: keyword overlap with simple stopword filtering, weighted by
// recency-decay so 3-week-old entries beat 6-month-old ones at equal overlap.
// Future v1: swap with embeddings via SupermemoryService.
class MemoryBraidEngine {
  const MemoryBraidEngine();

  // Entries less than this many days old are skipped — surfacing yesterday's
  // entry is not memory braiding, it's noise. Past-self has to be far enough
  // away to feel like a different person.
  static const _minAgeDays = 4;

  // Entries older than this fall off the relevance window.
  static const _maxAgeDays = 365;

  // Minimum keyword overlap required to surface anything at all. Below this
  // we'd rather show nothing than something wrong.
  static const _minOverlap = 1;

  static const _stopwords = <String>{
    'the', 'a', 'an', 'and', 'or', 'but', 'is', 'are', 'was', 'were',
    'be', 'been', 'being', 'have', 'has', 'had', 'do', 'does', 'did',
    'will', 'would', 'could', 'should', 'may', 'might', 'must', 'can',
    'i', 'me', 'my', 'we', 'our', 'you', 'your', 'they', 'them',
    'this', 'that', 'these', 'those', 'it', 'its', 'of', 'in', 'on',
    'at', 'to', 'for', 'with', 'about', 'as', 'by', 'from', 'up',
    'down', 'out', 'so', 'than', 'too', 'very', 'just', 'now', 'today',
    'tomorrow', 'yesterday', 'one', 'thing', 'need', 'want', 'get',
  };

  /// Returns the single most relevant past entry, or null if nothing crosses
  /// the relevance bar. Callers should treat null as "do not surface anything."
  JournalEntry? braid({
    required String intent,
    required List<JournalEntry> entries,
    DateTime? now,
  }) {
    final intentTokens = _tokenize(intent);
    if (intentTokens.isEmpty) return null;

    final clock = now ?? DateTime.now();

    JournalEntry? best;
    double bestScore = 0;

    for (final entry in entries) {
      final ageDays = clock.difference(entry.timestamp).inDays;
      if (ageDays < _minAgeDays) continue;
      if (ageDays > _maxAgeDays) continue;

      final entryTokens = _tokenize(entry.text);
      final overlap = intentTokens.intersection(entryTokens).length;
      if (overlap < _minOverlap) continue;

      // Recency-decay: linear from 1.0 at minAge to 0.4 at maxAge.
      // We want recent-but-not-too-recent entries to be prioritized.
      final ageFactor = 1.0 -
          ((ageDays - _minAgeDays) / (_maxAgeDays - _minAgeDays)) * 0.6;
      final score = overlap * ageFactor;

      if (score > bestScore) {
        bestScore = score;
        best = entry;
      }
    }
    return best;
  }

  Set<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r"[^\w\s]"), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 3 && !_stopwords.contains(t))
        .toSet();
  }
}
