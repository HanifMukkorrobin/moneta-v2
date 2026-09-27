import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/screens/auth/widgets/login_form.dart';
import 'package:moneta/state/app_state.dart';
import 'package:moneta/theme/app_theme.dart';

void main() {
  setUp(() {
    AppState.instance.resetToDefault();
  });

  Widget buildTestableWidget({
    VoidCallback? onLoginSuccess,
    String? initialEmail,
    String? initialPassword,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: AppStateScope(
          notifier: AppState.instance,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: LoginForm(
              onLoginSuccess: onLoginSuccess,
              initialEmail: initialEmail,
              initialPassword: initialPassword,
            ),
          ),
        ),
      ),
    );
  }

  group('LoginForm Widget Tests', () {
    testWidgets('renders all fields, buttons, checkbox, and defaults',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login_form')), findsOneWidget);
      expect(find.byKey(const Key('login_email_field')), findsOneWidget);
      expect(find.byKey(const Key('login_password_field')), findsOneWidget);
      expect(find.byKey(const Key('btn_login_toggle_password')), findsOneWidget);
      expect(find.byKey(const Key('login_remember_me_checkbox')), findsOneWidget);
      expect(find.byKey(const Key('btn_forgot_password')), findsOneWidget);
      expect(find.byKey(const Key('btn_login_submit')), findsOneWidget);
      expect(find.text('Masuk Sekarang'), findsOneWidget);
    });

    testWidgets('validates empty inputs and email format with error messages',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          initialEmail: '',
          initialPassword: '',
        ),
      );
      await tester.pumpAndSettle();

      // Submit empty
      await tester.tap(find.byKey(const Key('btn_login_submit')));
      await tester.pumpAndSettle();

      expect(find.text('Email wajib diisi'), findsOneWidget);
      expect(find.text('Kata sandi wajib diisi'), findsOneWidget);

      // Invalid email & short password
      await tester.enterText(
          find.byKey(const Key('login_email_field')), 'usernonemail');
      await tester.enterText(
          find.byKey(const Key('login_password_field')), '12345');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_login_submit')));
      await tester.pumpAndSettle();

      expect(
          find.text('Format email tidak valid (contoh: user@mail.com)'), findsOneWidget);
      expect(find.text('Kata sandi minimal 6 karakter'), findsOneWidget);
    });

    testWidgets('displays error banner when wrong password is used',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          initialEmail: 'budi.santoso@moneta.ai',
          initialPassword: 'wrongpass',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_login_submit')));
      await tester.pump(); // Start loading
      await tester.pump(const Duration(milliseconds: 350)); // Complete async delay
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login_error_banner')), findsOneWidget);
      expect(
        find.text('Email atau kata sandi tidak cocok. Silakan coba lagi.'),
        findsOneWidget,
      );
    });

    testWidgets('displays error banner when locked account is accessed',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          initialEmail: 'locked@moneta.ai',
          initialPassword: 'password123',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_login_submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login_error_banner')), findsOneWidget);
      expect(
        find.text('Akun terkunci sementara karena aktivitas mencurigakan.'),
        findsOneWidget,
      );
    });

    testWidgets('successful login updates AppState and calls onLoginSuccess callback',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool callbackFired = false;
      await tester.pumpWidget(
        buildTestableWidget(
          initialEmail: 'budi.santoso@moneta.ai',
          initialPassword: 'password123',
          onLoginSuccess: () => callbackFired = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_login_submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(callbackFired, true);
      expect(AppState.instance.isLoggedIn, true);
      expect(AppState.instance.userProfile.displayName, 'Budi Santoso');
      expect(AppState.instance.userProfile.email, 'budi.santoso@moneta.ai');
    });

    testWidgets('forgot password dialog opens and sends mock reset link',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Tap Lupa Kata Sandi
      await tester.tap(find.byKey(const Key('btn_forgot_password')));
      await tester.pumpAndSettle();

      expect(find.text('Reset Kata Sandi'), findsOneWidget);
      expect(find.byKey(const Key('reset_password_email_field')), findsOneWidget);
      expect(find.byKey(const Key('btn_confirm_forgot_password')), findsOneWidget);

      // Confirm send link
      await tester.tap(find.byKey(const Key('btn_confirm_forgot_password')));
      await tester.pumpAndSettle();

      expect(find.text('Reset Kata Sandi'), findsNothing);
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
          of: find.byKey(const Key('login_password_field')),
          matching: find.byType(TextField),
        ),
      );
      expect(passField.obscureText, true);

      // Tap toggle visibility
      await tester.tap(find.byKey(const Key('btn_login_toggle_password')));
      await tester.pumpAndSettle();

      final updatedPassField = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('login_password_field')),
          matching: find.byType(TextField),
        ),
      );
      expect(updatedPassField.obscureText, false);
    });
  });
}
