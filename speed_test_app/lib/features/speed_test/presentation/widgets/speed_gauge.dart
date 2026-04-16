import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../app/theme.dart';

/// Speed gauge widget with animated needle and 270-degree arc
/// Supports both Mbps and MB/s units with dynamic tick marks
class SpeedGauge extends StatefulWidget {
  final double speed;        // Speed value in selected unit
  final String label;
  final String unit;         // Display unit string
  final bool isMbps;         // Whether using Mbps scale (true) or MB/s scale (false)

  const SpeedGauge({
    super.key,
    required this.speed,
    required this.label,
    required this.unit,
    this.isMbps = true,
  });

  // Tick marks for Mbps: [0, 5, 10, 50, 100, 250, 500, 1000, 2000]
  static const List<double> tickMarksMbps = [0, 5, 10, 50, 100, 250, 500, 1000, 2000];

  // Tick marks for MB/s: [0, 1, 2, 5, 10, 25, 50, 100, 200]
  static const List<double> tickMarksMBs = [0, 1, 2, 5, 10, 25, 50, 100, 200];

  /// Calculate angle for a given speed based on the current unit scale
  /// Uses interval-based calculation: 9 tick marks create 8 intervals of 33.75 degrees each
  static double speedToAngle(double speed, bool isMbps) {
    if (speed <= 0) return 0;

    // Select tick marks based on unit
    final tickMarks = isMbps ? tickMarksMbps : tickMarksMBs;

    // Clamp speed to valid range
    if (speed <= tickMarks[1]) {
      // In first interval [0, firstTick], map proportionally to [0, 33.75]
      const intervalAngle = 270.0 / 8; // 33.75 degrees per interval
      final ratio = speed / tickMarks[1];
      // Ensure minimum 1 degree for non-zero speeds to avoid jitter
      return math.max(1.0, ratio * intervalAngle);
    }

    if (speed >= tickMarks.last) {
      // At or beyond max, return max angle
      return 270.0;
    }

    // Find the interval this speed falls into
    const intervalAngle = 270.0 / 8; // 33.75 degrees per interval

    for (int i = 1; i < tickMarks.length - 1; i++) {
      final lowerTick = tickMarks[i];
      final upperTick = tickMarks[i + 1];

      if (speed >= lowerTick && speed <= upperTick) {
        // Calculate position within this interval
        final intervalProgress = (speed - lowerTick) / (upperTick - lowerTick);
        // Each interval starts at (i * 33.75) degrees
        final intervalStartAngle = i * intervalAngle;
        final angle = intervalStartAngle + (intervalProgress * intervalAngle);
        // Ensure minimum 1 degree for non-zero speeds to avoid jitter
        return math.max(1.0, angle);
      }
    }

    return 0; // Fallback, should not reach here
  }

  @override
  State<SpeedGauge> createState() => _SpeedGaugeState();
}

class _SpeedGaugeState extends State<SpeedGauge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _currentAngle = 0;
  double _targetAngle = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _targetAngle = SpeedGauge.speedToAngle(widget.speed, widget.isMbps);
    _currentAngle = _targetAngle;
  }

  @override
  void didUpdateWidget(SpeedGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.speed != widget.speed || oldWidget.isMbps != widget.isMbps) {
      _animateToNewAngle();
    }
  }

  void _animateToNewAngle() {
    _currentAngle = _animation.value;
    _targetAngle = SpeedGauge.speedToAngle(widget.speed, widget.isMbps);

    _animation = Tween<double>(
      begin: _currentAngle,
      end: _targetAngle,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final speedColor = AppTheme.getSpeedColor(widget.speed);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 260,
          height: 180,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Stack(
                children: [
                  CustomPaint(
                    painter: _GaugePainter(
                      speed: widget.speed,
                      animatedAngle: _animation.value,
                      isMbps: widget.isMbps,
                      color: speedColor,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                    ),
                    size: const Size(260, 180),
                  ),
                  // Speed value centered and below the needle center
                  Positioned.fill(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 140),
                        child: Text(
                          widget.speed.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: speedColor,
                              ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.label,
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
  final double animatedAngle; // Animated angle from the state
  final bool isMbps;
  final Color color;
  final Color backgroundColor;

  // Arc configuration: 270 degrees starting from 135°
  static const double _startAngle = 135.0;
  static const double _sweepAngle = 270.0;

  _GaugePainter({
    required this.speed,
    required this.animatedAngle,
    required this.isMbps,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.7);
    final radius = size.width / 2 - 20;

        // Convert degrees to radians for drawing
    final startRad = _startAngle * math.pi / 180.0;
    final sweepRad = _sweepAngle * math.pi / 180.0;

        // Draw circular background for the gauge
    final bgCirclePaint = Paint()
      ..color = backgroundColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius + 20, bgCirclePaint);

    // Draw background arc
    final bgPaint = Paint()
      ..color = HSLColor.fromColor(backgroundColor).withLightness(0.8).toColor()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startRad,
      sweepRad,
      false,
      bgPaint,
    );

    // Draw speed arc (using animated angle for smooth transition)
    // Use positive sweepRad with usePathClockwise=false for counter-clockwise drawing
    // From 135° counter-clockwise to 45° (270° sweep)
    final speedSweepRad = (animatedAngle / 270.0) * sweepRad;

    if (speedSweepRad > 0) {
      final speedPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startRad,
        speedSweepRad,
        false,
        speedPaint,
      );
    }

    // Draw tick marks with appropriate labels
    _drawTickMarks(canvas, center, radius);

// Draw needle using animated angle
    // Angle increases counter-clockwise from 135° (left) to 45° (right)
    // Always show needle when there's any angle (including 0 at start position)
    if (animatedAngle >= 0) {
      // Use shorter needle (radius - 25) to avoid overlapping with tick labels at radius + 28
      _drawNeedle(canvas, center, radius - 25, _startAngle + animatedAngle);
    }

    // Draw center circle
    final centerPaint = Paint()..color = color;
    canvas.drawCircle(center, 8, centerPaint);
  }

  void _drawTickMarks(Canvas canvas, Offset center, double radius) {
    // Select tick marks based on unit
    final tickMarks = isMbps
        ? SpeedGauge.tickMarksMbps
        : SpeedGauge.tickMarksMBs;
    final textColor = color.withValues(alpha: 0.7);

    for (int i = 0; i < tickMarks.length; i++) {
      final tickValue = tickMarks[i];
// Calculate angle based on the current unit scale (counter-clockwise from 135°)
      final angleDeg = _startAngle + SpeedGauge.speedToAngle(tickValue, isMbps);
      final angleRad = angleDeg * math.pi / 180.0;

      // Tick line
      final innerRadius = radius + 5;
      final outerRadius = radius + 15;

      final tickPaint = Paint()
        ..color = textColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      final start = Offset(
        center.dx + innerRadius * math.cos(angleRad),
        center.dy + innerRadius * math.sin(angleRad),
      );
      final end = Offset(
        center.dx + outerRadius * math.cos(angleRad),
        center.dy + outerRadius * math.sin(angleRad),
      );

      canvas.drawLine(start, end, tickPaint);

      // Draw label
      final labelRadius = radius + 28;
      final labelOffset = Offset(
        center.dx + labelRadius * math.cos(angleRad),
        center.dy + labelRadius * math.sin(angleRad),
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: _formatTickLabel(tickValue, isMbps),
          style: TextStyle(
            color: textColor,
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Center the text on the position
      textPainter.paint(
        canvas,
        labelOffset - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  String _formatTickLabel(double value, bool isMbps) {
    // Use G for 1000+ values to avoid confusion with kilometers
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}G';
    }
    if (value >= 100) {
      return '${value.toStringAsFixed(0)}';
    }
    if (value >= 10) {
      return '${value.toStringAsFixed(0)}';
    }
    return '${value.toStringAsFixed(value < 1 ? 1 : 0)}';
  }

  void _drawNeedle(Canvas canvas, Offset center, double length, double angleDeg) {
    final angleRad = angleDeg * math.pi / 180.0;

    // Calculate needle tip and base positions
    final needleTip = Offset(
      center.dx + length * math.cos(angleRad),
      center.dy + length * math.sin(angleRad),
    );

    // Perpendicular angle for needle width
    final perpAngle = angleRad + math.pi / 2;
    final halfWidth = 4.0;

    // Needle base points (center area)
    final baseLeft = Offset(
      center.dx + halfWidth * math.cos(perpAngle),
      center.dy + halfWidth * math.sin(perpAngle),
    );
    final baseRight = Offset(
      center.dx - halfWidth * math.cos(perpAngle),
      center.dy - halfWidth * math.sin(perpAngle),
    );

    // Draw shadow first
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final shadowPath = Path()
      ..moveTo(needleTip.dx + 2, needleTip.dy + 2)
      ..lineTo(baseLeft.dx + 2, baseLeft.dy + 2)
      ..lineTo(baseRight.dx + 2, baseRight.dy + 2)
      ..close();
    canvas.drawPath(shadowPath, shadowPaint);

    // Draw needle with gradient
    final needlePath = Path()
      ..moveTo(needleTip.dx, needleTip.dy)
      ..lineTo(baseLeft.dx, baseLeft.dy)
      ..lineTo(baseRight.dx, baseRight.dy)
      ..close();

    // Gradient from tip (brighter) to base (darker)
    final needleGradient = LinearGradient(
      begin: Alignment.center,
      end: Alignment.bottomCenter,
      colors: [
        color,
        HSLColor.fromColor(color).withLightness(0.4).toColor(),
      ],
    );

    final needlePaint = Paint()
      ..shader = needleGradient.createShader(
        Rect.fromPoints(needleTip, center),
      )
      ..style = PaintingStyle.fill;

    canvas.drawPath(needlePath, needlePaint);

    // Draw needle highlight (thin bright line on top)
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final highlightPath = Path()
      ..moveTo(needleTip.dx, needleTip.dy)
      ..lineTo(
        center.dx + (length * 0.7) * math.cos(angleRad),
        center.dy + (length * 0.7) * math.sin(angleRad),
      );
    canvas.drawPath(highlightPath, highlightPaint);

    // Draw center cap with gradient
    final capCenter = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white,
          color,
          HSLColor.fromColor(color).withLightness(0.3).toColor(),
        ],
        stops: const [0.0, 0.3, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: 10));
    canvas.drawCircle(center, 10, capCenter);

    // Draw outer ring of center cap
    final capRing = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, 10, capRing);

    // Draw inner bright dot
    final innerDot = Paint()..color = Colors.white;
    canvas.drawCircle(center, 3, innerDot);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.animatedAngle != animatedAngle ||
        oldDelegate.speed != speed ||
        oldDelegate.isMbps != isMbps ||
        oldDelegate.color != color;
  }
}
