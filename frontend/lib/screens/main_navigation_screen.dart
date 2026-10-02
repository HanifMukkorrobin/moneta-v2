import 'package:flutter/material.dart';
import '../services/mock_notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/in_app_notification_banner.dart';
import 'akun_pengaturan/akun_pengaturan_screen.dart';
import 'analisa/analisa_keuangan_screen.dart';
import 'budget/atur_budget_screen.dart';
import 'chat/chat_screen.dart';
import 'hutang/hutang_screen.dart';
import 'rekap/rekap_bulanan_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const ChatScreen(),
    const RekapBulananScreen(),
    const AturBudgetScreen(),
    const HutangScreen(),
    const AnalisaKeuanganScreen(),
    const AkunPengaturanScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          ListenableBuilder(
            listenable: MockNotificationService.instance,
            builder: (context, _) {
              final notif =
                  MockNotificationService.instance.currentNotification;
              if (notif == null) return const SizedBox.shrink();
              return SafeArea(
                child: InAppNotificationBanner(
                  payload: notif,
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) {
          setState(() {
            _currentIndex = idx;
          });
        },
        backgroundColor: Colors.white,
        elevation: 2,
        indicatorColor: AppTheme.primaryColor.withValues(alpha: 0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded,
                color: AppTheme.primaryColor),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline_rounded),
            selectedIcon: Icon(Icons.pie_chart_rounded,
                color: AppTheme.primaryColor),
            label: 'Rekap',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded,
                color: AppTheme.primaryColor),
            label: 'Budget',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded,
                color: AppTheme.primaryColor),
            label: 'Hutang',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded,
                color: AppTheme.primaryColor),
            label: 'Analisa',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded,
                color: AppTheme.primaryColor),
            label: 'Akun',
          ),
        ],
      ),
    );
  }
}
