import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../app/network_provider.dart';
import '../../data/models/speed_result.dart';
import '../../data/repositories/history_repository.dart';
import '../../data/services/speed_test_service.dart';

/// Test state enumeration
enum TestState { idle, testingPing, testingDownload, testingUpload, completed, error }

/// Speed test ViewModel using ChangeNotifier
class SpeedTestViewModel extends ChangeNotifier {
  HistoryRepository? _historyRepository;
  final SpeedTestService _speedTestService = SpeedTestService();

  TestState _state = TestState.idle;
  double _downloadSpeed = 0;
  double _uploadSpeed = 0;
  double _ping = 0;
  double _progress = 0;
  String? _errorMessage;
  SpeedResult? _lastResult;

  // Network related
  NetworkProvider? _networkProvider;
  NetworkDetail? _testStartNetwork;
  bool _networkChangedDuringTest = false;

  // Getters
  TestState get state => _state;
  double get downloadSpeed => _downloadSpeed;
  double get uploadSpeed => _uploadSpeed;
  double get ping => _ping;
  TestState get currentState => _state;
  double get progress => _progress;
  String? get errorMessage => _errorMessage;
  SpeedResult? get lastResult => _lastResult;
  bool get isTestRunning => _state != TestState.idle && _state != TestState.completed && _state != TestState.error;

  /// Set network provider for monitoring
  void setNetworkProvider(NetworkProvider provider) {
    _networkProvider = provider;
  }

  SpeedTestViewModel({HistoryRepository? historyRepository}) {
    _historyRepository = historyRepository;
  }

  void setHistoryRepository(HistoryRepository repository) {
    _historyRepository = repository;
  }

  /// Start the full speed test sequence
  Future<void> startTest() async {
    if (isTestRunning) return;

    _reset();
    _networkChangedDuringTest = false;

    // Record network info at test start
    if (_networkProvider != null) {
      _testStartNetwork = _networkProvider!.currentNetwork;
      _networkProvider!.startSignalPolling();

      // Listen for network changes during test
      _networkProvider!.addListener(_onNetworkChanged);
    }

    _state = TestState.testingPing;
    notifyListeners();

    try {
      // Phase 1: Ping test
      _ping = await _speedTestService.measurePing();
      if (_ping < 0) throw Exception('Ping test failed');
      if (_networkChangedDuringTest) throw Exception('NETWORK_CHANGED');

      // Phase 2: Download test
      _state = TestState.testingDownload;
      _progress = 0.1;
      _downloadSpeed = 0;
      notifyListeners();

      bool networkChangedDuringDownload = false;
      await for (final measurement in _speedTestService.runDownloadTest()) {
        _downloadSpeed = measurement.speedMbps;
        _progress = 0.1 + (measurement.speedMbps / 500).clamp(0.0, 0.4);
        notifyListeners();
        if (_networkChangedDuringTest) {
          networkChangedDuringDownload = true;
          break;
        }
      }
      if (networkChangedDuringDownload) throw Exception('NETWORK_CHANGED');

      _progress = 0.5;
      notifyListeners();

      // Phase 3: Upload test
      _state = TestState.testingUpload;
      _progress = 0.7;
      _uploadSpeed = 0;
      notifyListeners();

      bool networkChangedDuringUpload = false;
      await for (final measurement in _speedTestService.runUploadTest()) {
        _uploadSpeed = measurement.speedMbps;
        _progress = 0.7 + (measurement.speedMbps / 500).clamp(0.0, 0.3);
        notifyListeners();
        if (_networkChangedDuringTest) {
          networkChangedDuringUpload = true;
          break;
        }
      }
      if (networkChangedDuringUpload) throw Exception('NETWORK_CHANGED');

      // Stop signal polling
      _networkProvider?.stopSignalPolling();

      // Complete
      _state = TestState.completed;
      _progress = 1.0;
      notifyListeners();

      // Save result with network info
      _lastResult = SpeedResult(
        timestamp: DateTime.now(),
        downloadSpeed: _downloadSpeed,
        uploadSpeed: _uploadSpeed,
        ping: _ping,
        networkType: _testStartNetwork?.type ?? NetworkType.none,
        wifiName: _testStartNetwork?.wifiName,
        avgSignalStrength: _networkProvider?.avgSignalStrength,
      );
      // Save result - wrap in try-catch to prevent database errors from causing test failure
      try {
        if (_lastResult != null) {
          await _historyRepository?.insertResult(_lastResult!);
        }
      } catch (e) {
        // Database error should not mark test as failed, just log it
        debugPrint('Failed to save result: $e');
      }

    } catch (e) {
      _networkProvider?.stopSignalPolling();
      _state = TestState.error;
      final errorStr = e.toString();
      if (errorStr == 'Exception: NETWORK_CHANGED' || errorStr.contains('NETWORK_CHANGED')) {
        _errorMessage = 'NETWORK_CHANGED';
      } else if (errorStr == 'Exception: Ping test failed') {
        _errorMessage = errorStr;
      } else {
        _errorMessage = errorStr;
        debugPrint('Test error: $e');
      }
      notifyListeners();
    } finally {
      _networkProvider?.removeListener(_onNetworkChanged);
    }
  }

  /// Handle network change during test
  void _onNetworkChanged() {
    if (_networkProvider == null || _testStartNetwork == null) return;
    if (!isTestRunning) return;

    final currentNetwork = _networkProvider!.currentNetwork;

    // Check if network type changed
    if (currentNetwork.type != _testStartNetwork!.type) {
      _networkChangedDuringTest = true;
      return;
    }

    // For WiFi, only consider it a change if both old and new names are non-null and different
    // This handles the case where WiFi name temporarily returns null during scanning
    if (currentNetwork.type == NetworkType.wifi) {
      final oldName = _testStartNetwork!.wifiName;
      final newName = currentNetwork.wifiName;

      // Only trigger change if both are non-null and different
      if (oldName != null && newName != null && oldName != newName) {
        _networkChangedDuringTest = true;
      }
    }
  }

  /// Stop the running test
  void stopTest() {
    _speedTestService.stopTest();
    _networkProvider?.stopSignalPolling();
    _networkProvider?.removeListener(_onNetworkChanged);
    _state = TestState.idle;
    notifyListeners();
  }

  /// Reset all values
  void _reset() {
    _downloadSpeed = 0;
    _uploadSpeed = 0;
    _ping = 0;
    _progress = 0;
    _errorMessage = null;
    _networkChangedDuringTest = false;
    _testStartNetwork = null;
    notifyListeners();
  }

  /// Check if error is due to network change
  bool get isNetworkChangedError => _errorMessage == 'NETWORK_CHANGED';

  @override
  void dispose() {
    _speedTestService.dispose();
    _networkProvider?.removeListener(_onNetworkChanged);
    _networkProvider?.stopSignalPolling();
    super.dispose();
  }
}
