import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/models/daily_reminder_settings.dart';
import 'package:moneta/screens/beranda/beranda_screen.dart';
import 'package:moneta/screens/beranda/pengaturan_pengingat_screen.dart';
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
        '/pengaturan-pengingat': (_) => const PengaturanPengingatScreen(),
      },
    );
  }

  group('PengaturanPengingatScreen Widget Tests', () {
    testWidgets('renders all initial cards, switches, and default values',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const PengaturanPengingatScreen()),
      );
      await tester.pumpAndSettle();

      // Check AppBar
      expect(find.text('Pengingat Harian'), findsOneWidget);
      expect(find.byKey(const Key('btn_save_reminder_settings')), findsOneWidget);

      // Check Master Switch
      expect(find.byKey(const Key('card_master_reminder')), findsOneWidget);
      expect(find.byKey(const Key('switch_master_reminder')), findsOneWidget);

      // Check Morning & Evening Cards
      expect(find.byKey(const Key('card_morning_reminder')), findsOneWidget);
      expect(find.byKey(const Key('text_morning_reminder_time')), findsOneWidget);
      expect(find.text('08:00 WIB'), findsOneWidget);

      expect(find.byKey(const Key('card_evening_reminder')), findsOneWidget);
      expect(find.byKey(const Key('text_evening_reminder_time')), findsOneWidget);
      expect(find.text('20:00 WIB'), findsOneWidget);

      // Check Active Days
      expect(find.byKey(const Key('card_active_days')), findsOneWidget);
      expect(find.text('Setiap Hari'), findsOneWidget);
      expect(find.byKey(const Key('chip_day_1')), findsOneWidget); // Senin

      // Check AI Alerts
      expect(find.byKey(const Key('card_smart_alerts')), findsOneWidget);
      expect(find.byKey(const Key('switch_alert_overbudget')), findsOneWidget);
      expect(find.byKey(const Key('switch_alert_saving_tips')), findsOneWidget);
      expect(find.byKey(const Key('switch_alert_debt_due')), findsOneWidget);

      // Check Preferences
      expect(find.byKey(const Key('card_system_preferences')), findsOneWidget);
      expect(find.byKey(const Key('switch_sound_enabled')), findsOneWidget);
      expect(find.byKey(const Key('switch_vibration_enabled')), findsOneWidget);

      // Check Buttons
      expect(find.byKey(const Key('btn_test_notification')), findsOneWidget);
    });

    testWidgets('toggles master reminder switch off and on', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const PengaturanPengingatScreen()),
      );
      await tester.pumpAndSettle();

      final switchFinder = find.byKey(const Key('switch_master_reminder'));
      expect(switchFinder, findsOneWidget);

      // Toggle off
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(
        find.text('Semua notifikasi pengingat harian nonaktif'),
        findsOneWidget,
      );

      // Toggle on
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(
        find.text('Notifikasi cerdas dan saran harian aktif'),
        findsOneWidget,
      );
    });

    testWidgets('toggles individual schedule switches', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const PengaturanPengingatScreen()),
      );
      await tester.pumpAndSettle();

      // Toggle Morning Reminder Switch
      await tester.tap(find.byKey(const Key('switch_morning_reminder')));
      await tester.pumpAndSettle();

      // Toggle Evening Reminder Switch
      await tester.tap(find.byKey(const Key('switch_evening_reminder')));
      await tester.pumpAndSettle();
    });

    testWidgets('toggles active days and updates frequency summary',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const PengaturanPengingatScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Setiap Hari'), findsOneWidget);

      // Tap Minggu (day 7) to remove it
      await tester.tap(find.byKey(const Key('chip_day_7')));
      await tester.pumpAndSettle();

      expect(find.text('Setiap Hari'), findsNothing);

      // Tap Sabtu (day 6) to remove it -> Left with 1..5 (Hari Kerja)
      await tester.tap(find.byKey(const Key('chip_day_6')));
      await tester.pumpAndSettle();

      expect(find.text('Hari Kerja (Sen - Jum)'), findsOneWidget);
    });

    testWidgets('prevents removing all days and shows SnackBar warning',
        (tester) async {
      const singleDaySettings = DailyReminderSettings(
        activeDays: [1], // Hanya Senin
      );

      await tester.pumpWidget(
        buildTestableWidget(
          const PengaturanPengingatScreen(initialSettings: singleDaySettings),
        ),
      );
      await tester.pumpAndSettle();

      // Try tapping Senin (day 1)
      await tester.tap(find.byKey(const Key('chip_day_1')));
      await tester.pumpAndSettle();

      expect(
        find.text('Minimal harus ada 1 hari aktif pengingat.'),
        findsOneWidget,
      );
    });

    testWidgets('triggers mock test notification and displays preview banner',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const PengaturanPengingatScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('notification_mock_preview')), findsNothing);

      // Scroll to test notification button and tap
      await tester.ensureVisible(find.byKey(const Key('btn_test_notification')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_test_notification')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('notification_mock_preview')), findsOneWidget);
      expect(
        find.text('Moneta AI • Saran Pagi Ini'),
        findsOneWidget,
      );
      expect(
        find.text('Batas Belanja Aman: Rp 65.000 / Hari'),
        findsOneWidget,
      );
      expect(
        find.text('Notifikasi percobaan berhasil disimulasikan.'),
        findsOneWidget,
      );
    });

    testWidgets('saves settings via save button and updates AppState',
        (tester) async {
      DailyReminderSettings? savedSettings;

      await tester.pumpWidget(
        buildTestableWidget(
          PengaturanPengingatScreen(
            onSave: (settings) => savedSettings = settings,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll and toggle overbudget switch
      await tester.ensureVisible(find.byKey(const Key('switch_alert_overbudget')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('switch_alert_overbudget')));
      await tester.pumpAndSettle();

      // Tap AppBar save button
      await tester.tap(find.byKey(const Key('btn_save_reminder_settings')));
      await tester.pumpAndSettle();

      expect(savedSettings, isNotNull);
      expect(savedSettings!.notifyOnOverbudget, isFalse);
      expect(AppState.instance.reminderSettings.notifyOnOverbudget, isFalse);
    });

    testWidgets('navigates from BerandaScreen AppBar to PengaturanPengingatScreen',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const BerandaScreen()),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('beranda_pengaturan_pengingat_button')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('beranda_pengaturan_pengingat_button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('pengaturan_pengingat_screen')),
        findsOneWidget,
      );
    });
  });
}
