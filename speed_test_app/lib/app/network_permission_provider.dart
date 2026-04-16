import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for managing WiFi permission state with persistence
class NetworkPermissionProvider extends ChangeNotifier {
  static const String _dontAskAgainKey = 'wifi_permission_dont_ask_again';

  bool _dontAskAgain = false;

  bool get dontAskAgain => _dontAskAgain;

  NetworkPermissionProvider() {
    _loadState();
  }

  /// Load state from SharedPreferences
  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    _dontAskAgain = prefs.getBool(_dontAskAgainKey) ?? false;
    notifyListeners();
  }

  /// Save dontAskAgain state
  Future<void> _saveDontAskAgain() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dontAskAgainKey, _dontAskAgain);
  }

  /// Set dont ask again preference
  void setDontAskAgain(bool value) {
    if (_dontAskAgain == value) return;
    _dontAskAgain = value;
    _saveDontAskAgain();
    notifyListeners();
  }

  /// Check if permission dialog should be shown
  /// Returns false if user selected "don't ask again"
  bool get shouldShowPermissionDialog => !_dontAskAgain;
}
