import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode enumeration for persistence
enum AppThemeMode { system, light, dark }

/// ThemeProvider - manages app theme state with persistence
class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';

  AppThemeMode _themeMode = AppThemeMode.system;

  AppThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadThemeMode();
  }

  /// Load theme mode from SharedPreferences
  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt(_themeKey);
    if (savedIndex != null && savedIndex < AppThemeMode.values.length) {
      _themeMode = AppThemeMode.values[savedIndex];
      notifyListeners();
    }
  }

  /// Save theme mode to SharedPreferences
  Future<void> _saveThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, _themeMode.index);
  }

  /// Set theme mode
  void setThemeMode(AppThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    _saveThemeMode();
    notifyListeners();
  }

  /// Convert AppThemeMode to Flutter ThemeMode
  ThemeMode get flutterThemeMode {
    switch (_themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}
