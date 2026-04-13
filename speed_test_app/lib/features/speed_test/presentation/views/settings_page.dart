import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Settings page placeholder
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.settings),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(AppLocalizations.of(context)!.about),
            subtitle: const Text('Speed Test App v1.0.0'),
            onTap: () => _showAbout(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: Text(AppLocalizations.of(context)!.testServer),
            subtitle: Text(AppLocalizations.of(context)!.cloudflare),
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: Text(AppLocalizations.of(context)!.darkMode),
            subtitle: Text(AppLocalizations.of(context)!.followSystemSetting),
            value: Theme.of(context).brightness == Brightness.dark,
            onChanged: null, // Follows system by default
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: AppLocalizations.of(context)!.appTitle,
      applicationVersion: '1.0.0',
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
