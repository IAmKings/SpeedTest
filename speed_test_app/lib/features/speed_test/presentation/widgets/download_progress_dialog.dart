import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Modal progress dialog for APK download (non-dismissible)
class DownloadProgressDialog extends StatelessWidget {
  final int progress;

  const DownloadProgressDialog({
    super.key,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Download icon with progress
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress / 100,
                      strokeWidth: 6,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                    ),
                    Icon(
                      progress >= 100
                          ? Icons.check_circle_outline
                          : Icons.downloading,
                      size: 32,
                      color: colorScheme.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                progress >= 100 ? l10n.downloadComplete : l10n.downloading,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),

              // Progress text
              Text(
                '$progress%',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 8),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress / 100,
                  minHeight: 6,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 16),

              // Filename
              Text(
                'speed_test_update.apk',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
