import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Speed unit enumeration
enum SpeedUnit { mbps, mbs }

/// UnitProvider - manages speed unit state with persistence
class UnitProvider extends ChangeNotifier {
  static const String _unitKey = 'speed_unit';

  SpeedUnit _unit = SpeedUnit.mbps;

  SpeedUnit get unit => _unit;

  UnitProvider() {
    _loadUnit();
  }

  /// Load unit from SharedPreferences
  Future<void> _loadUnit() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt(_unitKey);
    if (savedIndex != null && savedIndex < SpeedUnit.values.length) {
      _unit = SpeedUnit.values[savedIndex];
      notifyListeners();
    }
  }

  /// Save unit to SharedPreferences
  Future<void> _saveUnit() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_unitKey, _unit.index);
  }

  /// Set unit
  void setUnit(SpeedUnit unit) {
    if (_unit == unit) return;
    _unit = unit;
    _saveUnit();
    notifyListeners();
  }

  /// Convert Mbps to selected unit
  double convertSpeed(double mbps) {
    if (_unit == SpeedUnit.mbs) {
      return mbps / 8; // Convert Mbps to MB/s
    }
    return mbps;
  }

  /// Get display unit string
  String getUnitString(SpeedUnit unit) {
    return unit == SpeedUnit.mbps ? 'Mbps' : 'MB/s';
  }
}
