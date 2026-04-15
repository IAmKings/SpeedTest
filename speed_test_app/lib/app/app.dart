import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/speed_test/presentation/viewmodels/speed_test_viewmodel.dart';
import '../features/speed_test/presentation/viewmodels/history_viewmodel.dart';
import '../features/speed_test/data/repositories/history_repository.dart';
import '../features/speed_test/data/services/speed_test_service.dart';
import '../features/speed_test/presentation/views/home_page.dart';
import 'theme.dart';
import 'theme_provider.dart';
import 'locale_provider.dart';
import 'unit_provider.dart';
import 'connection_config_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SpeedTestApp extends StatelessWidget {
  const SpeedTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => UnitProvider()),
        ChangeNotifierProvider(create: (_) => ConnectionConfigProvider()),
        // Services
        Provider<SpeedTestService>(
          create: (_) => SpeedTestService(),
        ),
        ProxyProvider<SpeedTestService, HistoryRepository>(
          update: (_, speedTestService, __) => HistoryRepository(),
        ),
        // ViewModels
        ChangeNotifierProxyProvider<HistoryRepository, SpeedTestViewModel>(
          create: (_) => SpeedTestViewModel(),
          update: (_, historyRepository, previous) {
            final vm = previous ?? SpeedTestViewModel(historyRepository: historyRepository);
            vm.setHistoryRepository(historyRepository);
            return vm;
          },
        ),
        ChangeNotifierProxyProvider<HistoryRepository, HistoryViewModel>(
          create: (_) => HistoryViewModel(),
          update: (_, historyRepository, previous) {
            previous?.setHistoryRepository(historyRepository);
            return previous ?? HistoryViewModel(historyRepository: historyRepository);
          },
        ),
      ],
      child: Consumer2<ThemeProvider, LocaleProvider>(
        builder: (context, themeProvider, localeProvider, _) {
          return MaterialApp(
            title: 'Speed Test',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.flutterThemeMode,
            locale: localeProvider.flutterLocale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const HomePage(),
          );
        },
      ),
    );
  }
}
