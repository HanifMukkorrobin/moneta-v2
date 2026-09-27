import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/models/user_profile.dart';
import 'package:moneta/screens/akun_pengaturan/akun_pengaturan_screen.dart';
import 'package:moneta/screens/chat/chat_screen.dart';
import 'package:moneta/screens/main_navigation_screen.dart';
import 'package:moneta/state/app_state.dart';
import 'package:moneta/theme/app_theme.dart';

void main() {
  setUp(() {
    AppState.instance.resetToDefault();
  });

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: AppStateScope(
        notifier: AppState.instance,
        child: child,
      ),
      routes: {
        '/akun': (_) => const AkunPengaturanScreen(),
        '/pengaturan': (_) => const AkunPengaturanScreen(),
      },
    );
  }

  group('AkunPengaturanScreen Widget Tests', () {
    testWidgets('renders profile header, display name, email, and tier badge',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(const AkunPengaturanScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('akun_pengaturan_screen')), findsOneWidget);
      expect(find.text('Akun & Pengaturan'), findsOneWidget);

      // Profile Header Card
      expect(find.byKey(const Key('profile_header_card')), findsOneWidget);
      expect(find.byKey(const Key('profile_display_name_text')), findsOneWidget);
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.byKey(const Key('profile_email_text')), findsOneWidget);
      expect(find.text('budi.santoso@moneta.ai'), findsOneWidget);
      expect(find.byKey(const Key('profile_tier_badge')), findsOneWidget);
      expect(find.text('Personal AI'), findsOneWidget);
      expect(find.byKey(const Key('btn_edit_profile')), findsOneWidget);
    });

    testWidgets('edit profile dialog updates display name and email in AppState',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(const AkunPengaturanScreen()),
      );
      await tester.pumpAndSettle();

      // Tap Edit Profile
      await tester.tap(find.byKey(const Key('btn_edit_profile')));
      await tester.pumpAndSettle();

      expect(find.text('Ubah Profil Akun'), findsOneWidget);
      expect(find.byKey(const Key('edit_profile_name_field')), findsOneWidget);
      expect(find.byKey(const Key('edit_profile_email_field')), findsOneWidget);

      // Enter new name and email
      await tester.enterText(
          find.byKey(const Key('edit_profile_name_field')), 'Hanif Mukkorrobin');
      await tester.enterText(
          find.byKey(const Key('edit_profile_email_field')), 'hanif@moneta.ai');
      await tester.pumpAndSettle();

      // Tap Save
      await tester.tap(find.byKey(const Key('btn_save_profile_dialog')));
      await tester.pumpAndSettle();

      // Check updated UI
      expect(find.text('Hanif Mukkorrobin'), findsOneWidget);
      expect(find.text('hanif@moneta.ai'), findsOneWidget);
      expect(AppState.instance.userProfile.displayName, 'Hanif Mukkorrobin');
      expect(AppState.instance.userProfile.email, 'hanif@moneta.ai');
    });

    testWidgets('currency picker tile updates selected currency in AppState',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(const AkunPengaturanScreen()),
      );
      await tester.pumpAndSettle();

      // Tap Currency Tile
      await tester.tap(find.byKey(const Key('setting_currency_tile')));
      await tester.pumpAndSettle();

      expect(find.text('Pilih Mata Uang Utama'), findsOneWidget);
      expect(find.byKey(const Key('currency_option_USD')), findsOneWidget);

      // Tap USD
      await tester.tap(find.byKey(const Key('currency_option_USD')));
      await tester.pumpAndSettle();

      expect(AppState.instance.userProfile.currency, 'USD');
      expect(AppState.instance.userProfile.currencySymbol, '\$');
      expect(find.text('USD (\$)'), findsOneWidget);
    });

    testWidgets('AI advice tone picker updates tone in AppState',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(const AkunPengaturanScreen()),
      );
      await tester.pumpAndSettle();

      // Tap AI Tone Tile
      await tester.tap(find.byKey(const Key('setting_ai_tone_tile')));
      await tester.pumpAndSettle();

      expect(find.text('Gaya Bahasa Saran Finansial AI'), findsOneWidget);
      expect(find.byKey(const Key('ai_tone_option_Tegas')), findsOneWidget);

      // Select Tegas
      await tester.tap(find.byKey(const Key('ai_tone_option_Tegas')));
      await tester.pumpAndSettle();

      expect(AppState.instance.userProfile.aiAdviceTone, 'Tegas');
      expect(find.text('Mode saat ini: Tegas'), findsOneWidget);
    });

    testWidgets('security PIN and Biometric switches toggle state in AppState',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(const AkunPengaturanScreen()),
      );
      await tester.pumpAndSettle();

      // Initial state
      expect(AppState.instance.userProfile.pinEnabled, false);
      expect(AppState.instance.userProfile.biometricEnabled, false);

      // Toggle PIN switch
      await tester.tap(find.byKey(const Key('setting_pin_switch')));
      await tester.pumpAndSettle();
      expect(AppState.instance.userProfile.pinEnabled, true);

      // Toggle Biometric switch
      await tester.tap(find.byKey(const Key('setting_biometric_switch')));
      await tester.pumpAndSettle();
      expect(AppState.instance.userProfile.biometricEnabled, true);
    });

    testWidgets('export data tile shows export formats dialog',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(const AkunPengaturanScreen()),
      );
      await tester.pumpAndSettle();

      // Tap Export Data Tile
      await tester.tap(find.byKey(const Key('setting_export_data_tile')));
      await tester.pumpAndSettle();

      expect(find.text('Ekspor Data Transaksi'), findsOneWidget);
      expect(find.byKey(const Key('btn_export_csv')), findsOneWidget);
      expect(find.byKey(const Key('btn_export_json')), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_export_csv')));
      await tester.pumpAndSettle();
      expect(find.text('Ekspor Data Transaksi'), findsNothing);
    });

    testWidgets('reset simulation data shows confirmation dialog and resets state',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(const AkunPengaturanScreen()),
      );
      await tester.pumpAndSettle();

      // Modify state first
      AppState.instance.updateUserProfile(
        AppState.instance.userProfile.copyWith(displayName: 'Test Modified'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Test Modified'), findsOneWidget);

      // Tap Reset Data Tile
      await tester.tap(find.byKey(const Key('setting_reset_data_tile')));
      await tester.pumpAndSettle();

      expect(find.text('Reset Data Lokal?'), findsOneWidget);
      expect(find.byKey(const Key('btn_confirm_reset_data')), findsOneWidget);

      // Confirm Reset
      await tester.tap(find.byKey(const Key('btn_confirm_reset_data')));
      await tester.pumpAndSettle();

      // Back to default Budi Santoso
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(AppState.instance.userProfile.displayName, 'Budi Santoso');
    });

    testWidgets('MainNavigationScreen bottom navigation tab opens AkunPengaturanScreen',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(const MainNavigationScreen()),
      );
      await tester.pumpAndSettle();

      // Tap Akun destination in NavigationBar
      final akunDestFinder = find.text('Akun');
      expect(akunDestFinder, findsOneWidget);
      await tester.tap(akunDestFinder);
      await tester.pumpAndSettle();

      // AkunPengaturanScreen should be visible
      expect(find.byKey(const Key('akun_pengaturan_screen')), findsOneWidget);
      expect(find.byKey(const Key('profile_header_card')), findsOneWidget);
      expect(find.text('Akun & Pengaturan'), findsOneWidget);
    });

    testWidgets('ChatScreen AppBar account button navigates to AkunPengaturanScreen',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(const ChatScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('chat_appbar_account_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('chat_appbar_account_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('akun_pengaturan_screen')), findsOneWidget);
      expect(find.text('Budi Santoso'), findsOneWidget);
    });
  });
}
