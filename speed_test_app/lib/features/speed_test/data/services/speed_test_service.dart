import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_constants.dart';

/// Speed test service using Cloudflare Speed Test API
class SpeedTestService {
  final http.Client _client;
  bool _isTestRunning = false;

  SpeedTestService({http.Client? client}) : _client = client ?? http.Client();

  bool get isTestRunning => _isTestRunning;

  /// Measure latency (ping) to Cloudflare
  Future<double> measurePing() async {
    final stopwatch = Stopwatch()..start();
    try {
      await _client
          .head(Uri.parse(AppConstants.pingTestUrl))
          .timeout(const Duration(seconds: 10));
      stopwatch.stop();
      return stopwatch.elapsedMilliseconds.toDouble();
    } catch (e) {
      stopwatch.stop();
      return -1; // Indicate failure
    }
  }

  /// Run download speed test
  Stream<SpeedMeasurement> runDownloadTest() async* {
    _isTestRunning = true;
    final random = Random();

    try {
      final testDuration = Duration(seconds: AppConstants.downloadTestDurationSeconds);
      final endTime = DateTime.now().add(testDuration);
      final interval = Duration(milliseconds: AppConstants.measurementIntervalMs);

      int totalBytes = 0;
      DateTime lastUpdate = DateTime.now();

      while (DateTime.now().isBefore(endTime) && _isTestRunning) {
        final chunkSize = 500000 + random.nextInt(500000); // 500KB-1MB random chunk
        final url = '${AppConstants.downloadTestUrl}&r=$chunkSize-${DateTime.now().millisecondsSinceEpoch}';

        try {
          final request = http.Request('GET', Uri.parse(url));
          final response = await _client.send(request).timeout(const Duration(seconds: 5));

          final chunks = <int>[];
          await for (final chunk in response.stream) {
            chunks.addAll(chunk);
            if (chunks.length >= chunkSize) break;
          }

          totalBytes += chunks.length;
          final elapsed = DateTime.now().difference(lastUpdate).inMilliseconds;

          if (elapsed >= interval.inMilliseconds) {
            final speedBps = (totalBytes * 8) / (elapsed / 1000);
            final speedMbps = speedBps / 1000000;
            yield SpeedMeasurement(speedMbps: speedMbps, bytesReceived: totalBytes);
            totalBytes = 0;
            lastUpdate = DateTime.now();
          }
        } catch (e) {
          // Continue test even if one chunk fails
        }

        await Future.delayed(const Duration(milliseconds: 50));
      }
    } finally {
      _isTestRunning = false;
    }
  }

  /// Run upload speed test
  Stream<SpeedMeasurement> runUploadTest() async* {
    _isTestRunning = true;
    final random = Random();

    try {
      final testDuration = Duration(seconds: AppConstants.uploadTestDurationSeconds);
      final endTime = DateTime.now().add(testDuration);
      final interval = Duration(milliseconds: AppConstants.measurementIntervalMs);

      int totalBytes = 0;
      DateTime lastUpdate = DateTime.now();

      while (DateTime.now().isBefore(endTime) && _isTestRunning) {
        final chunkSize = 100000 + random.nextInt(100000); // 100KB-200KB random chunk
        final data = List.generate(chunkSize, (i) => random.nextInt(256));

        try {
          final request = http.Request('POST', Uri.parse(AppConstants.uploadTestUrl));
          request.bodyBytes = Uint8List.fromList(data);
          request.headers['Content-Type'] = 'application/octet-stream';
          await _client.send(request).timeout(const Duration(seconds: 5));

          totalBytes += chunkSize;
          final elapsed = DateTime.now().difference(lastUpdate).inMilliseconds;

          if (elapsed >= interval.inMilliseconds) {
            final speedBps = (totalBytes * 8) / (elapsed / 1000);
            final speedMbps = speedBps / 1000000;
            yield SpeedMeasurement(speedMbps: speedMbps, bytesReceived: totalBytes);
            totalBytes = 0;
            lastUpdate = DateTime.now();
          }
        } catch (e) {
          // Continue test even if one upload fails
        }

        await Future.delayed(const Duration(milliseconds: 50));
      }
    } finally {
      _isTestRunning = false;
    }
  }

  /// Stop all running tests
  void stopTest() {
    _isTestRunning = false;
  }

  void dispose() {
    _client.close();
  }
}

/// Speed measurement data
class SpeedMeasurement {
  final double speedMbps;
  final int bytesReceived;

  SpeedMeasurement({required this.speedMbps, required this.bytesReceived});
}
