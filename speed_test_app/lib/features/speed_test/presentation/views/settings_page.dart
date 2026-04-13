import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../app/theme_provider.dart';

/// Settings page with theme mode switching
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _packageInfo = info;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.settings),
      ),
      body: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(AppLocalizations.of(context)!.about),
                subtitle: Text(
                  '${AppLocalizations.of(context)!.appTitle} v${_packageInfo?.version ?? ''}',
                ),
                onTap: () => _showAbout(context),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.cloud_outlined),
                title: Text(AppLocalizations.of(context)!.testServer),
                subtitle: Text(AppLocalizations.of(context)!.cloudflare),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.dark_mode_outlined),
                title: Text(AppLocalizations.of(context)!.darkMode),
                subtitle: Text(_getThemeModeSubtitle(context, themeProvider)),
                trailing: DropdownButton<AppThemeMode>(
                  value: themeProvider.themeMode,
                  underline: const SizedBox(),
                  onChanged: (value) {
                    if (value != null) {
                      themeProvider.setThemeMode(value);
                    }
                  },
                  items: [
                    const DropdownMenuItem(
                      value: AppThemeMode.system,
                      child: Text('System'),
                    ),
                    DropdownMenuItem(
                      value: AppThemeMode.light,
                      child: Text(AppLocalizations.of(context)!.lightMode),
                    ),
                    DropdownMenuItem(
                      value: AppThemeMode.dark,
                      child: Text(AppLocalizations.of(context)!.darkModeLabel),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getThemeModeSubtitle(BuildContext context, ThemeProvider themeProvider) {
    switch (themeProvider.themeMode) {
      case AppThemeMode.system:
        return AppLocalizations.of(context)!.followSystemSetting;
      case AppThemeMode.light:
        return AppLocalizations.of(context)!.lightMode;
      case AppThemeMode.dark:
        return AppLocalizations.of(context)!.darkModeLabel;
    }
  }

  void _showAbout(BuildContext context) {
    if (_packageInfo == null) return;
    showAboutDialog(
      context: context,
      applicationName: AppLocalizations.of(context)!.appTitle,
      applicationVersion: _packageInfo!.version,
      applicationLegalese: '© 2026 Speed Test App',
      children: [
        const SizedBox(height: 16),
        Text(
          AppLocalizations.of(context)!.aboutAppDescription,
        ),
      ],
    );
  }
}
