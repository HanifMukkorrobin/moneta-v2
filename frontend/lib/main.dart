import 'package:flutter/material.dart';
import 'screens/akun_pengaturan/akun_pengaturan_screen.dart';
import 'screens/akun_pengaturan/preferensi_aplikasi_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/beranda/beranda_screen.dart';
import 'screens/beranda/pengaturan_pengingat_screen.dart';
import 'screens/beranda/riwayat_tips_hemat_screen.dart';
import 'screens/category_management/manage_categories_screen.dart';
import 'screens/hutang/hutang_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/security/pin_lock_screen.dart';
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
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: MockNotificationService.navigatorKey,
          title: 'Moneta',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: AppState.instance.themeMode,
          home: const MainNavigationScreen(),
          routes: {
            '/beranda': (_) => const BerandaScreen(),
            '/riwayat-tips': (_) => const RiwayatTipsHematScreen(),
            '/pengaturan-pengingat': (_) => const PengaturanPengingatScreen(),
            '/hutang': (_) => const HutangScreen(),
            '/akun': (_) => const AkunPengaturanScreen(),
            '/pengaturan': (_) => const AkunPengaturanScreen(),
            '/preferensi': (_) => const PreferensiAplikasiScreen(),
            '/manage-categories': (_) => const ManageCategoriesScreen(),
            '/auth': (_) => const AuthScreen(),
            '/login': (_) => const AuthScreen(initialMode: AuthMode.login),
            '/daftar': (_) => const AuthScreen(initialMode: AuthMode.register),
            '/pin-lock': (_) => const PinLockScreen(),
            '/pin-setup': (_) => const PinLockScreen(mode: PinLockMode.setup),
            '/pin-change': (_) => const PinLockScreen(mode: PinLockMode.change),
          },
        );
      },
    );
  }
}




