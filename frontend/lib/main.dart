import 'package:flutter/material.dart';
import 'screens/beranda/beranda_screen.dart';
import 'screens/beranda/pengaturan_pengingat_screen.dart';
import 'screens/beranda/riwayat_tips_hemat_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'services/mock_notification_service.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    AppStateScope(
      notifier: AppState.instance,
      child: const MonetaApp(),
    ),
  );
}

class MonetaApp extends StatelessWidget {
  const MonetaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: MockNotificationService.navigatorKey,
      title: 'Moneta',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainNavigationScreen(),
      routes: {
        '/beranda': (_) => const BerandaScreen(),
        '/riwayat-tips': (_) => const RiwayatTipsHematScreen(),
        '/pengaturan-pengingat': (_) => const PengaturanPengingatScreen(),
      },
    );
  }
}



