/// Speed test result data model
class SpeedResult {
  final int? id;
  final DateTime timestamp;
  final double downloadSpeed; // Mbps
  final double uploadSpeed;   // Mbps
  final double ping;          // ms
  final String? serverInfo;

  SpeedResult({
    this.id,
    required this.timestamp,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.ping,
    this.serverInfo,
  });

  /// Create from database map
  factory SpeedResult.fromMap(Map<String, dynamic> map) {
    return SpeedResult(
      id: map['id'] as int?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      downloadSpeed: (map['download_speed'] as num).toDouble(),
      uploadSpeed: (map['upload_speed'] as num).toDouble(),
      ping: (map['ping'] as num).toDouble(),
      serverInfo: map['server_info'] as String?,
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
      'server_info': serverInfo,
    };
  }

  /// Copy with new values
  SpeedResult copyWith({
    int? id,
    DateTime? timestamp,
    double? downloadSpeed,
    double? uploadSpeed,
    double? ping,
    String? serverInfo,
  }) {
    return SpeedResult(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      ping: ping ?? this.ping,
      serverInfo: serverInfo ?? this.serverInfo,
    );
  }

  @override
  String toString() {
    return 'SpeedResult(id: $id, download: ${downloadSpeed.toStringAsFixed(2)} Mbps, '
        'upload: ${uploadSpeed.toStringAsFixed(2)} Mbps, ping: ${ping.toStringAsFixed(0)} ms)';
  }
}
