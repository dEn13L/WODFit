import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeService {
  static const String _boxName = 'settings_box';
  static const String _themeModeKey = 'theme_mode';

  Box? _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  ThemeMode get themeMode {
    final saved = _box?.get(_themeModeKey, defaultValue: 'dark') as String?;
    switch (saved) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      case 'dark':
      default:
        return ThemeMode.dark;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    String value;
    switch (mode) {
      case ThemeMode.light:
        value = 'light';
        break;
      case ThemeMode.system:
        value = 'system';
        break;
      case ThemeMode.dark:
        value = 'dark';
        break;
    }
    await _box?.put(_themeModeKey, value);
  }
}
