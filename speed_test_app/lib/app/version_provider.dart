import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import '../features/speed_test/data/services/version_service.dart';

/// Global version state provider for sharing version check state between pages
class VersionProvider extends ChangeNotifier {
  final VersionService _versionService = VersionService();

  bool _isChecking = false;
  VersionInfo? _latestVersion;
  bool _hasUpdate = false;
  String? _errorMessage;
  http.Client? _httpClient;
  StreamSubscription? _responseSubscription;

  /// Whether a version check is currently in progress
  bool get isChecking => _isChecking;

  /// Latest version info if check has completed
  VersionInfo? get latestVersion => _latestVersion;

  /// Whether a newer version is available
  bool get hasUpdate => _hasUpdate;

  /// Error message if check failed
  String? get errorMessage => _errorMessage;

  /// Check for updates - cancels any existing check in progress
  Future<void> checkForUpdate() async {
    // Cancel any existing check
    _cancelPendingCheck();

    _isChecking = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final currentVersion = await PackageInfo.fromPlatform().then((p) => p.version);
      final versionInfo = await _versionService.checkLatestVersion();

      if (versionInfo == null) {
        _latestVersion = null;
        _hasUpdate = false;
      } else {
        _latestVersion = versionInfo;
        _hasUpdate = _compareVersions(currentVersion, versionInfo.version) < 0;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _latestVersion = null;
      _hasUpdate = false;
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  /// Cancel any pending version check
  void _cancelPendingCheck() {
    _responseSubscription?.cancel();
    _responseSubscription = null;
    _httpClient?.close();
    _httpClient = null;
  }

  /// Cancel any in-progress check
  void cancelCheck() {
    _cancelPendingCheck();
    _isChecking = false;
    notifyListeners();
  }

  /// Compare version strings
  /// Returns negative if current < latest, 0 if equal, positive if current > latest
  int _compareVersions(String current, String latest) {
    final cParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final lParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (int i = 0; i < 3; i++) {
      final c = i < cParts.length ? cParts[i] : 0;
      final l = i < lParts.length ? lParts[i] : 0;
      if (c != l) return c - l;
    }
    return 0;
  }

  @override
  void dispose() {
    _cancelPendingCheck();
    super.dispose();
  }
}
