/// App-wide constants
class AppConstants {
  AppConstants._();

  // Cloudflare Speed Test API endpoints
  static const String downloadTestUrl = 'https://speed.cloudflare.com/__down?bytes=10000000';
  static const String uploadTestUrl = 'https://speed.cloudflare.com/__up';
  static const String pingTestUrl = 'https://speed.cloudflare.com/__down?bytes=0';

  // Test configuration
  static const int downloadTestDurationSeconds = 10;
  static const int uploadTestDurationSeconds = 10;
  static const int pingTestCount = 5;
  static const int measurementIntervalMs = 200;
  static const int warmupDurationMs = 1500;
  static const int parallelConnections = 3;

  // UI constants
  static const double gaugeMinValue = 0;
  static const double gaugeMaxValue = 200; // Mbps
  static const double pingExcellent = 20; // ms
  static const double pingGood = 50;
  static const double pingFair = 100;
  static const double pingPoor = 200;

  // Database
  static const String dbName = 'speed_test_history.db';
  static const int dbVersion = 3;
  static const String tableSpeedResults = 'speed_results';
}
