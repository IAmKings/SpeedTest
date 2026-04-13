/// Speed rating utility for converting speed values to ratings
class SpeedRating {
  SpeedRating._();

  /// Get rating label based on download speed in Mbps
  static String getDownloadRating(double speedMbps) {
    if (speedMbps >= 100) return 'Excellent';
    if (speedMbps >= 50) return 'Good';
    if (speedMbps >= 25) return 'Fair';
    if (speedMbps >= 10) return 'Poor';
    return 'Very Poor';
  }

  /// Get rating label based on ping in ms
  static String getPingRating(double pingMs) {
    if (pingMs < 20) return 'Excellent';
    if (pingMs < 50) return 'Good';
    if (pingMs < 100) return 'Fair';
    if (pingMs < 200) return 'Poor';
    return 'Very Poor';
  }

  /// Get normalized score (0-100) for download speed
  static double getDownloadScore(double speedMbps) {
    if (speedMbps >= 100) return 100;
    if (speedMbps >= 50) return 75 + (speedMbps - 50) / 2;
    if (speedMbps >= 25) return 50 + (speedMbps - 25) / 1.25;
    if (speedMbps >= 10) return 25 + (speedMbps - 10) / 0.75;
    return speedMbps / 0.4; // 0-10 Mbps maps to 0-25
  }

  /// Get normalized score (0-100) for ping
  static double getPingScore(double pingMs) {
    if (pingMs <= 0) return 100;
    if (pingMs <= 20) return 100;
    if (pingMs <= 50) return 75 + (50 - pingMs) / 1.2;
    if (pingMs <= 100) return 50 + (100 - pingMs) / 2;
    if (pingMs <= 200) return 25 + (200 - pingMs) / 4;
    return 25 * 200 / pingMs;
  }
}
