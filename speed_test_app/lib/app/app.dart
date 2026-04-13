import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/speed_test/presentation/viewmodels/speed_test_viewmodel.dart';
import '../features/speed_test/presentation/viewmodels/history_viewmodel.dart';
import '../features/speed_test/data/repositories/history_repository.dart';
import '../features/speed_test/data/services/speed_test_service.dart';
import '../features/speed_test/presentation/views/home_page.dart';
import 'theme.dart';

class SpeedTestApp extends StatelessWidget {
  const SpeedTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
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
          update: (_, historyRepository, previous) =>
              previous ?? SpeedTestViewModel(historyRepository: historyRepository),
        ),
        ChangeNotifierProxyProvider<HistoryRepository, HistoryViewModel>(
          create: (_) => HistoryViewModel(),
          update: (_, historyRepository, previous) =>
              previous ?? HistoryViewModel(historyRepository: historyRepository),
        ),
      ],
      child: MaterialApp(
        title: 'Speed Test',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const HomePage(),
      ),
    );
  }
}
