import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../app/network_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../data/models/speed_result.dart';
import '../../data/repositories/history_repository.dart';
import '../../data/services/speed_test_service.dart';

/// Test state enumeration
enum TestState { idle, testingPing, testingDownload, testingUpload, completed, error }

/// EMA (指数移动平均) 计算器
/// V_current = α × V_new + (1-α) × V_previous
class EmaCalculator {
  final double alpha;
  double _value = 0;
  bool _initialized = false;

  EmaCalculator({this.alpha = 0.2});

  /// 更新值并返回 EMA 平滑后的值
  double update(double newValue) {
    if (!_initialized) {
      _value = newValue;
      _initialized = true;
    } else {
      _value = alpha * newValue + (1 - alpha) * _value;
    }
    return _value;
  }

  /// 重置状态
  void reset() {
    _value = 0;
    _initialized = false;
  }
}

/// Speed test ViewModel using ChangeNotifier
class SpeedTestViewModel extends ChangeNotifier {
  HistoryRepository? _historyRepository;
  final SpeedTestService _speedTestService = SpeedTestService();

  TestState _state = TestState.idle;
  double _downloadSpeed = 0;
  double _uploadSpeed = 0;
  double _ping = 0;
  double _jitter = 0;
  double _progress = 0;
  String? _errorMessage;
  SpeedResult? _lastResult;

  // EMA 平滑计算器
  final EmaCalculator _downloadEma = EmaCalculator(alpha: 0.2);
  final EmaCalculator _uploadEma = EmaCalculator(alpha: 0.2);

  // Network related
  NetworkProvider? _networkProvider;
  NetworkDetail? _testStartNetwork;
  bool _networkChangedDuringTest = false;

  // Getters
  TestState get state => _state;
  double get downloadSpeed => _downloadSpeed;
  double get uploadSpeed => _uploadSpeed;
  double get ping => _ping;
  double get jitter => _jitter;
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
      final pingResult = await _speedTestService.measurePing();
      _ping = pingResult.ping;
      _jitter = pingResult.jitter;
      if (_ping < 0) throw Exception('Ping test failed');
      if (_networkChangedDuringTest) throw Exception('NETWORK_CHANGED');

      // Phase 2: Download test (parallel with real-time updates)
      _state = TestState.testingDownload;
      _progress = 0.0;
      _downloadSpeed = 0;
      _downloadEma.reset();  // 重置 EMA 计算器
      notifyListeners();

      // Start progress timer (linear growth based on time, including warmup)
      final downloadStartTime = DateTime.now();
      final downloadDuration = Duration(milliseconds: AppConstants.warmupDurationMs + AppConstants.downloadTestDurationSeconds * 1000);
      final progressTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (_state != TestState.testingDownload) return;
        final elapsed = DateTime.now().difference(downloadStartTime);
        _progress = (elapsed.inMilliseconds / downloadDuration.inMilliseconds).clamp(0.0, 0.45);
        notifyListeners();
      });

      // Run parallel download test with stream updates
      // FR-017: 使用 EMA 算法平滑速度显示
      await for (final speed in _speedTestService.runDownloadTestParallel()) {
        if (_state != TestState.testingDownload) break;
        _downloadSpeed = _downloadEma.update(speed);  // EMA 平滑
        notifyListeners();
      }
      progressTimer.cancel();

      if (_networkChangedDuringTest) throw Exception('NETWORK_CHANGED');

      _progress = 0.5;
      notifyListeners();

      // Phase 3: Upload test (parallel with real-time updates)
      _state = TestState.testingUpload;
      _uploadSpeed = 0;
      _uploadEma.reset();  // 重置 EMA 计算器
      notifyListeners();

      // Start progress timer (linear growth based on time, including warmup)
      final uploadStartTime = DateTime.now();
      final uploadDuration = Duration(milliseconds: AppConstants.warmupDurationMs + AppConstants.uploadTestDurationSeconds * 1000);
      final uploadProgressTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (_state != TestState.testingUpload) return;
        final elapsed = DateTime.now().difference(uploadStartTime);
        _progress = 0.5 + (elapsed.inMilliseconds / uploadDuration.inMilliseconds).clamp(0.0, 0.45);
        notifyListeners();
      });

      // Run parallel upload test with stream updates
      // FR-017: 使用 EMA 算法平滑速度显示
      await for (final speed in _speedTestService.runUploadTestParallel()) {
        if (_state != TestState.testingUpload) break;
        _uploadSpeed = _uploadEma.update(speed);  // EMA 平滑
        notifyListeners();
      }
      uploadProgressTimer.cancel();

      if (_networkChangedDuringTest) throw Exception('NETWORK_CHANGED');

      // Stop signal polling
      _networkProvider?.stopSignalPolling();

      // Complete
      _state = TestState.completed;
      _progress = 1.0;
      notifyListeners();

      // Refresh WiFi name before saving - it might be available now that connection is stable
      String? finalWifiName = _testStartNetwork?.wifiName;
      if (finalWifiName == null) {
        final currentNetwork = _networkProvider?.currentNetwork;
        if (currentNetwork?.wifiName != null) {
          finalWifiName = currentNetwork!.wifiName;
        }
      }

      // Save result with network info
      _lastResult = SpeedResult(
        timestamp: DateTime.now(),
        downloadSpeed: _downloadSpeed,
        uploadSpeed: _uploadSpeed,
        ping: _ping,
        jitter: _jitter,
        networkType: _testStartNetwork?.type ?? NetworkType.none,
        wifiName: finalWifiName,
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
    _jitter = 0;
    _progress = 0;
    _errorMessage = null;
    _networkChangedDuringTest = false;
    _testStartNetwork = null;
    _downloadEma.reset();
    _uploadEma.reset();
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
