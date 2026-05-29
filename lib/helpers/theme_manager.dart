import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'color.dart';

class ThemeManager {
  static const _key = 'app_dark_mode';

  // Notifier — listen to this to rebuild the root widget
  static final ValueNotifier<bool> isDark = ValueNotifier(false);

  // Call once in main() before runApp
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final dark = prefs.getBool(_key) ?? false;
    isDark.value = dark;
    if (dark) {
      setDarkTheme();
    } else {
      setLightTheme();
    }
  }

  // Toggle and persist
  static Future<void> toggle() async {
    final nowDark = !isDark.value;
    if (nowDark) {
      setDarkTheme();
    } else {
      setLightTheme();
    }
    isDark.value = nowDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, nowDark);
  }

  // Current Flutter ThemeMode for MaterialApp
  static ThemeMode get themeMode =>
      isDark.value ? ThemeMode.dark : ThemeMode.light;
}
