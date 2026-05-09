import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/dharma_chapter_models.dart';

/// Persists the user's dharma map — the ordered list of chapters that
/// together form a long-arc identity narrative.
///
/// v0 stores in SharedPreferences as JSON. Network sync deferred — chapters
/// are currently personal, not public to the Circle.
class DharmaMapService extends ChangeNotifier {
  DharmaMapService();

  static const _key = 'dharma_chapters_v1';

  List<DharmaChapter> _chapters = const [];
  bool _initialized = false;

  List<DharmaChapter> get chapters => List.unmodifiable(_chapters);
  bool get isInitialized => _initialized;
  DharmaChapter? get currentChapter {
    for (final c in _chapters) {
      if (c.isOpen) return c;
    }
    return null;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    _chapters = raw
        .map((s) =>
            DharmaChapter.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    _initialized = true;
    notifyListeners();
  }

  Future<DharmaChapter> startChapter({
    required String themeWord,
    required String masterSkill,
    required List<String> outcomes,
  }) async {
    if (themeWord.trim().isEmpty || masterSkill.trim().isEmpty) {
      throw ArgumentError('themeWord and masterSkill are required');
    }
    final clean = outcomes
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(3)
        .toList();
    if (clean.isEmpty) {
      throw ArgumentError('at least one outcome is required');
    }
    // Auto-close any currently-open chapter — only one runs at a time.
    _chapters = _chapters
        .map((c) =>
            c.isOpen ? c.copyWith(closedAt: DateTime.now()) : c)
        .toList();
    final chapter = DharmaChapter(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      themeWord: themeWord.trim().split(RegExp(r'\s+')).first.toLowerCase(),
      masterSkill: masterSkill.trim(),
      outcomes: clean,
      startedAt: DateTime.now(),
    );
    _chapters = [..._chapters, chapter];
    await _persist();
    notifyListeners();
    return chapter;
  }

  Future<void> closeCurrent() async {
    final cur = currentChapter;
    if (cur == null) return;
    _chapters = _chapters
        .map((c) =>
            c.id == cur.id ? c.copyWith(closedAt: DateTime.now()) : c)
        .toList();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      _chapters.map((c) => jsonEncode(c.toJson())).toList(),
    );
  }
}
