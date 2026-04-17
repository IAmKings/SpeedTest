import '../../../../app/network_provider.dart';

/// Speed test result data model
class SpeedResult {
  final int? id;
  final DateTime timestamp;
  final double downloadSpeed; // Mbps
  final double uploadSpeed;   // Mbps
  final double ping;          // ms
  final double jitter;        // ms
  final String? serverInfo;
  final NetworkType networkType;
  final String? wifiName;
  final int? avgSignalStrength; // dBm

  SpeedResult({
    this.id,
    required this.timestamp,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.ping,
    this.jitter = 0,
    this.serverInfo,
    this.networkType = NetworkType.none,
    this.wifiName,
    this.avgSignalStrength,
  });

  /// Create from database map
  factory SpeedResult.fromMap(Map<String, dynamic> map) {
    return SpeedResult(
      id: map['id'] as int?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      downloadSpeed: (map['download_speed'] as num).toDouble(),
      uploadSpeed: (map['upload_speed'] as num).toDouble(),
      ping: (map['ping'] as num).toDouble(),
      jitter: (map['jitter'] as num?)?.toDouble() ?? 0,
      serverInfo: map['server_info'] as String?,
      networkType: NetworkType.values[map['network_type'] as int? ?? 5],
      wifiName: map['wifi_name'] as String?,
      avgSignalStrength: map['avg_signal_strength'] as int?,
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'download_speed': downloadSpeed,
      'upload_speed': uploadSpeed,
      'ping': ping,
      'jitter': jitter,
      'server_info': serverInfo,
      'network_type': networkType.index,
      'wifi_name': wifiName,
      'avg_signal_strength': avgSignalStrength,
    };
  }

  /// Copy with new values
  SpeedResult copyWith({
    int? id,
    DateTime? timestamp,
    double? downloadSpeed,
    double? uploadSpeed,
    double? ping,
    double? jitter,
    String? serverInfo,
    NetworkType? networkType,
    String? wifiName,
    int? avgSignalStrength,
  }) {
    return SpeedResult(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      ping: ping ?? this.ping,
      jitter: jitter ?? this.jitter,
      serverInfo: serverInfo ?? this.serverInfo,
      networkType: networkType ?? this.networkType,
      wifiName: wifiName ?? this.wifiName,
      avgSignalStrength: avgSignalStrength ?? this.avgSignalStrength,
    );
  }

  /// Get network display string with localization
  /// Pass localization function for WiFi unknown fallback
  String getNetworkDisplayString({
    String wifiUnknownLabel = 'WiFi (unknown)',
  }) {
    if (networkType == NetworkType.wifi) {
      if (wifiName != null && wifiName!.isNotEmpty) {
        if (avgSignalStrength != null) {
          return 'WiFi: $wifiName (${avgSignalStrength}dBm)';
        }
        return 'WiFi: $wifiName';
      }
      // wifiName is null or empty, show unknown fallback
      if (avgSignalStrength != null) {
        return '$wifiUnknownLabel (${avgSignalStrength}dBm)';
      }
      return wifiUnknownLabel;
    }
    switch (networkType) {
      case NetworkType.wifi:
        return wifiUnknownLabel;
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

  /// Get network display string (backward compatible)
  String get networkDisplayString => getNetworkDisplayString();

  @override
  String toString() {
    return 'SpeedResult(id: $id, download: ${downloadSpeed.toStringAsFixed(2)} Mbps, '
        'upload: ${uploadSpeed.toStringAsFixed(2)} Mbps, ping: ${ping.toStringAsFixed(0)} ms, '
        'jitter: ${jitter.toStringAsFixed(0)} ms, network: $networkDisplayString)';
  }
}
