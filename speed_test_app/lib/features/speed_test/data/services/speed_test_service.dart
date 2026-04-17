import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
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

/// Ping/Jitter 测量结果
class PingResult {
  final double ping;    // ms，中位数
  final double jitter;  // ms，方差

  PingResult({required this.ping, required this.jitter});
}

/// Speed test service using Cloudflare Speed Test API
/// 优化版：支持原生 HttpClient、连接池复用、keep-alive、多线程并行测速、流式实时速度更新、带预热阶段
class SpeedTestService {
  HttpClient? _client;
  bool _isTestRunning = false;
  static const String _parallelConnectionsKey = 'parallel_connections';

  // StreamController 引用，用于 stopTest 时清理
  final List<StreamController<ChunkResult>> _activeControllers = [];

  SpeedTestService();

  bool get isTestRunning => _isTestRunning;

  /// 创建配置好的 HttpClient
  /// - 连接池复用：maxConnectionsPerHost
  /// - keep-alive：persistentConnection = true
  HttpClient _getConfiguredClient() {
    final client = HttpClient();
    // 连接池大小，每个 host 最多 8 个并发连接
    client.maxConnectionsPerHost = AppConstants.parallelConnections;
    return client;
  }

  /// Get parallel connections from settings (default 3)
  Future<int> _getParallelConnections() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_parallelConnectionsKey) ?? AppConstants.parallelConnections;
  }

  /// 初始化 HttpClient
  Future<void> _ensureClient() async {
    _client ??= _getConfiguredClient();
  }

  /// 优化 Ping 测量：多次测量去极值取平均，同时计算 Jitter
  Future<PingResult> measurePing() async {
    await _ensureClient();
    final measurements = <double>[];

    for (int i = 0; i < AppConstants.pingTestCount; i++) {
      final stopwatch = Stopwatch()..start();
      try {
        // 使用原生 HttpClient HEAD 请求
        final request = await _client!.openUrl('HEAD', Uri.parse(AppConstants.pingTestUrl));
        request.persistentConnection = true;  // keep-alive
        final response = await request.close().timeout(const Duration(seconds: 10));
        // 消耗响应体以关闭连接
        await response.drain<void>();
        stopwatch.stop();
        measurements.add(stopwatch.elapsedMilliseconds.toDouble());
      } catch (e) {
        // 失败不计入
      }
      if (i < AppConstants.pingTestCount - 1) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    if (measurements.isEmpty) return PingResult(ping: -1, jitter: 0);
    if (measurements.length == 1) return PingResult(ping: measurements.first, jitter: 0);

    // 去极值：排序后去掉最大和最小值
    measurements.sort();
    final trimmed = measurements.length > 2
        ? measurements.sublist(1, measurements.length - 1)
        : measurements;

    // 取平均作为 Ping
    final ping = trimmed.reduce((a, b) => a + b) / trimmed.length;

    // 计算方差作为 Jitter
    final mean = ping;
    final variance = trimmed.map((r) => pow(r - mean, 2)).reduce((a, b) => a + b) / trimmed.length;
    final jitter = sqrt(variance);

    return PingResult(ping: ping, jitter: jitter);
  }

  /// 运行下载速度测试（预热 + 多线程并行，流式返回实时速度）
  /// FR-002: 预热阶段单线程持续下载 500MB，测量阶段多线程并发
  Stream<double> runDownloadTestParallel() async* {
    await _ensureClient();
    _isTestRunning = true;
    final startTime = DateTime.now();
    final warmupDuration = Duration(milliseconds: AppConstants.warmupDurationMs);
    final testDuration = Duration(seconds: AppConstants.downloadTestDurationSeconds);
    final warmupEnd = startTime.add(warmupDuration);
    final connections = await _getParallelConnections();

    // 预热阶段估算器
    final warmupEstimator = ChunkSizeEstimator();

    // ========== 阶段1: 预热（0-2s 单线程持续下载）==========
    // 单线程预热，让 TCP cwnd 完成慢启动爬坡
    await for (final result in _downloadChunksStream(startTime, warmupDuration, warmupEstimator, 0)) {
      warmupEstimator.addSample(result.bytes, result.elapsedMs);
    }

    // ========== 阶段2: 测量（2-12s 多线程并发）==========
    if (!_isTestRunning) return;

    // 测量阶段使用新的估算器
    final measurementEstimator = ChunkSizeEstimator();

    // StreamController 用于合并多个并行任务的字节流
    final streamController = StreamController<ChunkResult>();
    _activeControllers.add(streamController);
    final subscriptions = <StreamSubscription<ChunkResult>>[];

    try {
      // 启动多个并行下载任务
      for (int i = 0; i < connections; i++) {
        final sub = _downloadChunksStream(warmupEnd, testDuration, measurementEstimator, i)
            .listen(streamController.add);
        subscriptions.add(sub);
      }

      // 监听所有任务完成
      Future.wait(subscriptions.map((s) => s.asFuture())).then((_) {
        streamController.close();
      });

      // 合并字节流，计算速度
      int totalBytes = 0;
      final measurementStart = DateTime.now();

      await for (final result in streamController.stream) {
        if (!_isTestRunning) break;

        totalBytes += result.bytes;
        final elapsedSeconds = DateTime.now().difference(measurementStart).inMilliseconds / 1000;
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

  /// 运行上传速度测试（预热 + 多线程并行，流式返回实时速度）
  /// FR-005: 预热阶段 N 个并发同时上传，测量阶段持续上传
  Stream<double> runUploadTestParallel() async* {
    await _ensureClient();
    _isTestRunning = true;
    final startTime = DateTime.now();
    final warmupDuration = Duration(milliseconds: AppConstants.warmupDurationMs);
    final testDuration = Duration(seconds: AppConstants.uploadTestDurationSeconds);
    final warmupEnd = startTime.add(warmupDuration);
    final connections = await _getParallelConnections();

    // 预热阶段估算器
    final warmupEstimator = ChunkSizeEstimator();

    // ========== 阶段1: 预热（0-2s 多线程并发上传）==========
    // 多线程并发预热，让所有连接的 TCP cwnd 同时爬坡
    final warmupStreamController = StreamController<ChunkResult>();
    _activeControllers.add(warmupStreamController);
    final warmupSubscriptions = <StreamSubscription<ChunkResult>>[];

    try {
      for (int i = 0; i < connections; i++) {
        final sub = _uploadChunksStream(startTime, warmupDuration, warmupEstimator, i)
            .listen(warmupStreamController.add);
        warmupSubscriptions.add(sub);
      }

      Future.wait(warmupSubscriptions.map((s) => s.asFuture())).then((_) {
        warmupStreamController.close();
      });

      await for (final result in warmupStreamController.stream) {
        warmupEstimator.addSample(result.bytes, result.elapsedMs);
      }
    } finally {
      _activeControllers.remove(warmupStreamController);
    }

    // ========== 阶段2: 测量（2-12s 多线程并发）==========
    if (!_isTestRunning) return;

    final measurementEstimator = ChunkSizeEstimator();

    final streamController = StreamController<ChunkResult>();
    _activeControllers.add(streamController);
    final subscriptions = <StreamSubscription<ChunkResult>>[];

    try {
      for (int i = 0; i < connections; i++) {
        final sub = _uploadChunksStream(warmupEnd, testDuration, measurementEstimator, i)
            .listen(streamController.add);
        subscriptions.add(sub);
      }

      Future.wait(subscriptions.map((s) => s.asFuture())).then((_) {
        streamController.close();
      });

      int totalBytes = 0;
      final measurementStart = DateTime.now();

      await for (final result in streamController.stream) {
        if (!_isTestRunning) break;

        totalBytes += result.bytes;
        final elapsedSeconds = DateTime.now().difference(measurementStart).inMilliseconds / 1000;
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
  /// 使用 keep-alive 连接持续下载
  Stream<ChunkResult> _downloadChunksStream(
    DateTime startTime,
    Duration duration,
    ChunkSizeEstimator estimator,
    int threadId,
  ) async* {
    final endTime = startTime.add(duration);

    while (DateTime.now().isBefore(endTime) && _isTestRunning) {
      final chunkSize = estimator.getNextChunkSize();
      // 动态控制下载大小（Cloudflare 只支持 bytes 参数）
      final url = 'https://speed.cloudflare.com/__down?bytes=$chunkSize';
      final chunkStopwatch = Stopwatch()..start();

      try {
        final request = await _client!.getUrl(Uri.parse(url));
        // FR-001 要求：显式设置 persistentConnection = true
        request.persistentConnection = true;

        final response = await request.close().timeout(const Duration(seconds: 15));

        final chunks = <int>[];
        await for (final chunk in response) {
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
  /// 使用 keep-alive 连接持续上传
  Stream<ChunkResult> _uploadChunksStream(
    DateTime startTime,
    Duration duration,
    ChunkSizeEstimator estimator,
    int threadId,
  ) async* {
    final endTime = startTime.add(duration);

    while (DateTime.now().isBefore(endTime) && _isTestRunning) {
      final chunkSize = estimator.getNextChunkSize();
      final data = List.generate(chunkSize, (i) => Random().nextInt(256));
      // Cloudflare 上传端点
      final url = '${AppConstants.uploadTestUrl}';
      final chunkStopwatch = Stopwatch()..start();

      try {
        final request = await _client!.postUrl(Uri.parse(url));
        // FR-001 要求：显式设置 persistentConnection = true
        request.persistentConnection = true;
        request.headers.set('Content-Type', 'application/octet-stream');
        request.add(Uint8List.fromList(data));

        await request.close().timeout(const Duration(seconds: 15));
        chunkStopwatch.stop();

        yield ChunkResult(bytes: chunkSize, elapsedMs: chunkStopwatch.elapsedMilliseconds);

        // 上报样本用于估算
        if (chunkStopwatch.elapsedMilliseconds > 0) {
          estimator.addSample(chunkSize, chunkStopwatch.elapsedMilliseconds);
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
    _client?.close(force: true);
    _client = null;
  }
}

/// Chunk 下载/上传结果
class ChunkResult {
  final int bytes;
  final int elapsedMs;

  ChunkResult({required this.bytes, required this.elapsedMs});
}
