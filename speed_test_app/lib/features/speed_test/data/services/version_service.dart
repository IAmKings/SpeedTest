import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:permission_handler/permission_handler.dart';

/// Version information from GitHub release
class VersionInfo {
  final String version;
  final String downloadUrl;
  final String releaseNotes;
  final String tagName;

  const VersionInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.tagName,
  });

  @override
  String toString() => 'VersionInfo($version)';
}

/// Service for checking and downloading app updates from GitHub
class VersionService {
  static const String _skipVersionKey = 'skip_version';
  static const String _owner = 'IAmKings';
  static const String _repo = 'SpeedTest';

  /// Check if a newer version is available
  /// Returns VersionInfo if update available, null otherwise
  Future<VersionInfo?> checkLatestVersion() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$_owner/$_repo/releases/latest'),
        headers: {'Accept': 'application/vnd.github+json'},
      );

      if (response.statusCode != 200) {
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = json['tag_name'] as String? ?? '';
      final version = tagName.startsWith('v') ? tagName.substring(1) : tagName;

      // Find APK asset
      String? apkUrl;
      final assets = json['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
          break;
        }
      }

      if (apkUrl == null) {
        return null;
      }

      return VersionInfo(
        version: version,
        downloadUrl: apkUrl,
        releaseNotes: json['body'] as String? ?? '',
        tagName: tagName,
      );
    } catch (e) {
      return null;
    }
  }

  /// Check if user has skipped this version
  Future<bool> isVersionSkipped(String version) async {
    final prefs = await SharedPreferences.getInstance();
    final skipped = prefs.getString(_skipVersionKey);
    return skipped == version;
  }

  /// Skip this version
  Future<void> skipVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_skipVersionKey, version);
  }

  /// Download APK file and return local file path
  /// Emits progress callbacks as percentage (0-100)
  Future<String> downloadApk(
    String downloadUrl, {
    void Function(int progress)? onProgress,
  }) async {
    final response = await http.Client().send(
      http.Request('GET', Uri.parse(downloadUrl)),
    );

    if (response.statusCode != 200) {
      throw Exception('Download failed: ${response.statusCode}');
    }

    final contentLength = response.contentLength ?? 0;
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/speed_test_update.apk');

    final sink = file.openWrite();
    var received = 0;

    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (contentLength > 0 && onProgress != null) {
        onProgress((received * 100 / contentLength).round());
      }
    }

    await sink.close();
    return file.path;
  }

  /// Check if we can install APK (user has granted install permission)
  Future<bool> canInstallApk() async {
    // Request permission - this will prompt user if needed
    final status = await Permission.requestInstallPackages.status;
    return status.isGranted;
  }

  /// Request install packages permission
  /// Returns true if granted, false otherwise
  Future<bool> requestInstallPermission() async {
    final status = await Permission.requestInstallPackages.request();
    return status.isGranted;
  }

  /// Open Android settings for the app to enable "Install unknown apps"
  Future<void> openInstallSettings() async {
    const androidIntent = AndroidIntent(
      action: 'android.settings.MANAGE_UNKNOWN_APP_SOURCES',
    );
    await androidIntent.launch();
  }

  /// Install the downloaded APK
  /// Returns true if installation intent was launched
  Future<bool> installApk(String filePath) async {
    try {
      // Check if we have permission first
      if (!await canInstallApk()) {
        // Try to request permission
        final granted = await requestInstallPermission();
        if (!granted) {
          // Permission denied, open settings
          await openInstallSettings();
          return false;
        }
      }

      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }

      // Launch APK installer
      final androidIntent = AndroidIntent(
        action: 'android.intent.action.INSTALL_PACKAGE',
        arguments: {
          'android.content.pm.extra.INSTALL_URI': filePath,
        },
      );
      await androidIntent.launch();
      return true;
    } catch (e) {
      return false;
    }
  }
}
