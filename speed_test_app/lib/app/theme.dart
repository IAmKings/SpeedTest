import 'package:flutter/material.dart';

/// Material Design 3 Theme System
/// 测速 App 专用主题
class AppTheme {
  AppTheme._();

  // 品牌色
  static const Color _primarySeed = Color(0xFF2563EB);

  // 下载速度颜色等级
  static const Color speedExcellent = Color(0xFF22C55E); // >100 Mbps
  static const Color speedGood = Color(0xFF84CC16);      // 50-100 Mbps
  static const Color speedFair = Color(0xFFFACC15);      // 25-50 Mbps
  static const Color speedPoor = Color(0xFFF97316);      // 10-25 Mbps
  static const Color speedVeryPoor = Color(0xFFEF4444);  // <10 Mbps

  // 测速指标专属颜色 - 用于区分下载、上传、Ping 三个指标
  static const Color downloadColor = Color(0xFF2563EB);  // 蓝色 - 下载
  static const Color uploadColor = Color(0xFF22C55E);    // 绿色 - 上传
  static const Color pingColor = Color(0xFFA855F7);      // 紫色 - Ping

  static Color getSpeedColor(double speedMbps) {
    if (speedMbps >= 100) return speedExcellent;
    if (speedMbps >= 50) return speedGood;
    if (speedMbps >= 25) return speedFair;
    if (speedMbps >= 10) return speedPoor;
    return speedVeryPoor;
  }

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primarySeed,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: colorScheme.surfaceContainerHighest,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primarySeed,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: colorScheme.surfaceContainerHighest,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }
}
