import 'package:flutter/material.dart';

/// Settings page placeholder
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            subtitle: const Text('Speed Test App v1.0.0'),
            onTap: () => _showAbout(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('Test Server'),
            subtitle: const Text('Cloudflare'),
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Dark Mode'),
            subtitle: const Text('Follow system setting'),
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
      applicationName: 'Speed Test',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2026 Speed Test App',
      children: [
        const SizedBox(height: 16),
        const Text(
          'A simple speed test app using Cloudflare\'s speed test API.',
        ),
      ],
    );
  }
}
