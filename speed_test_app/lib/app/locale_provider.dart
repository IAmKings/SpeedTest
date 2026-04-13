import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported locales for the app
enum AppLocale {
  system,
  english,
  simplifiedChinese,
  traditionalChinese,
}

/// LocaleProvider - manages app locale state with persistence
class LocaleProvider extends ChangeNotifier {
  static const String _localeKey = 'app_locale';

  AppLocale _locale = AppLocale.system;

  AppLocale get locale => _locale;

  LocaleProvider() {
    _loadLocale();
  }

  /// Load locale from SharedPreferences
  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt(_localeKey);
    if (savedIndex != null && savedIndex < AppLocale.values.length) {
      _locale = AppLocale.values[savedIndex];
      notifyListeners();
    }
  }

  /// Save locale to SharedPreferences
  Future<void> _saveLocale() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_localeKey, _locale.index);
  }

  /// Set locale
  void setLocale(AppLocale locale) {
    if (_locale == locale) return;
    _locale = locale;
    _saveLocale();
    notifyListeners();
  }

  /// Convert AppLocale to Flutter Locale
  Locale? get flutterLocale {
    switch (_locale) {
      case AppLocale.system:
        return null; // Use system default
      case AppLocale.english:
        return const Locale('en');
      case AppLocale.simplifiedChinese:
        return const Locale('zh');
      case AppLocale.traditionalChinese:
        return const Locale('zh', 'TW');
    }
  }

  /// Get display name for the locale
  String getDisplayName(AppLocale locale, BuildContext context) {
    switch (locale) {
      case AppLocale.system:
        return 'System';
      case AppLocale.english:
        return 'English';
      case AppLocale.simplifiedChinese:
        return '简体中文';
      case AppLocale.traditionalChinese:
        return '繁體中文';
    }
  }
}
