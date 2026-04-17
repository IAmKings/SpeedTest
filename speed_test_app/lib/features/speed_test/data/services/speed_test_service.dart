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

  /// 单次 ping 测量
  /// 返回 (success, pingMs)
  Future<(bool, double)> measureOnePing() async {
    await _ensureClient();
    final stopwatch = Stopwatch()..start();
    try {
      final request = await _client!.openUrl('HEAD', Uri.parse(AppConstants.pingTestUrl));
      request.persistentConnection = true;  // keep-alive
      final response = await request.close().timeout(const Duration(seconds: 10));
      await response.drain<void>();
      stopwatch.stop();
      return (true, stopwatch.elapsedMilliseconds.toDouble());
    } catch (e) {
      stopwatch.stop();
      return (false, 0.0);
    }
  }

  /// 优化 Ping 测量：多次测量去极值取平均，同时计算 Jitter
  Future<PingResult> measurePing() async {
    await _ensureClient();
    final measurements = <double>[];

    for (int i = 0; i < AppConstants.pingTestCount; i++) {
      final (success, pingMs) = await measureOnePing();
      if (success) {
        measurements.add(pingMs);
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

  /// 运行下载速度测试（多线程并行，Timer 200ms 固定采样）
  /// - 总时间 11.5s
  /// - 前 1.5s 预热不计入测量
  /// - 后 10s 正式测量，200ms 采样回调速度
  Stream<double> runDownloadTestParallel() async* {
    await _ensureClient();
    _isTestRunning = true;
    final startTime = DateTime.now();
    final warmupEnd = startTime.add(Duration(milliseconds: AppConstants.warmupDurationMs));
    final connections = await _getParallelConnections();

    // 估算器：全程使用
    final estimator = ChunkSizeEstimator();

    // StreamController 用于合并多个并行任务的字节流
    // 数据 StreamController：合并多线程的 ChunkResult
    final dataController = StreamController<ChunkResult>();
    _activeControllers.add(dataController);

    // 速度 StreamController：Timer 写入速度，直接 yield
    final speedController = StreamController<double>();

    final subscriptions = <StreamSubscription<ChunkResult>>[];

    // totalBytes 多线程安全累加
    int totalBytes = 0;
    final measurementStartTime = warmupEnd;

    Timer? speedTimer;

    try {
      // 启动多个并行下载任务（全程运行）
      for (int i = 0; i < connections; i++) {
        final sub = _downloadChunksStream(estimator)
            .listen(dataController.add);
        subscriptions.add(sub);
      }

      // 消费数据 Stream：只做累加（用 listen，不阻塞）
      dataController.stream.listen((result) {
        totalBytes += result.bytes;
      });

      // 监听所有任务完成，关闭 dataController
      Future.wait(subscriptions.map((s) => s.asFuture())).then((_) {
        if (!dataController.isClosed) {
          dataController.close();
        }
      });

      // Timer 200ms 固定采样：计算速度并直接 yield
      speedTimer = Timer.periodic(const Duration(milliseconds: AppConstants.measurementIntervalMs), (_) {
        if (!_isTestRunning) {
          speedTimer?.cancel();
          speedController.close();
          return;
        }

        final now = DateTime.now();
        final elapsedSeconds = now.difference(measurementStartTime).inMilliseconds / 1000;

        // 超过 10s 测量时间，停止采样
        if (elapsedSeconds >= AppConstants.downloadTestDurationSeconds) {
          speedTimer?.cancel();
          speedController.close();
          return;
        }

        // 只在 1.5s 预热之后才计算并 yield
        if (now.isAfter(warmupEnd)) {
          final speed = (totalBytes * 8) / elapsedSeconds / 1000000;
          speedController.add(speed);
        }
      });

      // 消费速度 Stream：yield 到调用方
      await for (final speed in speedController.stream) {
        yield speed;
      }
    } finally {
      speedTimer?.cancel();
      for (final sub in subscriptions) {
        await sub.cancel();
      }
      if (!dataController.isClosed) {
        await dataController.close();
      }
      if (!speedController.isClosed) {
        await speedController.close();
      }
      _activeControllers.remove(dataController);
      _client?.close(force: true);
      _client = null;
      _isTestRunning = false;
    }
  }

  /// 运行上传速度测试（无预热，Timer 200ms 固定采样）
  /// - 总时间 11.5s
  /// - 前 1.5s 数据抛弃
  /// - 后 10s 正式测量，200ms 采样回调速度
  Stream<double> runUploadTestParallel() async* {
    await _ensureClient();
    _isTestRunning = true;
    final startTime = DateTime.now();
    final warmupEnd = startTime.add(Duration(milliseconds: AppConstants.warmupDurationMs));
    final totalDuration = Duration(milliseconds: AppConstants.warmupDurationMs + AppConstants.uploadTestDurationSeconds * 1000);
    final connections = await _getParallelConnections();

    // 数据 StreamController：合并多线程的 ChunkResult
    final dataController = StreamController<ChunkResult>();
    _activeControllers.add(dataController);

    // 速度 StreamController：Timer 写入速度，直接 yield
    final speedController = StreamController<double>();

    final subscriptions = <StreamSubscription<ChunkResult>>[];

    // totalBytes 多线程安全累加
    int totalBytes = 0;
    final measurementStartTime = warmupEnd;

    Timer? speedTimer;

    try {
      // 启动 N 个并发上传任务
      for (int i = 0; i < connections; i++) {
        final sub = _uploadChunksStream(startTime, totalDuration, null, i)
            .listen(dataController.add);
        subscriptions.add(sub);
      }

      // 消费数据 Stream：只做累加（用 listen，不阻塞）
      dataController.stream.listen((result) {
        totalBytes += result.bytes;
      });

      // 监听所有上传任务完成，关闭 dataController
      Future.wait(subscriptions.map((s) => s.asFuture())).then((_) {
        dataController.close();
      });

      // Timer 200ms 固定采样：计算速度并直接 yield
      speedTimer = Timer.periodic(const Duration(milliseconds: AppConstants.measurementIntervalMs), (_) {
        if (!_isTestRunning) {
          speedTimer?.cancel();
          speedController.close();
          return;
        }

        final now = DateTime.now();
        final elapsedSeconds = now.difference(measurementStartTime).inMilliseconds / 1000;

        // 超过 10s 测量时间，停止采样
        if (elapsedSeconds >= AppConstants.uploadTestDurationSeconds) {
          speedTimer?.cancel();
          speedController.close();
          return;
        }

        // 只在 1.5s 预热之后才计算并 yield
        if (now.isAfter(warmupEnd)) {
          final speed = (totalBytes * 8) / elapsedSeconds / 1000000;
          speedController.add(speed);
        }
      });

      // 消费速度 Stream：yield 到调用方
      await for (final speed in speedController.stream) {
        yield speed;
      }
    } finally {
      speedTimer?.cancel();
      for (final sub in subscriptions) {
        await sub.cancel();
      }
      if (!dataController.isClosed) {
        await dataController.close();
      }
      if (!speedController.isClosed) {
        await speedController.close();
      }
      _activeControllers.remove(dataController);
      _client?.close(force: true);
      _client = null;
      _isTestRunning = false;
    }
  }

  /// 下载 chunks 持续下载，流式返回每个 chunk 的字节数和耗时
  /// 使用 keep-alive 连接持续下载
  Stream<ChunkResult> _downloadChunksStream(
    ChunkSizeEstimator estimator,
  ) async* {
    while (_isTestRunning) {
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
    ChunkSizeEstimator? estimator,
    int threadId,
  ) async* {
    final endTime = startTime.add(duration);

    while (DateTime.now().isBefore(endTime) && _isTestRunning) {
      final chunkSize = estimator?.getNextChunkSize() ?? AppConstants.downloadTestDurationSeconds * 100000;
      final data = List.generate(chunkSize, (i) => Random().nextInt(256));
      // Cloudflare 上传端点
      final url = AppConstants.uploadTestUrl;
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

        // 上报样本用于估算（如果估算器存在）
        if (chunkStopwatch.elapsedMilliseconds > 0 && estimator != null) {
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
