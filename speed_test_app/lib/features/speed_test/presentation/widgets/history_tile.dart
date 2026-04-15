import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/speed_result.dart';
import '../../../../app/theme.dart';

/// History list tile showing a single speed test result
class HistoryTile extends StatelessWidget {
  final SpeedResult result;
  final VoidCallback? onDelete;
  final String downloadLabel;
  final String uploadLabel;
  final String pingLabel;
  final String mbpsUnit;
  final String mbsUnit;
  final String msUnit;
  final bool isMbps;

  const HistoryTile({
    super.key,
    required this.result,
    this.onDelete,
    this.downloadLabel = 'Download',
    this.uploadLabel = 'Upload',
    this.pingLabel = 'Ping',
    this.mbpsUnit = 'Mbps',
    this.mbsUnit = 'MB/s',
    this.msUnit = 'ms',
    this.isMbps = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('HH:mm');

    // Convert speeds to display unit
    final displayDownloadSpeed = isMbps ? result.downloadSpeed : result.downloadSpeed / 8;
    final displayUploadSpeed = isMbps ? result.uploadSpeed : result.uploadSpeed / 8;
    final displayUnit = isMbps ? mbpsUnit : mbsUnit;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateFormat.format(result.timestamp),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  timeFormat.format(result.timestamp),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SpeedColumn(
                    label: downloadLabel,
                    value: displayDownloadSpeed,
                    unit: displayUnit,
                    color: AppTheme.downloadColor,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: colorScheme.outlineVariant,
                ),
                Expanded(
                  child: _SpeedColumn(
                    label: uploadLabel,
                    value: displayUploadSpeed,
                    unit: displayUnit,
                    color: AppTheme.uploadColor,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: colorScheme.outlineVariant,
                ),
                Expanded(
                  child: _SpeedColumn(
                    label: pingLabel,
                    value: result.ping,
                    unit: msUnit,
                    color: AppTheme.pingColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedColumn extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final Color color;

  const _SpeedColumn({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value.toStringAsFixed(1),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
              TextSpan(
                text: ' $unit',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
