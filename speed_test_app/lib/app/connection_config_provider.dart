import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ConnectionConfigProvider - manages parallel connection count with persistence
class ConnectionConfigProvider extends ChangeNotifier {
  static const String _key = 'parallel_connections';
  static const int _defaultConnections = 3;
  static const int _minConnections = 1;
  static const int _maxConnections = 8;

  int _connections = _defaultConnections;

  int get connections => _connections;

  ConnectionConfigProvider() {
    _load();
  }

  /// Load from SharedPreferences
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_key);
    if (saved != null && saved >= _minConnections && saved <= _maxConnections) {
      _connections = saved;
      notifyListeners();
    }
  }

  /// Save to SharedPreferences
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, _connections);
  }

  /// Set connection count
  void setConnections(int count) {
    if (count < _minConnections || count > _maxConnections) return;
    if (_connections == count) return;
    _connections = count;
    _save();
    notifyListeners();
  }
}
