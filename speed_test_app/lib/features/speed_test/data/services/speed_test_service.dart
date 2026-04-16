import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';

/// 动态 chunk 大小估算器
/// 根据当前网速动态调整下一次请求的 chunk 大小，维持连续下载状态
class ChunkSizeEstimator {
  static const int _minSamples = 3;            // 最少样本数
  static const int _defaultChunkSize = 2000000;  // 2MB 默认
  static const int _minChunkSize = 500000;       // 500KB 最小
  static const int _maxChunkSize = 10000000;     // 10MB 最大
  static const double _targetDuration = 0.5;     // 500ms 目标时长

  double _lastSpeed = 0;  // Mbps
  int _sampleCount = 0;

  int getNextChunkSize() {
    if (_sampleCount < _minSamples) return _defaultChunkSize;
    // speedMbps * targetDuration(0.5s) * 125000 ≈ chunkSize(bytes)
    return (_lastSpeed * _targetDuration * 125000).clamp(_minChunkSize.toDouble(), _maxChunkSize.toDouble()).toInt();
  }

  void addSample(int bytes, int elapsedMs) {
    if (elapsedMs <= 0) return;
    _sampleCount++;
    // speed = bytes * 8 / seconds / 1,000,000 = Mbps
    final speed = (bytes * 8) / elapsedMs * 1000 / 1000000;
    _lastSpeed = (_lastSpeed * (_sampleCount - 1) + speed) / _sampleCount;
  }

  void reset() {
    _lastSpeed = 0;
    _sampleCount = 0;
  }
}

/// Speed test service using Cloudflare Speed Test API
/// 优化版：支持多线程并行测速、流式实时速度更新、带预热阶段、动态 chunkSize
class SpeedTestService {
  final http.Client _client;
  bool _isTestRunning = false;
  static const String _parallelConnectionsKey = 'parallel_connections';

  // StreamController 引用，用于 stopTest 时清理
  final List<StreamController<ChunkResult>> _activeControllers = [];

  SpeedTestService({http.Client? client}) : _client = client ?? http.Client();

  bool get isTestRunning => _isTestRunning;

  /// Get parallel connections from settings (default 3)
  Future<int> _getParallelConnections() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_parallelConnectionsKey) ?? AppConstants.parallelConnections;
  }

  /// 优化 Ping 测量：多次测量去极值取平均
  Future<double> measurePing() async {
    final measurements = <double>[];

    for (int i = 0; i < AppConstants.pingTestCount; i++) {
      final stopwatch = Stopwatch()..start();
      try {
        await _client
            .head(Uri.parse(AppConstants.pingTestUrl))
            .timeout(const Duration(seconds: 10));
        stopwatch.stop();
        measurements.add(stopwatch.elapsedMilliseconds.toDouble());
      } catch (e) {
        // 失败不计入
      }
      if (i < AppConstants.pingTestCount - 1) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    if (measurements.isEmpty) return -1;
    if (measurements.length == 1) return measurements.first;

    // 去极值：排序后去掉最大和最小值
    measurements.sort();
    final trimmed = measurements.length > 2
        ? measurements.sublist(1, measurements.length - 1)
        : measurements;

    // 取平均
    return trimmed.reduce((a, b) => a + b) / trimmed.length;
  }

  /// 运行下载速度测试（多线程并行版本，流式返回实时速度）
  Stream<double> runDownloadTestParallel() async* {
    _isTestRunning = true;
    final startTime = DateTime.now();
    final testDuration = Duration(seconds: AppConstants.downloadTestDurationSeconds);
    final warmupEnd = startTime.add(Duration(milliseconds: AppConstants.warmupDurationMs));
    final connections = await _getParallelConnections();

    // 共享估算器
    final estimator = ChunkSizeEstimator();

    // StreamController 用于合并多个并行任务的字节流
    final streamController = StreamController<ChunkResult>();
    _activeControllers.add(streamController);
    final subscriptions = <StreamSubscription<ChunkResult>>[];

    try {
      // 启动多个并行下载任务
      for (int i = 0; i < connections; i++) {
        final sub = _downloadChunksStream(startTime, testDuration, estimator)
            .listen(streamController.add);
        subscriptions.add(sub);
      }

      // 监听所有任务完成
      Future.wait(subscriptions.map((s) => s.asFuture())).then((_) {
        streamController.close();
      });

      // 合并字节流，跳过预热阶段
      int totalBytes = 0;
      bool warmupPassed = false;

      await for (final result in streamController.stream) {
        // 预热阶段跳过，不计入
        if (DateTime.now().isBefore(warmupEnd)) {
          estimator.addSample(result.bytes, result.elapsedMs);
          continue;
        }

        // 预热刚结束，重置估算器
        if (!warmupPassed) {
          warmupPassed = true;
          estimator.reset();
        }

        totalBytes += result.bytes;
        final elapsedSeconds = DateTime.now().difference(warmupEnd).inMilliseconds / 1000;
        if (elapsedSeconds > 0) {
          final speedMbps = (totalBytes * 8) / elapsedSeconds / 1000000;
          yield speedMbps;
        }
      }
    } finally {
      _isTestRunning = false;
      _activeControllers.remove(streamController);
    }
  }

  /// 运行上传速度测试（多线程并行版本，流式返回实时速度）
  Stream<double> runUploadTestParallel() async* {
    _isTestRunning = true;
    final startTime = DateTime.now();
    final testDuration = Duration(seconds: AppConstants.uploadTestDurationSeconds);
    final warmupEnd = startTime.add(Duration(milliseconds: AppConstants.warmupDurationMs));
    final connections = await _getParallelConnections();

    // 共享估算器
    final estimator = ChunkSizeEstimator();

    // StreamController 用于合并多个并行任务的字节流
    final streamController = StreamController<ChunkResult>();
    _activeControllers.add(streamController);
    final subscriptions = <StreamSubscription<ChunkResult>>[];

    try {
      // 启动多个并行上传任务
      for (int i = 0; i < connections; i++) {
        final sub = _uploadChunksStream(startTime, testDuration, estimator)
            .listen(streamController.add);
        subscriptions.add(sub);
      }

      // 监听所有任务完成
      Future.wait(subscriptions.map((s) => s.asFuture())).then((_) {
        streamController.close();
      });

      // 合并字节流，跳过预热阶段
      int totalBytes = 0;
      bool warmupPassed = false;

      await for (final result in streamController.stream) {
        // 预热阶段跳过，不计入
        if (DateTime.now().isBefore(warmupEnd)) {
          estimator.addSample(result.bytes, result.elapsedMs);
          continue;
        }

        // 预热刚结束，重置估算器
        if (!warmupPassed) {
          warmupPassed = true;
          estimator.reset();
        }

        totalBytes += result.bytes;
        final elapsedSeconds = DateTime.now().difference(warmupEnd).inMilliseconds / 1000;
        if (elapsedSeconds > 0) {
          final speedMbps = (totalBytes * 8) / elapsedSeconds / 1000000;
          yield speedMbps;
        }
      }
    } finally {
      _isTestRunning = false;
      _activeControllers.remove(streamController);
    }
  }

  /// 下载 chunks 直到时间到，流式返回每个 chunk 的字节数和耗时
  Stream<ChunkResult> _downloadChunksStream(DateTime startTime, Duration duration, ChunkSizeEstimator estimator) async* {
    final endTime = startTime.add(duration);

    while (DateTime.now().isBefore(endTime) && _isTestRunning) {
      final chunkSize = estimator.getNextChunkSize();
      final url = '${AppConstants.downloadTestUrl}&r=$chunkSize-${DateTime.now().millisecondsSinceEpoch}';
      final chunkStopwatch = Stopwatch()..start();

      try {
        final request = http.Request('GET', Uri.parse(url));
        final response = await _client.send(request).timeout(const Duration(seconds: 15));

        final chunks = <int>[];
        await for (final chunk in response.stream) {
          chunks.addAll(chunk);
          if (chunks.length >= chunkSize) break;
        }
        chunkStopwatch.stop();
        yield ChunkResult(bytes: chunks.length, elapsedMs: chunkStopwatch.elapsedMilliseconds);

        // 上报样本用于估算
        if (chunkStopwatch.elapsedMilliseconds > 0) {
          estimator.addSample(chunks.length, chunkStopwatch.elapsedMilliseconds);
        }
      } catch (e) {
        // 单次失败继续下一个 chunk
        chunkStopwatch.stop();
        await Future.delayed(const Duration(milliseconds: 20));
      }
    }
  }

  /// 上传 chunks 直到时间到，流式返回每个 chunk 的字节数和耗时
  Stream<ChunkResult> _uploadChunksStream(DateTime startTime, Duration duration, ChunkSizeEstimator estimator) async* {
    final endTime = startTime.add(duration);

    while (DateTime.now().isBefore(endTime) && _isTestRunning) {
      final chunkSize = estimator.getNextChunkSize();
      final data = List.generate(chunkSize, (i) => Random().nextInt(256));
      final chunkStopwatch = Stopwatch()..start();

      try {
        final request = http.Request('POST', Uri.parse(AppConstants.uploadTestUrl));
        request.bodyBytes = Uint8List.fromList(data);
        request.headers['Content-Type'] = 'application/octet-stream';
        await _client.send(request).timeout(const Duration(seconds: 15));
        chunkStopwatch.stop();

        yield ChunkResult(bytes: request.bodyBytes.length, elapsedMs: chunkStopwatch.elapsedMilliseconds);

        // 上报样本用于估算
        if (chunkStopwatch.elapsedMilliseconds > 0) {
          estimator.addSample(request.bodyBytes.length, chunkStopwatch.elapsedMilliseconds);
        }
      } catch (e) {
        // 单次失败继续下一个 chunk
        chunkStopwatch.stop();
        await Future.delayed(const Duration(milliseconds: 20));
      }
    }
  }

  /// 停止所有运行中的测试
  void stopTest() {
    _isTestRunning = false;
    // 关闭所有活动的 streamController
    for (final controller in _activeControllers) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _activeControllers.clear();
  }

  void dispose() {
    stopTest();
    _client.close();
  }
}

/// Chunk 下载/上传结果
class ChunkResult {
  final int bytes;
  final int elapsedMs;

  ChunkResult({required this.bytes, required this.elapsedMs});
}
