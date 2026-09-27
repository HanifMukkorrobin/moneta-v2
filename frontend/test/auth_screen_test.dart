import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/screens/auth/auth_screen.dart';
import 'package:moneta/state/app_state.dart';
import 'package:moneta/theme/app_theme.dart';

void main() {
  setUp(() {
    AppState.instance.resetToDefault();
  });

  Widget buildTestableWidget({AuthMode initialMode = AuthMode.login, VoidCallback? onAuthSuccess}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: AppStateScope(
        notifier: AppState.instance,
        child: AuthScreen(
          initialMode: initialMode,
          onAuthSuccess: onAuthSuccess,
        ),
      ),
      routes: {
        '/auth': (_) => const AuthScreen(),
        '/login': (_) => const AuthScreen(initialMode: AuthMode.login),
        '/daftar': (_) => const AuthScreen(initialMode: AuthMode.register),
      },
    );
  }

  group('AuthScreen Widget Tests', () {
    testWidgets('renders login form by default with logo, inputs, and quick demo buttons',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('auth_screen')), findsOneWidget);
      expect(find.text('Catat Uang AI'), findsOneWidget);
      expect(find.text('Masuk ke Moneta AI'), findsOneWidget);

      // Mode Switcher
      expect(find.byKey(const Key('auth_mode_tab_bar')), findsOneWidget);
      expect(find.byKey(const Key('tab_login')), findsOneWidget);
      expect(find.byKey(const Key('tab_register')), findsOneWidget);

      // Login form inputs
      expect(find.byKey(const Key('auth_email_field')), findsOneWidget);
      expect(find.byKey(const Key('auth_password_field')), findsOneWidget);
      expect(find.byKey(const Key('btn_submit_auth')), findsOneWidget);
      expect(find.text('Masuk Sekarang'), findsOneWidget);

      // Demo login
      expect(find.byKey(const Key('btn_quick_demo_login')), findsOneWidget);
      expect(find.byKey(const Key('btn_google_mock_login')), findsOneWidget);
    });

    testWidgets('switches to register mode revealing name, confirm password, and currency fields',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Tap Daftar tab
      await tester.tap(find.byKey(const Key('tab_register')));
      await tester.pumpAndSettle();

      expect(find.text('Daftar Akun Baru'), findsWidgets);
      expect(find.byKey(const Key('auth_name_field')), findsOneWidget);
      expect(find.byKey(const Key('auth_email_field')), findsOneWidget);
      expect(find.byKey(const Key('auth_password_field')), findsOneWidget);
      expect(find.byKey(const Key('auth_confirm_password_field')), findsOneWidget);
      expect(find.byKey(const Key('auth_currency_dropdown')), findsOneWidget);
    });

    testWidgets('validates required fields and email format',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Clear email and password
      await tester.enterText(find.byKey(const Key('auth_email_field')), '');
      await tester.enterText(find.byKey(const Key('auth_password_field')), '');
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.byKey(const Key('btn_submit_auth')));
      await tester.pumpAndSettle();

      expect(find.text('Email wajib diisi'), findsOneWidget);
      expect(find.text('Kata sandi wajib diisi'), findsOneWidget);

      // Invalid email
      await tester.enterText(find.byKey(const Key('auth_email_field')), 'invalidemail');
      await tester.enterText(find.byKey(const Key('auth_password_field')), '123');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_submit_auth')));
      await tester.pumpAndSettle();

      expect(find.text('Format email tidak valid'), findsOneWidget);
      expect(find.text('Kata sandi minimal 6 karakter'), findsOneWidget);
    });

    testWidgets('register form checks mismatched password confirmation',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget(initialMode: AuthMode.register));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('auth_name_field')), 'Siti Rahma');
      await tester.enterText(find.byKey(const Key('auth_email_field')), 'siti@example.com');
      await tester.enterText(find.byKey(const Key('auth_password_field')), 'secret123');
      await tester.enterText(find.byKey(const Key('auth_confirm_password_field')), 'different123');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_submit_auth')));
      await tester.pumpAndSettle();

      expect(find.text('Konfirmasi kata sandi tidak cocok'), findsOneWidget);
    });

    testWidgets('successful registration updates AppState userProfile',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool successCalled = false;
      await tester.pumpWidget(
        buildTestableWidget(
          initialMode: AuthMode.register,
          onAuthSuccess: () => successCalled = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('auth_name_field')), 'Ahmad Dahlan');
      await tester.enterText(find.byKey(const Key('auth_email_field')), 'ahmad@moneta.ai');
      await tester.enterText(find.byKey(const Key('auth_password_field')), 'password123');
      await tester.enterText(find.byKey(const Key('auth_confirm_password_field')), 'password123');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_submit_auth')));
      await tester.pump(); // Trigger loading
      await tester.pump(const Duration(milliseconds: 400)); // Finish simulation delay
      await tester.pumpAndSettle();

      expect(AppState.instance.userProfile.displayName, 'Ahmad Dahlan');
      expect(AppState.instance.userProfile.email, 'ahmad@moneta.ai');
      expect(AppState.instance.isLoggedIn, true);
      expect(successCalled, true);
    });

    testWidgets('quick demo login immediately signs in Budi Santoso',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool successCalled = false;
      await tester.pumpWidget(
        buildTestableWidget(
          onAuthSuccess: () => successCalled = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_quick_demo_login')));
      await tester.pumpAndSettle();

      expect(AppState.instance.userProfile.displayName, 'Budi Santoso');
      expect(AppState.instance.userProfile.email, 'budi.santoso@moneta.ai');
      expect(AppState.instance.isLoggedIn, true);
      expect(successCalled, true);
    });

    testWidgets('toggling password visibility changes obscureText',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      final passField = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('auth_password_field')),
          matching: find.byType(TextField),
        ),
      );
      expect(passField.obscureText, true);

      // Tap toggle visibility
      await tester.tap(find.byKey(const Key('btn_toggle_password_visibility')));
      await tester.pumpAndSettle();

      final updatedPassField = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('auth_password_field')),
          matching: find.byType(TextField),
        ),
      );
      expect(updatedPassField.obscureText, false);
    });
  });
}
