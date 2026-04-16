import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';

/// Speed test service using Cloudflare Speed Test API
/// 优化版：支持多线程并行测速、流式实时速度更新、带预热阶段
class SpeedTestService {
  final http.Client _client;
  bool _isTestRunning = false;
  static const String _parallelConnectionsKey = 'parallel_connections';

  // StreamController 引用，用于 stopTest 时清理
  final List<StreamController<int>> _activeControllers = [];

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

    // StreamController 用于合并多个并行任务的字节流
    final streamController = StreamController<int>();
    _activeControllers.add(streamController);
    final subscriptions = <StreamSubscription<int>>[];

    try {
      // 启动多个并行下载任务
      for (int i = 0; i < connections; i++) {
        final sub = _downloadChunksStream(startTime, testDuration)
            .listen(streamController.add);
        subscriptions.add(sub);
      }

      // 监听所有任务完成
      Future.wait(subscriptions.map((s) => s.asFuture())).then((_) {
        streamController.close();
      });

      // 合并字节流，跳过预热阶段
      int totalBytes = 0;
      await for (final bytes in streamController.stream) {
        // 预热阶段跳过，不计入
        if (DateTime.now().isBefore(warmupEnd)) continue;
        totalBytes += bytes;
        final elapsedSeconds = DateTime.now().difference(startTime).inMilliseconds / 1000;
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

    // StreamController 用于合并多个并行任务的字节流
    final streamController = StreamController<int>();
    _activeControllers.add(streamController);
    final subscriptions = <StreamSubscription<int>>[];

    try {
      // 启动多个并行上传任务
      for (int i = 0; i < connections; i++) {
        final sub = _uploadChunksStream(startTime, testDuration)
            .listen(streamController.add);
        subscriptions.add(sub);
      }

      // 监听所有任务完成
      Future.wait(subscriptions.map((s) => s.asFuture())).then((_) {
        streamController.close();
      });

      // 合并字节流，跳过预热阶段
      int totalBytes = 0;
      await for (final bytes in streamController.stream) {
        // 预热阶段跳过，不计入
        if (DateTime.now().isBefore(warmupEnd)) continue;
        totalBytes += bytes;
        final elapsedSeconds = DateTime.now().difference(startTime).inMilliseconds / 1000;
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

  /// 下载 chunks 直到时间到，流式返回每个 chunk 的字节数
  Stream<int> _downloadChunksStream(DateTime startTime, Duration duration) async* {
    final endTime = startTime.add(duration);
    final random = Random();

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
        yield chunks.length;
      } catch (e) {
        // 单次失败继续下一个 chunk
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }
  }

  /// 上传 chunks 直到时间到，流式返回实际发送的字节数
  Stream<int> _uploadChunksStream(DateTime startTime, Duration duration) async* {
    final endTime = startTime.add(duration);
    final random = Random();

    while (DateTime.now().isBefore(endTime) && _isTestRunning) {
      final chunkSize = 100000 + random.nextInt(100000);
      final data = List.generate(chunkSize, (i) => random.nextInt(256));

      try {
        final request = http.Request('POST', Uri.parse(AppConstants.uploadTestUrl));
        request.bodyBytes = Uint8List.fromList(data);
        request.headers['Content-Type'] = 'application/octet-stream';
        await _client.send(request).timeout(const Duration(seconds: 15));

        // 上传成功后 yield 实际发送字节数（与请求体一致）
        yield request.bodyBytes.length;
      } catch (e) {
        // 单次失败继续下一个 chunk
        await Future.delayed(const Duration(milliseconds: 50));
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
