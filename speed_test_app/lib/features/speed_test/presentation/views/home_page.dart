import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/speed_test_viewmodel.dart';
import '../viewmodels/history_viewmodel.dart';
import '../widgets/speed_gauge.dart';
import '../widgets/history_tile.dart';
import '../widgets/version_check_dialog.dart';
import '../widgets/download_progress_dialog.dart';
import '../../data/services/version_service.dart';
import 'settings_page.dart';
import '../../../../app/unit_provider.dart';
import '../../../../app/theme.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Main home page with speed test UI
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final VersionService _versionService = VersionService();
  bool _versionCheckDone = false;
  TestState? _lastState;

  @override
  void initState() {
    super.initState();
    // Load history when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryViewModel>().loadHistory();
      _checkForUpdate();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen to SpeedTestViewModel state changes to refresh history when test completes
    final viewModel = context.watch<SpeedTestViewModel>();
    if (_lastState != null && _lastState != viewModel.state && viewModel.state == TestState.completed) {
      // Test just completed, refresh history
      context.read<HistoryViewModel>().loadHistory();
    }
    _lastState = viewModel.state;
  }

  Future<void> _checkForUpdate() async {
    if (!_versionCheckDone) {
      _versionCheckDone = true;
    }

    final versionInfo = await _versionService.checkLatestVersion();
    if (versionInfo == null || !mounted) return;

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    // Compare versions
    if (_compareVersions(currentVersion, versionInfo.version) >= 0) return;
    if (await _versionService.isVersionSkipped(versionInfo.version)) return;

    // Only show dialog if in idle state
    if (!mounted) return;
    final viewModel = context.read<SpeedTestViewModel>();
    if (viewModel.state != TestState.idle) return;

    _showUpdateDialog(versionInfo);
  }

  int _compareVersions(String current, String latest) {
    final cParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final lParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (int i = 0; i < 3; i++) {
      final c = i < cParts.length ? cParts[i] : 0;
      final l = i < lParts.length ? lParts[i] : 0;
      if (c != l) return c - l;
    }
    return 0;
  }

  void _showUpdateDialog(VersionInfo versionInfo) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => VersionCheckDialog(
        versionInfo: versionInfo,
        onUpdate: () => _startDownload(versionInfo),
        onSkip: () => _versionService.skipVersion(versionInfo.version),
        onLater: () {},
      ),
    );
  }

  Future<void> _startDownload(VersionInfo versionInfo) async {
    int progress = 0;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ListenableBuilder(
        listenable: _ProgressNotifier(progress),
        builder: (context, _) => DownloadProgressDialog(progress: progress),
      ),
    );

    try {
      final downloadedPath = await _versionService.downloadApk(
        versionInfo.downloadUrl,
        onProgress: (p) {
          progress = p;
        },
      );

      if (mounted) Navigator.pop(context);

      // Try to install after download
      await _versionService.installApk(downloadedPath);
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _openSettings(context),
          ),
        ],
      ),
      body: Consumer2<SpeedTestViewModel, UnitProvider>(
        builder: (context, viewModel, unitProvider, child) {
          final isMbps = unitProvider.unit == SpeedUnit.mbps;
          final speedUnit = isMbps
              ? AppLocalizations.of(context)!.mbpsUnit
              : AppLocalizations.of(context)!.mbsUnit;

          // Get speed value for current test phase (in Mbps), then convert to display unit
          final currentSpeedMbps = _getSpeedForCurrentPhase(viewModel);
          final displayValue = unitProvider.convertSpeed(currentSpeedMbps);

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Idle state: only show pulsing start button
                      if (viewModel.state == TestState.idle) ...[
                        const SizedBox(height: 120),
                        _PulsingStartButton(
                          onPressed: viewModel.startTest,
                          text: AppLocalizations.of(context)!.start,
                        ),
                      ],

                      // Testing/Completed state: show gauge and results
                      if (viewModel.state != TestState.idle) ...[
                        const SizedBox(height: 24),

                        // Result row: Ping, Download, Upload in one line
                        _ResultRow(
                          ping: viewModel.ping,
                          downloadSpeed: viewModel.downloadSpeed,
                          uploadSpeed: viewModel.uploadSpeed,
                          isPingActive: viewModel.state == TestState.testingPing,
                          isDownloadActive: viewModel.state == TestState.testingDownload,
                          isUploadActive: viewModel.state == TestState.testingUpload,
                          isCompleted: viewModel.state == TestState.completed,
                          pingLabel: AppLocalizations.of(context)!.ping,
                          downloadLabel: AppLocalizations.of(context)!.download,
                          uploadLabel: AppLocalizations.of(context)!.upload,
                          mbpsUnit: speedUnit,
                          msUnit: AppLocalizations.of(context)!.ms,
                          isMbps: isMbps,
                        ),
                        const SizedBox(height: 24),

                        // Speed gauge - single gauge showing current test phase
                        SpeedGauge(
                          speed: displayValue,
                          label: _getCurrentLabel(context, viewModel),
                          unit: speedUnit,
                          isMbps: isMbps,
                        ),
                        const SizedBox(height: 24),

                        // Status text
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            viewModel.currentPhase,
                            key: ValueKey(viewModel.currentPhase),
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Progress indicator
                        if (viewModel.isTestRunning)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 48),
                            child: LinearProgressIndicator(
                              value: viewModel.progress,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        const SizedBox(height: 32),

                        // Continue/Stop button
                        if (viewModel.state == TestState.completed || viewModel.state == TestState.error)
                          SizedBox(
                            width: 200,
                            height: 56,
                            child: FilledButton(
                              onPressed: viewModel.startTest,
                              child: Text(
                                AppLocalizations.of(context)!.continueTest,
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                          ),
                        if (viewModel.isTestRunning)
                          SizedBox(
                            width: 200,
                            height: 56,
                            child: OutlinedButton(
                              onPressed: viewModel.stopTest,
                              child: Text(
                                AppLocalizations.of(context)!.stop,
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                          ),

                        // Error message
                        if (viewModel.state == TestState.error)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              viewModel.errorMessage ?? AppLocalizations.of(context)!.anErrorOccurred,
                              style: TextStyle(color: colorScheme.error),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),

              // History section
              _HistorySection(),
            ],
          );
        },
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  /// Get the speed value (in Mbps) for the current test phase
  double _getSpeedForCurrentPhase(SpeedTestViewModel viewModel) {
    switch (viewModel.state) {
      case TestState.testingDownload:
        return viewModel.downloadSpeed;
      case TestState.testingUpload:
      case TestState.completed:
        return viewModel.uploadSpeed;
      default:
        return 0;
    }
  }

  String _getCurrentLabel(BuildContext context, SpeedTestViewModel viewModel) {
    switch (viewModel.state) {
      case TestState.testingDownload:
        return AppLocalizations.of(context)!.download;
      case TestState.testingUpload:
        return AppLocalizations.of(context)!.upload;
      case TestState.completed:
        return AppLocalizations.of(context)!.upload; // Ready for next phase
      default:
        return AppLocalizations.of(context)!.download; // Default to download
    }
  }
}

/// Bottom sheet showing history
class _HistorySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.recentTests,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                TextButton(
                  onPressed: () => _showHistorySheet(context),
                  child: Text(AppLocalizations.of(context)!.seeAll),
                ),
              ],
            ),
          ),
          // Latest result
          Consumer2<HistoryViewModel, UnitProvider>(
            builder: (context, historyVM, unitProvider, _) {
              if (historyVM.history.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(AppLocalizations.of(context)!.noTestsYet),
                );
              }
              final isMbps = unitProvider.unit == SpeedUnit.mbps;
              return HistoryTile(
                result: historyVM.history.first,
                downloadLabel: AppLocalizations.of(context)!.download,
                uploadLabel: AppLocalizations.of(context)!.upload,
                pingLabel: AppLocalizations.of(context)!.ping,
                mbpsUnit: AppLocalizations.of(context)!.mbps,
                mbsUnit: AppLocalizations.of(context)!.mbsUnit,
                msUnit: AppLocalizations.of(context)!.ms,
                isMbps: isMbps,
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showHistorySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return _HistorySheet(scrollController: scrollController);
        },
      ),
    );
  }
}

/// Full history bottom sheet
class _HistorySheet extends StatelessWidget {
  final ScrollController scrollController;

  const _HistorySheet({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.testHistory,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Consumer<HistoryViewModel>(
                  builder: (context, vm, _) {
                    if (vm.history.isEmpty) return const SizedBox();
                    return IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmClearAll(context, vm),
                    );
                  },
                ),
              ],
            ),
          ),
          // History list
          Expanded(
            child: Consumer2<HistoryViewModel, UnitProvider>(
              builder: (context, historyVM, unitProvider, _) {
                if (historyVM.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (historyVM.history.isEmpty) {
                  return Center(child: Text(AppLocalizations.of(context)!.noTestHistory));
                }
                final isMbps = unitProvider.unit == SpeedUnit.mbps;
                return ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.only(bottom: 32),
                  itemCount: historyVM.history.length,
                  itemBuilder: (context, index) {
                    final result = historyVM.history[index];
                    return Dismissible(
                      key: ValueKey(result.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        color: Theme.of(context).colorScheme.error,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) async {
                        return await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(AppLocalizations.of(context)!.deleteThisRecord),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(AppLocalizations.of(context)!.cancel),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(AppLocalizations.of(context)!.delete),
                              ),
                            ],
                          ),
                        ) ?? false;
                      },
                      onDismissed: (_) {
                        if (result.id != null) {
                          historyVM.deleteResult(result.id!);
                        }
                      },
                      child: HistoryTile(
                        result: result,
                        downloadLabel: AppLocalizations.of(context)!.download,
                        uploadLabel: AppLocalizations.of(context)!.upload,
                        pingLabel: AppLocalizations.of(context)!.ping,
                        mbpsUnit: AppLocalizations.of(context)!.mbps,
                        mbsUnit: AppLocalizations.of(context)!.mbsUnit,
                        msUnit: AppLocalizations.of(context)!.ms,
                        isMbps: isMbps,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll(BuildContext context, HistoryViewModel vm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.clearAllHistory),
        content: Text(AppLocalizations.of(context)!.clearAllHistoryConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () {
              vm.clearAllHistory();
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)!.clearAll),
          ),
        ],
      ),
    );
  }
}

/// Result row showing Ping, Download, Upload in one line
class _ResultRow extends StatelessWidget {
  final double ping;
  final double downloadSpeed;
  final double uploadSpeed;
  final bool isPingActive;
  final bool isDownloadActive;
  final bool isUploadActive;
  final bool isCompleted;
  final String pingLabel;
  final String downloadLabel;
  final String uploadLabel;
  final String mbpsUnit;
  final String msUnit;
  final bool isMbps;

  const _ResultRow({
    required this.ping,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.isPingActive,
    required this.isDownloadActive,
    required this.isUploadActive,
    required this.isCompleted,
    required this.pingLabel,
    required this.downloadLabel,
    required this.uploadLabel,
    required this.mbpsUnit,
    required this.msUnit,
    required this.isMbps,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ResultColumn(
              label: pingLabel,
              value: ping >= 0 ? ping.toStringAsFixed(0) : '--',
              unit: msUnit,
              color: AppTheme.pingColor,
              isActive: isPingActive,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: colorScheme.outlineVariant,
          ),
          Expanded(
            child: _ResultColumn(
              label: downloadLabel,
              value: downloadSpeed > 0 ? downloadSpeed.toStringAsFixed(1) : '--',
              unit: mbpsUnit,
              color: AppTheme.downloadColor,
              isActive: isDownloadActive,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: colorScheme.outlineVariant,
          ),
          Expanded(
            child: _ResultColumn(
              label: uploadLabel,
              value: uploadSpeed > 0 ? uploadSpeed.toStringAsFixed(1) : '--',
              unit: mbpsUnit,
              color: AppTheme.uploadColor,
              isActive: isUploadActive,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultColumn extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final bool isActive;

  const _ResultColumn({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.isActive,
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
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 2, left: 2),
              child: Text(
                unit,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color,
                    ),
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              _AnimatedDots(color: color),
            ],
          ],
        ),
      ],
    );
  }
}

class _AnimatedDots extends StatefulWidget {
  final Color color;

  const _AnimatedDots({required this.color});

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
                color: widget.color.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

/// Pulsing start button with white border, transparent fill, and scale animation
class _PulsingStartButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String text;

  const _PulsingStartButton({
    required this.onPressed,
    required this.text,
  });

  @override
  State<_PulsingStartButton> createState() => _PulsingStartButtonState();
}

class _PulsingStartButtonState extends State<_PulsingStartButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3500),
      vsync: this,
    )..repeat(reverse: true);

    // Gentle scale: 0.92 ~ 1.05 (subtle pulse)
    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    // Soft opacity: 0.7 ~ 1.0
    _opacityAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final accentColor = isDark ? Colors.white : colorScheme.primary;
    final textColor = isDark ? Colors.white : colorScheme.primary;
    final bgColor = isDark
        ? Colors.transparent
        : colorScheme.primaryContainer.withValues(alpha: 0.1);
    final glowColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : colorScheme.primary.withValues(alpha: 0.12);

    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: GestureDetector(
              onTap: widget.onPressed,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Scaled container
                  Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.5),
                          width: 2,
                        ),
                        color: bgColor,
                        boxShadow: [
                          BoxShadow(
                            color: glowColor,
                            blurRadius: 25,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Fixed-size text (not scaled)
                  Text(
                    widget.text,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.9),
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Simple ChangeNotifier for progress updates
class _ProgressNotifier extends ChangeNotifier {
  int _progress;
  _ProgressNotifier(this._progress);

  int get progress => _progress;
  set progress(int value) {
    _progress = value;
    notifyListeners();
  }
}
