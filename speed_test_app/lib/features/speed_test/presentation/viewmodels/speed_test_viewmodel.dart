import 'dart:async';
import 'package:flutter/foundation.dart';
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
  String _currentPhase = '';
  double _progress = 0;
  String? _errorMessage;
  SpeedResult? _lastResult;

  // Getters
  TestState get state => _state;
  double get downloadSpeed => _downloadSpeed;
  double get uploadSpeed => _uploadSpeed;
  double get ping => _ping;
  String get currentPhase => _currentPhase;
  double get progress => _progress;
  String? get errorMessage => _errorMessage;
  SpeedResult? get lastResult => _lastResult;
  bool get isTestRunning => _state != TestState.idle && _state != TestState.completed && _state != TestState.error;

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
    _state = TestState.testingPing;
    _currentPhase = 'Measuring ping...';
    notifyListeners();

    try {
      // Phase 1: Ping test
      _ping = await _speedTestService.measurePing();
      if (_ping < 0) throw Exception('Ping test failed');

      // Phase 2: Download test
      _state = TestState.testingDownload;
      _currentPhase = 'Testing download...';
      _progress = 0;
      notifyListeners();

      await for (final measurement in _speedTestService.runDownloadTest()) {
        _downloadSpeed = measurement.speedMbps;
        _progress = 0.3 + (measurement.speedMbps / 200) * 0.4; // 30-70%
        notifyListeners();
      }

      // Phase 3: Upload test
      _state = TestState.testingUpload;
      _currentPhase = 'Testing upload...';
      _progress = 0.7;
      notifyListeners();

      await for (final measurement in _speedTestService.runUploadTest()) {
        _uploadSpeed = measurement.speedMbps;
        _progress = 0.7 + (measurement.speedMbps / 100) * 0.3; // 70-100%
        notifyListeners();
      }

      // Complete
      _state = TestState.completed;
      _progress = 1.0;
      _currentPhase = 'Test completed!';
      notifyListeners();

      // Save result
      _lastResult = SpeedResult(
        timestamp: DateTime.now(),
        downloadSpeed: _downloadSpeed,
        uploadSpeed: _uploadSpeed,
        ping: _ping,
      );
      await _historyRepository?.insertResult(_lastResult!);

    } catch (e) {
      _state = TestState.error;
      _errorMessage = e.toString();
      _currentPhase = 'Test failed';
      notifyListeners();
    }
  }

  /// Stop the running test
  void stopTest() {
    _speedTestService.stopTest();
    _state = TestState.idle;
    _currentPhase = '';
    notifyListeners();
  }

  /// Reset all values
  void _reset() {
    _downloadSpeed = 0;
    _uploadSpeed = 0;
    _ping = 0;
    _progress = 0;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _speedTestService.dispose();
    super.dispose();
  }
}
