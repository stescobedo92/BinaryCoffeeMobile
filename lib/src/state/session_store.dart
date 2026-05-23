import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_session.dart';

class SessionStore {
  static const _keys = ['id', 'username', 'email', 'avatarUrl', 'jwt'];

  Future<UserSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString('session.jwt');
    final username = prefs.getString('session.username');
    if (jwt == null || username == null) return null;
    return UserSession.fromPrefs({
      for (final key in _keys)
        if (prefs.getString('session.$key') != null)
          key: prefs.getString('session.$key')!,
    });
  }

  Future<void> save(UserSession session) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in session.toPrefs().entries) {
      await prefs.setString('session.${entry.key}', entry.value);
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _keys) {
      await prefs.remove('session.$key');
    }
  }

  Future<bool> loadDarkMode() async =>
      (await SharedPreferences.getInstance()).getBool('darkMode') ?? false;

  Future<void> saveDarkMode(bool value) async =>
      (await SharedPreferences.getInstance()).setBool('darkMode', value);

  Future<bool> loadNotifications() async =>
      (await SharedPreferences.getInstance()).getBool('notificationsEnabled') ??
      true;

  Future<void> saveNotifications(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(
        'notificationsEnabled',
        value,
      );
}
