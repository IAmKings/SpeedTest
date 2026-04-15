import 'package:flutter/material.dart';
import '../../data/services/version_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Dialog shown when a new version is available
class VersionCheckDialog extends StatelessWidget {
  final VersionInfo versionInfo;
  final VoidCallback onUpdate;
  final VoidCallback onSkip;
  final VoidCallback onLater;

  const VersionCheckDialog({
    super.key,
    required this.versionInfo,
    required this.onUpdate,
    required this.onSkip,
    required this.onLater,
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
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Update icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.system_update_alt,
                  size: 36,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                l10n.newVersionAvailable(versionInfo.version),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Release notes (if any)
              if (versionInfo.releaseNotes.isNotEmpty) ...[
                Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: SingleChildScrollView(
                    child: Text(
                      versionInfo.releaseNotes,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onSkip();
                      },
                      child: Text(l10n.skipThisVersion),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onLater();
                      },
                      child: Text(l10n.updateLater),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onUpdate();
                  },
                  child: Text(l10n.updateNow),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
