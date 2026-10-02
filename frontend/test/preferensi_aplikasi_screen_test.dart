import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/screens/akun_pengaturan/preferensi_aplikasi_screen.dart';
import 'package:moneta/state/app_state.dart';
import 'package:moneta/theme/app_theme.dart';

void main() {
  setUp(() {
    AppState.instance.resetToDefault();
  });

  void setTestViewSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget createWidgetUnderTest() {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: AppStateScope(
        notifier: AppState.instance,
        child: const PreferensiAplikasiScreen(),
      ),
    );
  }

  testWidgets('renders PreferensiAplikasiScreen with initial profile settings', (tester) async {
    setTestViewSize(tester);
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Preferensi Aplikasi'), findsOneWidget);
    expect(find.text('Tampilan & Format Regional'), findsOneWidget);
    expect(find.text('Kecerdasan Finansial AI'), findsOneWidget);
    expect(find.text('Privasi & Sensor Layar'), findsOneWidget);

    // Initial default values
    expect(find.text('IDR (Rp)'), findsOneWidget);
    expect(find.text('DD/MM/YYYY'), findsOneWidget);
    expect(find.text('Senin'), findsOneWidget);
    expect(find.text('Terang'), findsOneWidget);
    expect(find.text('Standar'), findsOneWidget);
  });

  testWidgets('can change currency using bottom sheet picker', (tester) async {
    setTestViewSize(tester);
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Tap currency tile
    await tester.tap(find.byKey(const Key('pref_currency_tile')));
    await tester.pumpAndSettle();

    expect(find.text('Pilih Mata Uang Utama'), findsOneWidget);
    expect(find.byKey(const Key('pref_currency_option_USD')), findsOneWidget);

    // Select USD
    await tester.tap(find.byKey(const Key('pref_currency_option_USD')));
    await tester.pumpAndSettle();

    expect(AppState.instance.userProfile.currency, 'USD');
    expect(AppState.instance.userProfile.currencySymbol, '\$');
    expect(find.text('USD (\$)'), findsOneWidget);
  });

  testWidgets('can change date format using bottom sheet picker', (tester) async {
    setTestViewSize(tester);
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pref_date_format_tile')));
    await tester.pumpAndSettle();

    expect(find.text('Pilih Format Tanggal'), findsOneWidget);
    final opt = find.byKey(const Key('pref_date_format_option_YYYY-MM-DD'));
    expect(opt, findsOneWidget);

    await tester.tap(opt);
    await tester.pumpAndSettle();

    expect(AppState.instance.userProfile.dateFormat, 'YYYY-MM-DD');
    expect(find.text('YYYY-MM-DD'), findsOneWidget);
  });

  testWidgets('can change first day of week', (tester) async {
    setTestViewSize(tester);
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pref_first_day_tile')));
    await tester.pumpAndSettle();

    expect(find.text('Hari Pertama dalam Seminggu'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pref_first_day_option_Minggu')));
    await tester.pumpAndSettle();

    expect(AppState.instance.userProfile.firstDayOfWeek, 'Minggu');
    expect(find.text('Minggu'), findsOneWidget);
  });

  testWidgets('can change app theme mode', (tester) async {
    setTestViewSize(tester);
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pref_theme_tile')));
    await tester.pumpAndSettle();

    expect(find.text('Tema Tampilan Aplikasi'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pref_theme_option_Gelap')));
    await tester.pumpAndSettle();

    expect(AppState.instance.userProfile.themeMode, 'Gelap');
    expect(find.text('Gelap'), findsOneWidget);
  });

  testWidgets('can change AI advice tone', (tester) async {
    setTestViewSize(tester);
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pref_ai_tone_tile')));
    await tester.pumpAndSettle();

    expect(find.text('Gaya Bahasa Saran Finansial AI'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pref_ai_tone_option_Tegas')));
    await tester.pumpAndSettle();

    expect(AppState.instance.userProfile.aiAdviceTone, 'Tegas');
    expect(find.text('Tegas'), findsOneWidget);
  });

  testWidgets('can change budget alert threshold', (tester) async {
    setTestViewSize(tester);
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pref_budget_alert_threshold_tile')));
    await tester.pumpAndSettle();

    expect(find.text('Ambang Peringatan Pengeluaran Bulanan'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pref_threshold_option_90')));
    await tester.pumpAndSettle();

    expect(AppState.instance.userProfile.budgetAlertThreshold, 90);
    expect(find.text('Peringatkan di 90% dari batas budget'), findsOneWidget);
  });

  testWidgets('can toggle privacy and sensor switches', (tester) async {
    setTestViewSize(tester);
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(AppState.instance.userProfile.autoConfirmChat, false);
    expect(AppState.instance.userProfile.hideBalance, false);
    expect(AppState.instance.userProfile.hapticFeedback, true);

    // Toggle auto confirm
    await tester.tap(find.byKey(const Key('pref_auto_confirm_switch')));
    await tester.pumpAndSettle();
    expect(AppState.instance.userProfile.autoConfirmChat, true);

    // Toggle hide balance
    await tester.tap(find.byKey(const Key('pref_hide_balance_switch')));
    await tester.pumpAndSettle();
    expect(AppState.instance.userProfile.hideBalance, true);

    // Toggle haptic feedback
    await tester.tap(find.byKey(const Key('pref_haptic_feedback_switch')));
    await tester.pumpAndSettle();
    expect(AppState.instance.userProfile.hapticFeedback, false);
  });

  testWidgets('can reset preferences to default values', (tester) async {
    setTestViewSize(tester);

    // Set custom values first
    AppState.instance.updateUserProfile(
      AppState.instance.userProfile.copyWith(
        currency: 'EUR',
        currencySymbol: '€',
        dateFormat: 'YYYY-MM-DD',
        themeMode: 'Gelap',
        aiAdviceTone: 'Tegas',
        hideBalance: true,
        budgetAlertThreshold: 95,
      ),
    );

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('EUR (€)'), findsOneWidget);
    expect(find.text('YYYY-MM-DD'), findsOneWidget);
    expect(find.text('Gelap'), findsOneWidget);

    await tester.tap(find.byKey(const Key('btn_reset_preferences')));
    await tester.pumpAndSettle();

    expect(AppState.instance.userProfile.currency, 'IDR');
    expect(AppState.instance.userProfile.currencySymbol, 'Rp');
    expect(AppState.instance.userProfile.dateFormat, 'DD/MM/YYYY');
    expect(AppState.instance.userProfile.themeMode, 'Terang');
    expect(AppState.instance.userProfile.aiAdviceTone, 'Standar');
    expect(AppState.instance.userProfile.hideBalance, false);
    expect(AppState.instance.userProfile.budgetAlertThreshold, 80);
    expect(find.text('Preferensi aplikasi dikembalikan ke pengaturan default.'), findsOneWidget);
  });
}
