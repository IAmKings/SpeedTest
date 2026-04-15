import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart' as network_info_plus;
import 'package:flutter/services.dart';

/// Network type enumeration
enum NetworkType {
  wifi,
  mobileCmcc, // 中国移动
  mobileCucc, // 中国联通
  mobileCtcc, // 中国电信
  mobileOther, // 其他移动网络
  none, // 无连接
}

/// Network information container
class NetworkDetail {
  final NetworkType type;
  final String? wifiName;
  final int? signalStrength; // dBm
  final double normalizedSignal; // 0.0 ~ 1.0

  const NetworkDetail({
    required this.type,
    this.wifiName,
    this.signalStrength,
    this.normalizedSignal = 0.0,
  });

  /// Create a disconnected network info
  factory NetworkDetail.none() => const NetworkDetail(type: NetworkType.none);

  /// Get display name for network type
  String get typeDisplayName {
    switch (type) {
      case NetworkType.wifi:
        return 'WiFi';
      case NetworkType.mobileCmcc:
        return '中国移动';
      case NetworkType.mobileCucc:
        return '中国联通';
      case NetworkType.mobileCtcc:
        return '中国电信';
      case NetworkType.mobileOther:
        return '移动网络';
      case NetworkType.none:
        return '无连接';
    }
  }

  /// Get display string with optional signal info
  String get displayString {
    if (type == NetworkType.wifi && wifiName != null) {
      if (signalStrength != null) {
        return 'WiFi: $wifiName (${signalStrength}dBm)';
      }
      return 'WiFi: $wifiName';
    }
    return typeDisplayName;
  }

  @override
  String toString() => 'NetworkDetail(type: $type, wifiName: $wifiName, signal: $signalStrength dBm)';
}

/// Network provider for monitoring network state and signal strength
class NetworkProvider extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  final network_info_plus.NetworkInfo _networkInfoPlugin = network_info_plus.NetworkInfo();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  NetworkDetail _currentNetwork = NetworkDetail.none();
  Timer? _signalPollingTimer;
  final List<int> _signalSamples = [];

  static const MethodChannel _channel = MethodChannel('network_info_channel');

  /// Current network info
  NetworkDetail get currentNetwork => _currentNetwork;

  /// Signal samples collected during test
  List<int> get signalSamples => List.unmodifiable(_signalSamples);

  /// Average signal strength in dBm
  int? get avgSignalStrength {
    if (_signalSamples.isEmpty) return null;
    return (_signalSamples.reduce((a, b) => a + b) / _signalSamples.length).round();
  }

  /// Normalized average signal (0.0 ~ 1.0)
  double get avgNormalizedSignal {
    final avg = avgSignalStrength;
    if (avg == null) return 0.0;
    return _normalizeSignal(avg);
  }

  NetworkProvider() {
    _init();
  }

  Future<void> _init() async {
    // Get initial network state
    await _updateNetworkInfo();
    // Start monitoring
    startMonitoring();
  }

  /// Start monitoring network changes
  void startMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      _handleConnectivityChange(results);
    });
  }

  /// Stop monitoring
  void stopMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    stopSignalPolling();
  }

  /// Start polling signal strength during test
  void startSignalPolling() {
    _signalSamples.clear();
    _signalPollingTimer?.cancel();
    _signalPollingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _sampleSignalStrength();
    });
  }

  /// Stop polling and return average
  void stopSignalPolling() {
    _signalPollingTimer?.cancel();
    _signalPollingTimer = null;
  }

  Future<void> _sampleSignalStrength() async {
    if (_currentNetwork.type == NetworkType.wifi) {
      try {
        final wifiResult = await _networkInfoPlugin.getWifiIP();
        if (wifiResult != null) {
          // WiFi IP exists, try to get signal via native channel
          final signal = await _getWifiSignalStrength();
          if (signal != null) {
            _signalSamples.add(signal);
            notifyListeners();
          }
        }
      } catch (_) {
        // Ignore errors during sampling
      }
    }
  }

  Future<int?> _getWifiSignalStrength() async {
    try {
      // Use method channel to get WiFi signal strength
      final result = await _channel.invokeMethod<int>('getWifiSignalStrength');
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleConnectivityChange(List<ConnectivityResult> results) async {
    final hasConnection = results.any((r) => r != ConnectivityResult.none);
    if (!hasConnection) {
      _currentNetwork = NetworkDetail.none();
      notifyListeners();
      return;
    }
    await _updateNetworkInfo();
  }

  Future<void> _updateNetworkInfo() async {
    final results = await _connectivity.checkConnectivity();

    if (results.contains(ConnectivityResult.wifi)) {
      await _updateWifiInfo();
    } else if (results.contains(ConnectivityResult.mobile)) {
      await _updateMobileInfo();
    } else {
      _currentNetwork = NetworkDetail.none();
      notifyListeners();
    }
  }

  Future<void> _updateWifiInfo() async {
    try {
      final wifiName = await _networkInfoPlugin.getWifiName();
      final wifiIP = await _networkInfoPlugin.getWifiIP();

      int? signal;
      if (wifiIP != null) {
        signal = await _getWifiSignalStrength();
      }

      _currentNetwork = NetworkDetail(
        type: NetworkType.wifi,
        wifiName: wifiName?.replaceAll('"', ''),
        signalStrength: signal,
        normalizedSignal: signal != null ? _normalizeSignal(signal) : 0.0,
      );
    } catch (_) {
      _currentNetwork = const NetworkDetail(type: NetworkType.wifi);
    }
    notifyListeners();
  }

  Future<void> _updateMobileInfo() async {
    try {
      final operator = await _getMobileOperator();
      _currentNetwork = NetworkDetail(
        type: operator,
        signalStrength: null,
        normalizedSignal: 0.5, // Default for mobile network
      );
    } catch (_) {
      _currentNetwork = const NetworkDetail(type: NetworkType.mobileOther);
    }
    notifyListeners();
  }

  Future<NetworkType> _getMobileOperator() async {
    try {
      final result = await _channel.invokeMethod<String>('getMobileOperator');
      if (result == null) return NetworkType.mobileOther;

      if (result.contains('移动') || result.contains('CMCC')) {
        return NetworkType.mobileCmcc;
      } else if (result.contains('联通') || result.contains('CUCC') || result.contains('China Unicom')) {
        return NetworkType.mobileCucc;
      } else if (result.contains('电信') || result.contains('CTCC') || result.contains('China Telecom')) {
        return NetworkType.mobileCtcc;
      }
      return NetworkType.mobileOther;
    } catch (_) {
      return NetworkType.mobileOther;
    }
  }

  /// Normalize signal strength from dBm to 0.0 ~ 1.0
  /// WiFi: -30dBm (excellent) ~ -90dBm (poor)
  double _normalizeSignal(int dBm) {
    // Map -90dBm to 0.0, -30dBm to 1.0
    return ((dBm + 90) / 60).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}
