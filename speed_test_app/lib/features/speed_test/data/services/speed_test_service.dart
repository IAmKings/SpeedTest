import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';

/// Speed test service using Cloudflare Speed Test API
/// 优化版：支持多线程并行测速、更准确的计算逻辑
class SpeedTestService {
  final http.Client _client;
  bool _isTestRunning = false;
  static const String _parallelConnectionsKey = 'parallel_connections';

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

  /// 运行下载速度测试（优化版：修正计算逻辑 + 预热阶段）
  Stream<SpeedMeasurement> runDownloadTest() async* {
    _isTestRunning = true;
    final random = Random();

    try {
      final testDuration = Duration(seconds: AppConstants.downloadTestDurationSeconds);
      final endTime = DateTime.now().add(testDuration);
      final interval = Duration(milliseconds: AppConstants.measurementIntervalMs);
      final warmupEnd = DateTime.now().add(Duration(milliseconds: AppConstants.warmupDurationMs));

      int totalBytes = 0;
      final allMeasurements = <double>[];
      DateTime lastUpdate = DateTime.now();

      while (DateTime.now().isBefore(endTime) && _isTestRunning) {
        final chunkSize = 500000 + random.nextInt(500000); // 500KB-1MB
        final url = '${AppConstants.downloadTestUrl}&r=$chunkSize-${DateTime.now().millisecondsSinceEpoch}';

        try {
          final request = http.Request('GET', Uri.parse(url));
          final response = await _client.send(request).timeout(const Duration(seconds: 15));

          final chunks = <int>[];
          await for (final chunk in response.stream) {
            chunks.addAll(chunk);
            if (chunks.length >= chunkSize) break;
          }

          final bytesReceived = chunks.length;
          totalBytes += bytesReceived;
          final now = DateTime.now();
          final elapsed = now.difference(lastUpdate).inMilliseconds;

          // 预热阶段结束后才开始记录测量
          if (now.isAfter(warmupEnd) && elapsed >= interval.inMilliseconds) {
            final speedBps = (totalBytes * 8) / (elapsed / 1000);
            final speedMbps = speedBps / 1000000;
            allMeasurements.add(speedMbps);
            yield SpeedMeasurement(speedMbps: speedMbps, bytesReceived: totalBytes);
            totalBytes = 0;
            lastUpdate = now;
          }
        } catch (e) {
          // 单次失败继续
        }

        await Future.delayed(const Duration(milliseconds: 50));
      }

      // 测试结束后返回中位数
      if (allMeasurements.isNotEmpty) {
        allMeasurements.sort();
        final medianIndex = allMeasurements.length ~/ 2;
        final medianMbps = allMeasurements[medianIndex];
        yield SpeedMeasurement(speedMbps: medianMbps, bytesReceived: totalBytes);
      }
    } finally {
      _isTestRunning = false;
    }
  }

  /// 运行下载速度测试（多线程并行版本）
  Future<double> runDownloadTestParallel() async {
    _isTestRunning = true;
    final random = Random();
    final testDuration = Duration(seconds: AppConstants.downloadTestDurationSeconds);
    final connections = await _getParallelConnections();

    try {
      // 并发执行多个下载任务并汇总结果
      final totalBytes = await _runParallelTasks(
        count: connections,
        duration: testDuration,
        random: random,
        isDownload: true,
      );

      final totalSeconds = testDuration.inMilliseconds / 1000;
      final speedBps = (totalBytes * 8) / totalSeconds;
      return speedBps / 1000000;
    } finally {
      _isTestRunning = false;
    }
  }

  /// 运行上传速度测试（多线程并行版本）
  Future<double> runUploadTestParallel() async {
    _isTestRunning = true;
    final random = Random();
    final testDuration = Duration(seconds: AppConstants.uploadTestDurationSeconds);
    final connections = await _getParallelConnections();

    try {
      final totalBytes = await _runParallelTasks(
        count: connections,
        duration: testDuration,
        random: random,
        isDownload: false,
      );

      final totalSeconds = testDuration.inMilliseconds / 1000;
      final speedBps = (totalBytes * 8) / totalSeconds;
      return speedBps / 1000000;
    } finally {
      _isTestRunning = false;
    }
  }

  /// 通用并行任务执行器
  Future<int> _runParallelTasks({
    required int count,
    required Duration duration,
    required Random random,
    required bool isDownload,
  }) async {
    final tasks = List.generate(
      count,
      (_) => isDownload
          ? _downloadChunksUntil(random, duration)
          : _uploadChunksUntil(random, duration),
    );

    final results = await Future.wait(tasks);
    return results.reduce((a, b) => a + b);
  }

  Future<int> _downloadChunksUntil(Random random, Duration duration) async {
    final endTime = DateTime.now().add(duration);
    int totalBytes = 0;

    while (DateTime.now().isBefore(endTime) && _isTestRunning) {
      final chunkSize = 500000 + random.nextInt(500000);
      final url = '${AppConstants.downloadTestUrl}&r=$chunkSize-${DateTime.now().millisecondsSinceEpoch}';

      try {
        final request = http.Request('GET', Uri.parse(url));
        final response = await _client.send(request).timeout(const Duration(seconds: 15));

        final chunks = <int>[];
        await for (final chunk in response.stream) {
          chunks.addAll(chunk);
          if (chunks.length >= chunkSize) break;
        }
        totalBytes += chunks.length;
      } catch (e) {
        // 单次失败继续下一个 chunk
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }

    return totalBytes;
  }

  Future<int> _uploadChunksUntil(Random random, Duration duration) async {
    final endTime = DateTime.now().add(duration);
    int totalBytes = 0;

    while (DateTime.now().isBefore(endTime) && _isTestRunning) {
      final chunkSize = 100000 + random.nextInt(100000);
      final data = List.generate(chunkSize, (i) => random.nextInt(256));

      try {
        final request = http.Request('POST', Uri.parse(AppConstants.uploadTestUrl));
        request.bodyBytes = Uint8List.fromList(data);
        request.headers['Content-Type'] = 'application/octet-stream';
        await _client.send(request).timeout(const Duration(seconds: 15));
        totalBytes += chunkSize;
      } catch (e) {
        // 单次失败继续下一个 chunk
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }

    return totalBytes;
  }

  /// 运行上传速度测试（优化版）
  Stream<SpeedMeasurement> runUploadTest() async* {
    _isTestRunning = true;
    final random = Random();

    try {
      final testDuration = Duration(seconds: AppConstants.uploadTestDurationSeconds);
      final endTime = DateTime.now().add(testDuration);
      final interval = Duration(milliseconds: AppConstants.measurementIntervalMs);
      final warmupEnd = DateTime.now().add(Duration(milliseconds: AppConstants.warmupDurationMs));

      int totalBytes = 0;
      final allMeasurements = <double>[];
      DateTime lastUpdate = DateTime.now();

      while (DateTime.now().isBefore(endTime) && _isTestRunning) {
        final chunkSize = 100000 + random.nextInt(100000); // 100KB-200KB
        final data = List.generate(chunkSize, (i) => random.nextInt(256));

        try {
          final request = http.Request('POST', Uri.parse(AppConstants.uploadTestUrl));
          request.bodyBytes = Uint8List.fromList(data);
          request.headers['Content-Type'] = 'application/octet-stream';
          await _client.send(request).timeout(const Duration(seconds: 15));

          totalBytes += chunkSize;
          final now = DateTime.now();
          final elapsed = now.difference(lastUpdate).inMilliseconds;

          if (now.isAfter(warmupEnd) && elapsed >= interval.inMilliseconds) {
            final speedBps = (totalBytes * 8) / (elapsed / 1000);
            final speedMbps = speedBps / 1000000;
            allMeasurements.add(speedMbps);
            yield SpeedMeasurement(speedMbps: speedMbps, bytesReceived: totalBytes);
            totalBytes = 0;
            lastUpdate = now;
          }
        } catch (e) {
          // 继续
        }

        await Future.delayed(const Duration(milliseconds: 50));
      }

      // 返回中位数
      if (allMeasurements.isNotEmpty) {
        allMeasurements.sort();
        final medianIndex = allMeasurements.length ~/ 2;
        final medianMbps = allMeasurements[medianIndex];
        yield SpeedMeasurement(speedMbps: medianMbps, bytesReceived: totalBytes);
      }
    } finally {
      _isTestRunning = false;
    }
  }

  /// 停止所有运行中的测试
  void stopTest() {
    _isTestRunning = false;
  }

  void dispose() {
    _client.close();
  }
}

/// 速度测量数据
class SpeedMeasurement {
  final double speedMbps;
  final int bytesReceived;

  SpeedMeasurement({required this.speedMbps, required this.bytesReceived});
}
