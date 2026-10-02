import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/main.dart';
import 'package:moneta/screens/akun_pengaturan/akun_pengaturan_screen.dart';
import 'package:moneta/services/local_preference_service.dart';
import 'package:moneta/state/app_state.dart';
import 'package:moneta/theme/app_theme.dart';

void main() {
  const testPrefsPath = 'test_moneta_prefs.json';

  setUp(() {
    LocalPreferenceService.instance.resetForTesting(testPrefsPath);
    AppState.instance.resetToDefault();
  });

  tearDown(() {
    try {
      final file = File(testPrefsPath);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {}
  });

  group('LocalPreferenceService Tests', () {
    test('saves and retrieves theme mode correctly', () {
      expect(LocalPreferenceService.instance.getThemeMode(), isNull);

      LocalPreferenceService.instance.saveThemeMode('Gelap');
      expect(LocalPreferenceService.instance.getThemeMode(), 'Gelap');

      LocalPreferenceService.instance.saveThemeMode('Terang');
      expect(LocalPreferenceService.instance.getThemeMode(), 'Terang');

      LocalPreferenceService.instance.saveThemeMode('Ikuti Sistem');
      expect(LocalPreferenceService.instance.getThemeMode(), 'Ikuti Sistem');
    });

    test('persists strings and booleans locally', () {
      LocalPreferenceService.instance.setString('user_name', 'Budi Santoso');
      LocalPreferenceService.instance.setBool('is_dark', true);

      expect(LocalPreferenceService.instance.getString('user_name'), 'Budi Santoso');
      expect(LocalPreferenceService.instance.getBool('is_dark'), isTrue);

      LocalPreferenceService.instance.clear();
      expect(LocalPreferenceService.instance.getString('user_name'), isNull);
      expect(LocalPreferenceService.instance.getBool('is_dark'), isNull);
    });
  });

  group('AppTheme and parseThemeMode Tests', () {
    test('lightTheme has Brightness.light and expected surface/colors', () {
      final theme = AppTheme.lightTheme;
      expect(theme.brightness, Brightness.light);
      expect(theme.useMaterial3, isTrue);
      expect(theme.scaffoldBackgroundColor, AppTheme.backgroundColor);
    });

    test('darkTheme has Brightness.dark and dark surface/colors', () {
      final theme = AppTheme.darkTheme;
      expect(theme.brightness, Brightness.dark);
      expect(theme.useMaterial3, isTrue);
      expect(theme.scaffoldBackgroundColor, AppTheme.darkBackgroundColor);
      expect(theme.colorScheme.primary, AppTheme.darkPrimaryColor);
    });

    test('parseThemeMode parses Bahasa Indonesia and English values correctly', () {
      expect(AppTheme.parseThemeMode('Terang'), ThemeMode.light);
      expect(AppTheme.parseThemeMode('light'), ThemeMode.light);
      expect(AppTheme.parseThemeMode('Gelap'), ThemeMode.dark);
      expect(AppTheme.parseThemeMode('dark'), ThemeMode.dark);
      expect(AppTheme.parseThemeMode('Ikuti Sistem'), ThemeMode.system);
      expect(AppTheme.parseThemeMode('system'), ThemeMode.system);
      expect(AppTheme.parseThemeMode('unknown'), ThemeMode.system);
    });
  });

  group('AppState Theme Persistence Tests', () {
    test('themeMode getter returns appropriate ThemeMode enum', () {
      AppState.instance.updateUserProfile(
        AppState.instance.userProfile.copyWith(themeMode: 'Terang'),
      );
      expect(AppState.instance.themeMode, ThemeMode.light);

      AppState.instance.updateUserProfile(
        AppState.instance.userProfile.copyWith(themeMode: 'Gelap'),
      );
      expect(AppState.instance.themeMode, ThemeMode.dark);

      AppState.instance.updateUserProfile(
        AppState.instance.userProfile.copyWith(themeMode: 'Ikuti Sistem'),
      );
      expect(AppState.instance.themeMode, ThemeMode.system);
    });

    test('updateThemeMode updates profile and persists to LocalPreferenceService', () {
      AppState.instance.updateThemeMode('Gelap');

      expect(AppState.instance.userProfile.themeMode, 'Gelap');
      expect(AppState.instance.themeMode, ThemeMode.dark);
      expect(LocalPreferenceService.instance.getThemeMode(), 'Gelap');

      // Re-init default state should retain saved theme mode
      AppState.instance.resetToDefault();
      expect(AppState.instance.userProfile.themeMode, 'Gelap');
      expect(AppState.instance.themeMode, ThemeMode.dark);
    });
  });

  group('UI Theme Switcher Tests in AkunPengaturanScreen', () {
    testWidgets('shows theme tile and allows switching to Gelap', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: AppState.instance.themeMode,
          home: AppStateScope(
            notifier: AppState.instance,
            child: const AkunPengaturanScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Theme tile exists
      final themeTile = find.byKey(const Key('setting_theme_tile'));
      expect(themeTile, findsOneWidget);
      expect(find.text('Tema Tampilan'), findsOneWidget);

      // Tap theme tile
      await tester.tap(themeTile);
      await tester.pumpAndSettle();

      expect(find.text('Pilih Tema Tampilan'), findsOneWidget);
      final darkOption = find.byKey(const Key('setting_theme_option_Gelap'));
      expect(darkOption, findsOneWidget);

      // Select 'Gelap'
      await tester.tap(darkOption);
      await tester.pumpAndSettle();

      expect(AppState.instance.userProfile.themeMode, 'Gelap');
      expect(AppState.instance.themeMode, ThemeMode.dark);
      expect(LocalPreferenceService.instance.getThemeMode(), 'Gelap');
    });

    testWidgets('MonetaApp dynamically updates themeMode when AppState changes', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        AppStateScope(
          notifier: AppState.instance,
          child: const MonetaApp(),
        ),
      );
      await tester.pumpAndSettle();

      MaterialApp app = tester.widget(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.light);

      AppState.instance.updateThemeMode('Gelap');
      await tester.pumpAndSettle();

      app = tester.widget(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
    });
  });
}
