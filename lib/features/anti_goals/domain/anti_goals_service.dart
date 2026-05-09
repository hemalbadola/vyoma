import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The list of behaviors the user explicitly refuses to drift into.
///
/// Inverts goal-setting. Tony Fadell's internal practice: writing what you
/// will never become is a sharper compass than writing what you want.
///
/// v0: a flat list of strings, persisted locally. Surfaced in Settings and
/// referenced by future weekly review.
class AntiGoalsService extends ChangeNotifier {
  AntiGoalsService();

  static const _key = 'anti_goals_v1';

  List<String> _items = const [];
  bool _initialized = false;

  List<String> get items => List.unmodifiable(_items);
  bool get isInitialized => _initialized;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _items = prefs.getStringList(_key) ?? const [];
    _initialized = true;
    notifyListeners();
  }

  Future<void> add(String item) async {
    final clean = item.trim();
    if (clean.isEmpty) return;
    _items = [..._items, clean];
    await _persist();
    notifyListeners();
  }

  Future<void> remove(int index) async {
    if (index < 0 || index >= _items.length) return;
    final next = [..._items]..removeAt(index);
    _items = next;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _items);
  }
}
