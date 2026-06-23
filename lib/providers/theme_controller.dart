import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the user's light/dark/system preference and persists it.
class ThemeController with ChangeNotifier {
  static const _key = 'ttc_theme_mode';
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  bool isDark(BuildContext context) => switch (_mode) {
        ThemeMode.dark => true,
        ThemeMode.light => false,
        ThemeMode.system =>
          MediaQuery.platformBrightnessOf(context) == Brightness.dark,
      };

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    _mode = switch (saved) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  /// Cycles through the three options; used by the quick toggle button.
  Future<void> toggle(BuildContext context) async {
    final next = isDark(context) ? ThemeMode.light : ThemeMode.dark;
    await setMode(next);
  }
}
