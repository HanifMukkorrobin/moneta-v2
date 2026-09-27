import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/screens/security/pin_lock_screen.dart';
import 'package:moneta/state/app_state.dart';
import 'package:moneta/theme/app_theme.dart';

void main() {
  setUp(() {
    AppState.instance.resetToDefault();
  });

  Widget buildTestableWidget({
    PinLockMode mode = PinLockMode.unlock,
    VoidCallback? onUnlockSuccess,
    ValueChanged<String>? onPinSet,
    String? initialExpectedPin,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: AppStateScope(
        notifier: AppState.instance,
        child: PinLockScreen(
          mode: mode,
          onUnlockSuccess: onUnlockSuccess,
          onPinSet: onPinSet,
          initialExpectedPin: initialExpectedPin,
        ),
      ),
    );
  }

  group('PinLockScreen Widget Tests', () {
    testWidgets('renders all initial UI elements in unlock mode',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pin_lock_screen')), findsOneWidget);
      expect(find.byKey(const Key('pin_screen_title')), findsOneWidget);
      expect(find.text('Buka Kunci Moneta'), findsOneWidget);
      expect(find.byKey(const Key('pin_indicator_dots')), findsOneWidget);

      // Check all 4 dots
      expect(find.byKey(const Key('pin_dot_0')), findsOneWidget);
      expect(find.byKey(const Key('pin_dot_1')), findsOneWidget);
      expect(find.byKey(const Key('pin_dot_2')), findsOneWidget);
      expect(find.byKey(const Key('pin_dot_3')), findsOneWidget);

      // Check keypad digits
      for (int i = 0; i <= 9; i++) {
        expect(find.byKey(Key('btn_pin_digit_$i')), findsOneWidget);
      }
      expect(find.byKey(const Key('btn_biometric_auth')), findsOneWidget);
      expect(find.byKey(const Key('btn_pin_backspace')), findsOneWidget);
    });

    testWidgets('entering digits updates dots and backspace removes digits',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Enter 1, 2
      await tester.tap(find.byKey(const Key('btn_pin_digit_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_pin_digit_2')));
      await tester.pumpAndSettle();

      // Backspace once
      await tester.tap(find.byKey(const Key('btn_pin_backspace')));
      await tester.pumpAndSettle();

      // Dot 0 is filled, Dot 1 is not
      final dot0 = tester.widget<Container>(find.byKey(const Key('pin_dot_0')));
      final dot1 = tester.widget<Container>(find.byKey(const Key('pin_dot_1')));
      final dec0 = dot0.decoration as BoxDecoration;
      final dec1 = dot1.decoration as BoxDecoration;

      expect(dec0.color, AppTheme.primaryColor);
      expect(dec1.color, Colors.transparent);
    });

    testWidgets('unlock succeeds with correct PIN',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool unlocked = false;
      await tester.pumpWidget(
        buildTestableWidget(
          initialExpectedPin: '1234',
          onUnlockSuccess: () => unlocked = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_pin_digit_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_pin_digit_2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_pin_digit_3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_pin_digit_4')));
      await tester.pumpAndSettle();

      expect(unlocked, true);
    });

    testWidgets('unlock fails with incorrect PIN and displays error',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool unlocked = false;
      await tester.pumpWidget(
        buildTestableWidget(
          initialExpectedPin: '1234',
          onUnlockSuccess: () => unlocked = true,
        ),
      );
      await tester.pumpAndSettle();

      // Enter 9999
      await tester.tap(find.byKey(const Key('btn_pin_digit_9')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_pin_digit_9')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_pin_digit_9')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_pin_digit_9')));
      await tester.pumpAndSettle();

      expect(unlocked, false);
      expect(find.byKey(const Key('pin_error_text')), findsOneWidget);
      expect(find.textContaining('PIN salah'), findsOneWidget);
    });

    testWidgets('setup mode enters new PIN and confirms successfully',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? newlySetPin;
      await tester.pumpWidget(
        buildTestableWidget(
          mode: PinLockMode.setup,
          onPinSet: (pin) => newlySetPin = pin,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Buat PIN Baru'), findsOneWidget);

      // Enter 5, 6, 7, 8
      await tester.tap(find.byKey(const Key('btn_pin_digit_5')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_pin_digit_6')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_pin_digit_7')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_pin_digit_8')));
      await tester.pumpAndSettle();

      // Should transition to step 2: Konfirmasi PIN Anda
      expect(find.text('Konfirmasi PIN Anda'), findsOneWidget);

      // Confirm with 5, 6, 7, 8
      await tester.tap(find.byKey(const Key('btn_pin_digit_5')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_pin_digit_6')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_pin_digit_7')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_pin_digit_8')));
      await tester.pumpAndSettle();

      expect(newlySetPin, '5678');
      expect(AppState.instance.userProfile.pinCode, '5678');
      expect(AppState.instance.userProfile.pinEnabled, true);
    });

    testWidgets('biometric button triggers biometric simulation bottom sheet and unlocks',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool unlocked = false;
      await tester.pumpWidget(
        buildTestableWidget(
          onUnlockSuccess: () => unlocked = true,
        ),
      );
      await tester.pumpAndSettle();

      // Tap Biometric button
      await tester.tap(find.byKey(const Key('btn_biometric_auth')));
      await tester.pumpAndSettle();

      expect(find.text('Autentikasi Biometrik'), findsOneWidget);
      expect(find.byKey(const Key('btn_confirm_biometric_scan')), findsOneWidget);

      // Confirm biometric scan
      await tester.tap(find.byKey(const Key('btn_confirm_biometric_scan')));
      await tester.pumpAndSettle();

      expect(unlocked, true);
    });
  });
}
