import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores the user's identity anchor — a single sentence answering
/// "who are you trying to become in the next twelve months?"
///
/// This is referenced ambiently across the app (Today header, weekly review,
/// task framing). v0 is a single string in SharedPreferences. v2 layer would
/// move this to Firestore + add nuance (multiple chapters, expiry, etc.).
class IdentityAnchorService extends ChangeNotifier {
  IdentityAnchorService();

  static const _key = 'identity_anchor_v1';
  static const _setAtKey = 'identity_anchor_set_at_v1';

  String? _anchor;
  DateTime? _setAt;
  bool _initialized = false;

  String? get anchor => _anchor;
  DateTime? get setAt => _setAt;
  bool get isInitialized => _initialized;
  bool get hasAnchor => (_anchor?.trim().isNotEmpty ?? false);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _anchor = prefs.getString(_key);
    final iso = prefs.getString(_setAtKey);
    if (iso != null) _setAt = DateTime.tryParse(iso);
    _initialized = true;
    notifyListeners();
  }

  Future<void> setAnchor(String value) async {
    final clean = value.trim();
    final prefs = await SharedPreferences.getInstance();
    if (clean.isEmpty) {
      await prefs.remove(_key);
      await prefs.remove(_setAtKey);
      _anchor = null;
      _setAt = null;
    } else {
      _anchor = clean;
      _setAt = DateTime.now();
      await prefs.setString(_key, clean);
      await prefs.setString(_setAtKey, _setAt!.toIso8601String());
    }
    notifyListeners();
  }
}
