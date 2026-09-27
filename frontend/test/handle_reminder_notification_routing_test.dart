import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/screens/beranda/beranda_screen.dart';
import 'package:moneta/screens/beranda/pengaturan_pengingat_screen.dart';
import 'package:moneta/screens/main_navigation_screen.dart';
import 'package:moneta/services/mock_notification_service.dart';
import 'package:moneta/state/app_state.dart';
import 'package:moneta/theme/app_theme.dart';
import 'package:moneta/widgets/in_app_notification_banner.dart';

void main() {
  setUp(() {
    AppState.instance.resetToDefault();
    MockNotificationService.instance.resetForTesting();
  });

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      navigatorKey: MockNotificationService.navigatorKey,
      theme: AppTheme.lightTheme,
      home: AppStateScope(
        notifier: AppState.instance,
        child: child,
      ),
      routes: {
        '/beranda': (_) => const BerandaScreen(),
        '/pengaturan-pengingat': (_) => const PengaturanPengingatScreen(),
      },
    );
  }

  group('MockNotificationService Unit Tests', () {
    test('showReminderNotification sets current notification and appends to history', () {
      final service = MockNotificationService.instance;
      expect(service.currentNotification, isNull);
      expect(service.history, isEmpty);

      final payload = service.showReminderNotification(
        title: 'Saran Harian Test',
        body: 'Batas belanja aman Rp 65.000',
        targetRoute: '/beranda',
      );

      expect(service.currentNotification, equals(payload));
      expect(service.history.length, equals(1));
      expect(payload.title, equals('Saran Harian Test'));
      expect(payload.targetRoute, equals('/beranda'));

      // Dismiss
      service.dismissCurrentNotification();
      expect(service.currentNotification, isNull);
      expect(service.history.length, equals(1));
    });
  });

  group('InAppNotificationBanner Widget Tests', () {
    testWidgets('renders banner content and tapping directs to Beranda',
        (tester) async {
      bool tapped = false;
      bool dismissed = false;

      final payload = NotificationPayload(
        id: 'test_payload_1',
        title: 'Saran Pagi Hari Ini',
        body: 'Batas belanja aman Rp 65.000.',
        targetRoute: '/beranda',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InAppNotificationBanner(
              payload: payload,
              onTap: () => tapped = true,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('in_app_reminder_notification_banner')), findsOneWidget);
      expect(find.text('Saran Pagi Hari Ini'), findsOneWidget);
      expect(find.text('Batas belanja aman Rp 65.000.'), findsOneWidget);
      expect(find.text('Ketuk untuk buka Beranda'), findsOneWidget);

      // Tap banner
      await tester.tap(find.byKey(const Key('btn_tap_notification_banner')));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);

      // Tap dismiss
      await tester.tap(find.byKey(const Key('btn_dismiss_notification_banner')));
      await tester.pumpAndSettle();
      expect(dismissed, isTrue);
    });
  });

  group('Reminder Notification Routing to Beranda Integration Tests', () {
    testWidgets('incoming notification in MainNavigationScreen routes to Beranda on tap',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(const MainNavigationScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('in_app_reminder_notification_banner')), findsNothing);

      // Trigger reminder notification
      MockNotificationService.instance.showReminderNotification();
      await tester.pumpAndSettle();

      // Banner should appear at top
      expect(find.byKey(const Key('in_app_reminder_notification_banner')), findsOneWidget);
      expect(find.text('Moneta AI • Saran Belanja Hari Ini'), findsOneWidget);

      // Tap banner to open Beranda
      await tester.tap(find.byKey(const Key('btn_tap_notification_banner')));
      await tester.pumpAndSettle();

      // Should have navigated to BerandaScreen
      expect(find.text('Selamat Datang di Moneta ✨'), findsOneWidget);
      expect(find.byKey(const Key('daily_advice_card')), findsOneWidget);
      expect(find.byKey(const Key('safe_spending_limit_card')), findsOneWidget);
    });

    testWidgets('dismissing banner in MainNavigationScreen removes notification',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const MainNavigationScreen()),
      );
      await tester.pumpAndSettle();

      MockNotificationService.instance.showReminderNotification();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('in_app_reminder_notification_banner')), findsOneWidget);

      // Dismiss banner
      await tester.tap(find.byKey(const Key('btn_dismiss_notification_banner')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('in_app_reminder_notification_banner')), findsNothing);
      expect(MockNotificationService.instance.currentNotification, isNull);
    });

    testWidgets('PengaturanPengingatScreen notification preview button directs to Beranda',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(const PengaturanPengingatScreen()),
      );
      await tester.pumpAndSettle();

      // Trigger test notification
      await tester.ensureVisible(find.byKey(const Key('btn_test_notification')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_test_notification')));
      await tester.pumpAndSettle();

      // Preview banner is displayed with Buka Beranda button
      expect(find.byKey(const Key('notification_mock_preview')), findsOneWidget);
      expect(find.byKey(const Key('btn_open_beranda_from_notification')), findsOneWidget);

      // Tap Buka Beranda
      await tester.tap(find.byKey(const Key('btn_open_beranda_from_notification')));
      await tester.pumpAndSettle();

      // Should be on BerandaScreen
      expect(find.text('Selamat Datang di Moneta ✨'), findsOneWidget);
      expect(find.byKey(const Key('daily_advice_card')), findsOneWidget);
    });
  });
}
