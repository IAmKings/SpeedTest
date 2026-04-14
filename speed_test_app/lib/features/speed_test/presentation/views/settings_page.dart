import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../app/theme_provider.dart';
import '../../../../app/locale_provider.dart';
import '../../../../app/unit_provider.dart';

/// Settings page with theme mode, language and unit switching
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
      body: Consumer3<ThemeProvider, LocaleProvider, UnitProvider>(
        builder: (context, themeProvider, localeProvider, unitProvider, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              // Language Setting
              _SettingsTile(
                icon: Icons.language_outlined,
                title: AppLocalizations.of(context)!.language,
                subtitle: _getLocaleSubtitle(context, localeProvider),
                onTap: () => _showLanguageSelector(context, localeProvider),
              ),
              const Divider(indent: 72),

              // Unit Setting
              _SettingsTile(
                icon: Icons.speed_outlined,
                title: AppLocalizations.of(context)!.unit,
                subtitle: _getUnitSubtitle(context, unitProvider),
                onTap: () => _showUnitSelector(context, unitProvider),
              ),
              const Divider(indent: 72),

              // Theme Setting
              _SettingsTile(
                icon: Icons.dark_mode_outlined,
                title: AppLocalizations.of(context)!.darkMode,
                subtitle: _getThemeModeSubtitle(context, themeProvider),
                onTap: () => _showThemeSelector(context, themeProvider),
              ),
              const Divider(indent: 72),

              // Test Server
              _SettingsTile(
                icon: Icons.cloud_outlined,
                title: AppLocalizations.of(context)!.testServer,
                subtitle: AppLocalizations.of(context)!.cloudflare,
                onTap: null,
              ),
              const Divider(indent: 72),

              // About
              _SettingsTile(
                icon: Icons.info_outline,
                title: AppLocalizations.of(context)!.about,
                subtitle: '${AppLocalizations.of(context)!.appTitle} v${_packageInfo?.version ?? ''}',
                onTap: () => _showAbout(context),
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

  String _getLocaleSubtitle(BuildContext context, LocaleProvider localeProvider) {
    switch (localeProvider.locale) {
      case AppLocale.system:
        return AppLocalizations.of(context)!.system;
      case AppLocale.english:
        return AppLocalizations.of(context)!.english;
      case AppLocale.simplifiedChinese:
        return AppLocalizations.of(context)!.simplifiedChinese;
      case AppLocale.traditionalChinese:
        return AppLocalizations.of(context)!.traditionalChinese;
    }
  }

  String _getUnitSubtitle(BuildContext context, UnitProvider unitProvider) {
    switch (unitProvider.unit) {
      case SpeedUnit.mbps:
        return AppLocalizations.of(context)!.mbpsUnit;
      case SpeedUnit.mbs:
        return AppLocalizations.of(context)!.mbsUnit;
    }
  }

  void _showLanguageSelector(BuildContext context, LocaleProvider localeProvider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _SelectorBottomSheet<AppLocale>(
        title: AppLocalizations.of(context)!.language,
        selectedValue: localeProvider.locale,
        items: [
          _SelectorItem(AppLocale.system, AppLocalizations.of(context)!.system, Icons.settings_brightness),
          _SelectorItem(AppLocale.english, AppLocalizations.of(context)!.english, Icons.language),
          _SelectorItem(AppLocale.simplifiedChinese, AppLocalizations.of(context)!.simplifiedChinese, Icons.language),
          _SelectorItem(AppLocale.traditionalChinese, AppLocalizations.of(context)!.traditionalChinese, Icons.language),
        ],
        onSelected: (value) => localeProvider.setLocale(value),
      ),
    );
  }

  void _showUnitSelector(BuildContext context, UnitProvider unitProvider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _SelectorBottomSheet<SpeedUnit>(
        title: AppLocalizations.of(context)!.unit,
        selectedValue: unitProvider.unit,
        items: [
          _SelectorItem(SpeedUnit.mbps, AppLocalizations.of(context)!.mbpsUnit, Icons.speed),
          _SelectorItem(SpeedUnit.mbs, AppLocalizations.of(context)!.mbsUnit, Icons.speed),
        ],
        onSelected: (value) => unitProvider.setUnit(value),
      ),
    );
  }

  void _showThemeSelector(BuildContext context, ThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _SelectorBottomSheet<AppThemeMode>(
        title: AppLocalizations.of(context)!.darkMode,
        selectedValue: themeProvider.themeMode,
        items: [
          _SelectorItem(AppThemeMode.system, AppLocalizations.of(context)!.system, Icons.settings_brightness),
          _SelectorItem(AppThemeMode.light, AppLocalizations.of(context)!.lightMode, Icons.light_mode),
          _SelectorItem(AppThemeMode.dark, AppLocalizations.of(context)!.darkModeLabel, Icons.dark_mode),
        ],
        onSelected: (value) => themeProvider.setThemeMode(value),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    if (_packageInfo == null) return;
    showDialog(
      context: context,
      builder: (context) => _AboutDialog(
        appName: AppLocalizations.of(context)!.appTitle,
        version: _packageInfo!.version,
        description: AppLocalizations.of(context)!.aboutAppDescription,
        copyright: AppLocalizations.of(context)!.copyright,
      ),
    );
  }
}

/// MD3-styled About Dialog
class _AboutDialog extends StatelessWidget {
  final String appName;
  final String version;
  final String description;
  final String copyright;

  const _AboutDialog({
    required this.appName,
    required this.version,
    required this.description,
    required this.copyright,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.speed,
                  size: 48,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 16),

              // App Name
              Text(
                appName,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),

              // Version
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'v$version',
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Description
              Text(
                description,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Copyright
              Text(
                copyright,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // Close Button
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable settings tile widget
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: onTap != null
          ? Icon(
              Icons.chevron_right,
              color: colorScheme.onSurfaceVariant,
            )
          : null,
      onTap: onTap,
    );
  }
}

/// Generic bottom sheet selector with radio list
class _SelectorBottomSheet<T> extends StatelessWidget {
  final String title;
  final T selectedValue;
  final List<_SelectorItem<T>> items;
  final ValueChanged<T> onSelected;

  const _SelectorBottomSheet({
    required this.title,
    required this.selectedValue,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Items
          ...items.map((item) => RadioListTile<T>(
                value: item.value,
                groupValue: selectedValue,
                onChanged: (value) {
                  if (value != null) {
                    onSelected(value);
                    Navigator.pop(context);
                  }
                },
                title: Text(item.label),
                secondary: Icon(
                  item.icon,
                  color: colorScheme.onSurfaceVariant,
                ),
                activeColor: colorScheme.primary,
                selected: item.value == selectedValue,
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Selector item model
class _SelectorItem<T> {
  final T value;
  final String label;
  final IconData icon;

  const _SelectorItem(this.value, this.label, this.icon);
}
