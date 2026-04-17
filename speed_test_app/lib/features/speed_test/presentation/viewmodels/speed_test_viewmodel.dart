import 'dart:async';
import 'dart:math' as math;
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

  // Progress timers
  Timer? _downloadProgressTimer;
  Timer? _uploadProgressTimer;

  // Ping test timers
  Timer? _pingTimer;
  Timer? _pingProgressTimer;
  double _pingProgress = 0.0;
  bool _pingCompleted = false;

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
  double get pingProgress => _pingProgress;

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
    _pingProgress = 0.0;
    _pingCompleted = false;
    notifyListeners();

    // Start ping progress timer (advances 1/5 per second)
    _pingProgressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state != TestState.testingPing) return;
      _pingProgress = (_pingProgress + 0.2).clamp(0.0, 1.0);
      notifyListeners();
    });

    // Start 5 second timeout timer
    _pingTimer = Timer(const Duration(seconds: 5), () {
      if (_state == TestState.testingPing && !_pingCompleted) {
        _onPingCompleted(success: false);
      }
    });

    // Run ping test
    await _runPingTest();
  }

  /// Run ping test (5 measurements)
  Future<void> _runPingTest() async {
    final measurements = <double>[];

    for (int i = 0; i < AppConstants.pingTestCount; i++) {
      // Check if test was stopped
      if (_state != TestState.testingPing) return;

      final (success, pingMs) = await _speedTestService.measureOnePing();
      if (success) {
        measurements.add(pingMs);
      }

      // Update progress based on completed pings
      _pingProgress = (i + 1) / AppConstants.pingTestCount;
      notifyListeners();

      // Delay between pings
      if (i < AppConstants.pingTestCount - 1) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    // All pings done, calculate result
    if (_state != TestState.testingPing) return;

    if (measurements.isEmpty) {
      _onPingCompleted(success: false);
    } else {
      // Calculate ping and jitter from measurements (去极值取平均)
      _calculatePingAndJitter(measurements);
      _onPingCompleted(success: true);
    }
  }

  /// Calculate ping and jitter from measurements (去极值逻辑与 measurePing 一致)
  void _calculatePingAndJitter(List<double> measurements) {
    if (measurements.isEmpty) {
      _ping = -1;
      _jitter = 0;
      return;
    }

    if (measurements.length == 1) {
      _ping = measurements.first;
      _jitter = 0;
      return;
    }

    // 去极值：排序后去掉最大和最小值
    final sorted = List<double>.from(measurements)..sort();
    final trimmed = sorted.length > 2 ? sorted.sublist(1, sorted.length - 1) : sorted;

    // 取平均作为 Ping
    _ping = trimmed.reduce((a, b) => a + b) / trimmed.length;

    // 计算方差作为 Jitter
    final mean = _ping;
    final variance = trimmed.map((r) => math.pow(r - mean, 2)).reduce((a, b) => a + b) / trimmed.length;
    _jitter = math.sqrt(variance);
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
    _cancelPingTimers();
    _downloadProgressTimer?.cancel();
    _uploadProgressTimer?.cancel();
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
    _cancelPingTimers();
    _downloadProgressTimer?.cancel();
    _uploadProgressTimer?.cancel();
    _downloadProgressTimer = null;
    _uploadProgressTimer = null;
    _pingProgress = 0.0;
    _pingCompleted = false;
    notifyListeners();
  }

  /// Check if error is due to network change
  bool get isNetworkChangedError => _errorMessage == 'NETWORK_CHANGED';

  /// Cancel all ping-related timers
  void _cancelPingTimers() {
    _pingTimer?.cancel();
    _pingProgressTimer?.cancel();
    _pingTimer = null;
    _pingProgressTimer = null;
  }

  /// Called when ping test completes (successfully or timed out)
  void _onPingCompleted({bool success = true}) {
    _cancelPingTimers();
    _pingCompleted = true;
    _pingProgress = 1.0;
    notifyListeners();

    if (success) {
      // Proceed to download test after a brief delay for visual feedback
      Future.delayed(const Duration(milliseconds: 400), () {
        if (_state == TestState.testingPing) {
          _startDownloadTest();
        }
      });
    }
  }

  /// Start the download test phase
  void _startDownloadTest() {
    if (_networkChangedDuringTest) {
      _onNetworkChangedDuringTest();
      return;
    }

    _state = TestState.testingDownload;
    _progress = 0.0;
    _downloadSpeed = 0;
    _downloadEma.reset();
    notifyListeners();

    final downloadStartTime = DateTime.now();
    final downloadDuration = Duration(milliseconds: AppConstants.warmupDurationMs + AppConstants.downloadTestDurationSeconds * 1000);
    _downloadProgressTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_state != TestState.testingDownload) return;
      final elapsed = DateTime.now().difference(downloadStartTime);
      _progress = (elapsed.inMilliseconds / downloadDuration.inMilliseconds).clamp(0.0, 0.45);
      notifyListeners();
    });

    _runDownloadTest();
  }

  /// Run download test
  Future<void> _runDownloadTest() async {
    try {
      await for (final speed in _speedTestService.runDownloadTestParallel()) {
        if (_state != TestState.testingDownload) break;
        _downloadSpeed = _downloadEma.update(speed);
        notifyListeners();
      }
      if (_networkChangedDuringTest) {
        _onNetworkChangedDuringTest();
        return;
      }

      _progress = 0.5;
      notifyListeners();
      _startUploadTest();
    } catch (e) {
      _handleError(e);
    }
  }

  /// Start the upload test phase
  void _startUploadTest() {
    _state = TestState.testingUpload;
    _uploadSpeed = 0;
    _uploadEma.reset();
    notifyListeners();

    final uploadStartTime = DateTime.now();
    final uploadDuration = Duration(milliseconds: AppConstants.warmupDurationMs + AppConstants.uploadTestDurationSeconds * 1000);
    _uploadProgressTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_state != TestState.testingUpload) return;
      final elapsed = DateTime.now().difference(uploadStartTime);
      _progress = 0.5 + (elapsed.inMilliseconds / uploadDuration.inMilliseconds).clamp(0.0, 0.45);
      notifyListeners();
    });

    _runUploadTest();
  }

  /// Run upload test
  Future<void> _runUploadTest() async {
    try {
      await for (final speed in _speedTestService.runUploadTestParallel()) {
        if (_state != TestState.testingUpload) break;
        _uploadSpeed = _uploadEma.update(speed);
        notifyListeners();
      }

      if (_networkChangedDuringTest) {
        _onNetworkChangedDuringTest();
        return;
      }

      _networkProvider?.stopSignalPolling();
      _state = TestState.completed;
      _progress = 1.0;
      notifyListeners();

      _saveResult();
    } catch (e) {
      _handleError(e);
    }
  }

  /// Handle network change during test
  void _onNetworkChangedDuringTest() {
    _cancelPingTimers();
    _downloadProgressTimer?.cancel();
    _uploadProgressTimer?.cancel();
    _networkProvider?.stopSignalPolling();
    _state = TestState.error;
    _errorMessage = 'NETWORK_CHANGED';
    notifyListeners();
  }

  /// Save test result
  Future<void> _saveResult() async {
    String? finalWifiName = _testStartNetwork?.wifiName;
    if (finalWifiName == null) {
      final currentNetwork = _networkProvider?.currentNetwork;
      if (currentNetwork?.wifiName != null) {
        finalWifiName = currentNetwork!.wifiName;
      }
    }

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

    try {
      if (_lastResult != null) {
        await _historyRepository?.insertResult(_lastResult!);
      }
    } catch (e) {
      debugPrint('Failed to save result: $e');
    }
  }

  /// Handle errors
  void _handleError(dynamic e) {
    _cancelPingTimers();
    _downloadProgressTimer?.cancel();
    _uploadProgressTimer?.cancel();
    _networkProvider?.stopSignalPolling();
    _state = TestState.error;
    final errorStr = e.toString();
    if (errorStr.contains('NETWORK_CHANGED')) {
      _errorMessage = 'NETWORK_CHANGED';
    } else {
      _errorMessage = errorStr;
      debugPrint('Test error: $e');
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _speedTestService.dispose();
    _cancelPingTimers();
    _downloadProgressTimer?.cancel();
    _uploadProgressTimer?.cancel();
    _networkProvider?.removeListener(_onNetworkChanged);
    _networkProvider?.stopSignalPolling();
    super.dispose();
  }
}
