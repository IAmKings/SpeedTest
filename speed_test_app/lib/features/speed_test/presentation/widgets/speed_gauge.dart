import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../app/theme.dart';

/// Speed gauge widget displaying current download/upload speed
class SpeedGauge extends StatelessWidget {
  final double speed;
  final double maxSpeed;
  final String label;
  final String unit;
  final bool isActive;

  const SpeedGauge({
    super.key,
    required this.speed,
    this.maxSpeed = 200,
    required this.label,
    this.unit = 'Mbps',
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final speedColor = AppTheme.getSpeedColor(speed);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 200,
          height: 120,
          child: CustomPaint(
            painter: _GaugePainter(
              speed: speed,
              maxSpeed: maxSpeed,
              color: speedColor,
              backgroundColor: colorScheme.surfaceContainerHighest,
              isActive: isActive,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      speed.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: speedColor,
                          ),
                    ),
                    Text(
                      unit,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double speed;
  final double maxSpeed;
  final Color color;
  final Color backgroundColor;
  final bool isActive;

  _GaugePainter({
    required this.speed,
    required this.maxSpeed,
    required this.color,
    required this.backgroundColor,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 10;

    // Background arc
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      bgPaint,
    );

    // Speed arc
    final speedPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final sweepAngle = (speed / maxSpeed).clamp(0.0, 1.0) * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      sweepAngle,
      false,
      speedPaint,
    );

    // Tick marks
    final tickPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i <= 4; i++) {
      final angle = math.pi + (math.pi * i / 4);
      final innerRadius = radius - 20;
      final outerRadius = radius - 14;
      final start = Offset(
        center.dx + innerRadius * math.cos(angle),
        center.dy + innerRadius * math.sin(angle),
      );
      final end = Offset(
        center.dx + outerRadius * math.cos(angle),
        center.dy + outerRadius * math.sin(angle),
      );
      canvas.drawLine(start, end, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.speed != speed ||
        oldDelegate.color != color ||
        oldDelegate.isActive != isActive;
  }
}
