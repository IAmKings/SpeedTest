import 'package:flutter/material.dart';

/// Ping indicator widget showing network latency with animated dots
class PingIndicator extends StatelessWidget {
  final double ping;
  final bool isActive;

  const PingIndicator({
    super.key,
    required this.ping,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pingColor = _getPingColor(ping);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              ping < 0 ? '--' : ping.toStringAsFixed(0),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: pingColor,
                  ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 2),
              child: Text(
                'ms',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              const _AnimatedDots(),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Ping',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Color _getPingColor(double ping) {
    if (ping < 0) return Colors.grey;
    if (ping < 20) return Colors.green;
    if (ping < 50) return Colors.lightGreen;
    if (ping < 100) return Colors.orange;
    return Colors.red;
  }
}

class _AnimatedDots extends StatefulWidget {
  const _AnimatedDots();

  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final value = ((_controller.value + delay) % 1.0);
            final opacity = (value < 0.5 ? value * 2 : (1 - value) * 2).clamp(0.3, 1.0);
            return Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
