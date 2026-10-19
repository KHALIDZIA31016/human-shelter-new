import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Thin persistence layer. Providers talk only to this class, so replacing it
/// with a Firebase / REST implementation later does not touch any UI.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<LocalStore> open() async =>
      LocalStore(await SharedPreferences.getInstance());

  String? getString(String key) => _prefs.getString(key);

  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  List<Map<String, dynamic>> readList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return []; // corrupt data must never crash the app
    }
  }

  Future<void> writeList(String key, List<Map<String, dynamic>> data) =>
      _prefs.setString(key, jsonEncode(data));

  /// One-time reset: drops every locally stored registration, user and the
  /// data hanging off them, so accounts start fresh from the auth screens.
  Future<void> cleanSlateOnce() async {
    const flag = 'clean_slate_v1';
    if (_prefs.getString(flag) != null) return;
    for (final k in const [
      'registrations_v1',
      'seeded_v1',
      'seed_beds_fix_v1',
      'users_v1',
      'active_user',
      'persona',
      'active_partner',
      'requests_v1',
      'notifications_v1',
      'chat_v1',
      'complaints_v1',
      'transfers_v1',
      'profile_changes_v1',
      'staff_v1',
    ]) {
      await _prefs.remove(k);
    }
    await _prefs.setString(flag, '1');
  }
}
