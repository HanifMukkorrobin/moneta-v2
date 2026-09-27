import 'package:flutter/material.dart';
import 'screens/main_navigation_screen.dart';
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
      title: 'Moneta',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainNavigationScreen(),
    );
  }
}
