import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/speed_test_viewmodel.dart';
import '../viewmodels/history_viewmodel.dart';
import '../widgets/speed_gauge.dart';
import '../widgets/ping_indicator.dart';
import '../widgets/history_tile.dart';
import 'settings_page.dart';
import '../../../../app/unit_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Main home page with speed test UI
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    // Load history when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryViewModel>().loadHistory();
    });
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
          final displayDownload = unitProvider.convertSpeed(viewModel.downloadSpeed);
          final displayUpload = unitProvider.convertSpeed(viewModel.uploadSpeed);
          final speedUnit = unitProvider.unit == SpeedUnit.mbps
              ? AppLocalizations.of(context)!.mbpsUnit
              : AppLocalizations.of(context)!.mbsUnit;
          final maxSpeed = unitProvider.unit == SpeedUnit.mbps ? 200.0 : 25.0; // 200 Mbps or 25 MB/s

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Ping indicator
                      PingIndicator(
                        ping: viewModel.ping,
                        isActive: viewModel.state == TestState.testingPing,
                        pingLabel: AppLocalizations.of(context)!.ping,
                        unit: AppLocalizations.of(context)!.ms,
                      ),
                      const SizedBox(height: 32),

                      // Speed gauges
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          SpeedGauge(
                            speed: displayDownload,
                            maxSpeed: maxSpeed,
                            label: AppLocalizations.of(context)!.download,
                            unit: speedUnit,
                            isActive: viewModel.state == TestState.testingDownload,
                          ),
                          SpeedGauge(
                            speed: displayUpload,
                            maxSpeed: maxSpeed,
                            label: AppLocalizations.of(context)!.upload,
                            unit: speedUnit,
                            isActive: viewModel.state == TestState.testingUpload,
                          ),
                        ],
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

                      // Start/Stop button
                      SizedBox(
                        width: 200,
                        height: 56,
                        child: FilledButton(
                          onPressed: viewModel.isTestRunning
                              ? viewModel.stopTest
                              : viewModel.startTest,
                          child: Text(
                            viewModel.isTestRunning ? AppLocalizations.of(context)!.stop : AppLocalizations.of(context)!.startTest,
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
          Consumer<HistoryViewModel>(
            builder: (context, historyVM, _) {
              if (historyVM.history.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(AppLocalizations.of(context)!.noTestsYet),
                );
              }
              return HistoryTile(
                result: historyVM.history.first,
                downloadLabel: AppLocalizations.of(context)!.download,
                uploadLabel: AppLocalizations.of(context)!.upload,
                pingLabel: AppLocalizations.of(context)!.ping,
                mbpsUnit: AppLocalizations.of(context)!.mbps,
                msUnit: AppLocalizations.of(context)!.ms,
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
            child: Consumer<HistoryViewModel>(
              builder: (context, historyVM, _) {
                if (historyVM.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (historyVM.history.isEmpty) {
                  return Center(child: Text(AppLocalizations.of(context)!.noTestHistory));
                }
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
                        msUnit: AppLocalizations.of(context)!.ms,
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
