import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/screens/budget/atur_budget_screen.dart';
import 'package:moneta/screens/budget/widgets/budget_alert_settings_card.dart';

void main() {
  group('BudgetAlertSettingsCard Widget Tests', () {
    testWidgets('renders master switch, threshold chips, and sub-options when enabled', (WidgetTester tester) async {
      bool alertToggled = false;
      double? selectedThreshold;
      bool pushToggled = false;
      bool overToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BudgetAlertSettingsCard(
                isAlertEnabled: true,
                alertThreshold: 80.0,
                isPushNotificationEnabled: true,
                isOverBudgetAlertEnabled: true,
                onToggleAlert: (val) => alertToggled = val,
                onSelectThreshold: (val) => selectedThreshold = val,
                onTogglePushNotification: (val) => pushToggled = val,
                onToggleOverBudgetAlert: (val) => overToggled = val,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Card structure
      expect(find.byKey(const Key('budget_alert_settings_card')), findsOneWidget);
      expect(find.byKey(const Key('budget_alert_settings_title')), findsOneWidget);
      expect(find.text('Peringatan Budget'), findsOneWidget);
      expect(find.text('Notifikasi & peringatan batas aktif'), findsOneWidget);

      // Master switch
      expect(find.byKey(const Key('toggle_budget_warning_switch')), findsOneWidget);

      // Threshold chips
      expect(find.byKey(const Key('threshold_chip_80')), findsOneWidget);
      expect(find.byKey(const Key('threshold_chip_85')), findsOneWidget);
      expect(find.byKey(const Key('threshold_chip_90')), findsOneWidget);

      // Sub-options
      expect(find.byKey(const Key('toggle_overbudget_alert_switch')), findsOneWidget);
      expect(find.byKey(const Key('toggle_push_notification_switch')), findsOneWidget);

      // Status text
      expect(find.byKey(const Key('budget_alert_status_text')), findsOneWidget);
      expect(find.textContaining('Anda akan diberi peringatan saat pengeluaran mencapai 80% dari plafon.'), findsOneWidget);

      // Tap 85% threshold
      await tester.tap(find.byKey(const Key('threshold_chip_85')));
      expect(selectedThreshold, 85.0);

      // Toggle overbudget switch
      await tester.tap(find.byKey(const Key('toggle_overbudget_alert_switch')));
      expect(overToggled, isFalse);

      // Toggle push notification switch
      await tester.tap(find.byKey(const Key('toggle_push_notification_switch')));
      expect(pushToggled, isFalse);

      // Toggle master switch
      await tester.tap(find.byKey(const Key('toggle_budget_warning_switch')));
      expect(alertToggled, isFalse);
    });

    testWidgets('renders disabled banner and hides options when isAlertEnabled is false', (WidgetTester tester) async {
      bool alertToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BudgetAlertSettingsCard(
                isAlertEnabled: false,
                onToggleAlert: (val) => alertToggled = val,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Peringatan dinonaktifkan'), findsOneWidget);
      expect(find.byKey(const Key('budget_alert_disabled_banner')), findsOneWidget);
      expect(find.textContaining('Peringatan budget sedang dinonaktifkan'), findsOneWidget);

      // Threshold chips and sub-options should be hidden
      expect(find.byKey(const Key('threshold_chip_80')), findsNothing);
      expect(find.byKey(const Key('toggle_overbudget_alert_switch')), findsNothing);
      expect(find.byKey(const Key('toggle_push_notification_switch')), findsNothing);

      // Toggle master switch to enable
      await tester.tap(find.byKey(const Key('toggle_budget_warning_switch')));
      expect(alertToggled, isTrue);
    });
  });

  group('AturBudgetScreen Integration with BudgetAlertSettingsCard', () {
    testWidgets('toggling budget alert on/off suppresses and restores warning banners', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      await tester.pumpWidget(
        const MaterialApp(
          home: AturBudgetScreen(initialMonth: '2026-08'),
        ),
      );
      await tester.pumpAndSettle();

      // In Agustus 2026 (90% spent), warning banner is visible
      expect(find.byKey(const Key('budget_near_limit_banner')), findsOneWidget);

      // Scroll to BudgetAlertSettingsCard
      final settingsFinder = find.byKey(const Key('budget_alert_settings_card'));
      await tester.ensureVisible(settingsFinder);

      // Toggle alert switch off
      final toggleFinder = find.byKey(const Key('toggle_budget_warning_switch'));
      await tester.ensureVisible(toggleFinder);
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      // Verify snackbar
      expect(find.text('Peringatan budget dinonaktifkan.'), findsOneWidget);

      // Scroll back up and verify warning banner is suppressed
      await tester.ensureVisible(find.byKey(const Key('current_budget_month_label')));
      expect(find.byKey(const Key('budget_near_limit_banner')), findsNothing);

      // Scroll down and toggle alert switch back on
      await tester.ensureVisible(toggleFinder);
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      // Verify snackbar
      expect(find.text('Peringatan budget diaktifkan.'), findsOneWidget);

      // Scroll up and verify warning banner reappears
      await tester.ensureVisible(find.byKey(const Key('current_budget_month_label')));
      expect(find.byKey(const Key('budget_near_limit_banner')), findsOneWidget);
    });
  });
}
