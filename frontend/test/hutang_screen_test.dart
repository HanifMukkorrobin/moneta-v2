import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/mock/debt_mock_data.dart';
import 'package:moneta/models/debt_item.dart';
import 'package:moneta/screens/hutang/hutang_screen.dart';
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
        '/hutang': (_) => const HutangScreen(),
      },
    );
  }

  group('HutangScreen Widget Tests', () {
    testWidgets('renders AppBar, DebtSummaryCard, and initial mock debts',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const HutangScreen()),
      );
      await tester.pumpAndSettle();

      // Check AppBar
      expect(find.text('Catatan Hutang & Paylater'), findsOneWidget);
      expect(find.byKey(const Key('btn_refresh_debts')), findsOneWidget);

      // Check DebtSummaryCard
      expect(find.byKey(const Key('debt_summary_card')), findsOneWidget);
      expect(find.byKey(const Key('total_remaining_debt_text')), findsOneWidget);
      expect(find.byKey(const Key('active_debts_count_badge')), findsOneWidget);
      expect(find.text('Ringkasan Hutang'), findsOneWidget);
      expect(find.byKey(const Key('due_soon_alert_box')), findsOneWidget);

      // Check initial mock items
      final initialDebts = DebtMockData.getInitialDebts();
      for (var debt in initialDebts) {
        expect(find.byKey(Key('debt_card_${debt.id}')), findsOneWidget);
      }

      // Check FAB
      expect(find.byKey(const Key('btn_add_debt_fab')), findsOneWidget);
    });

    testWidgets('filters debts by status tabs (Semua, Aktif, Jatuh Tempo Dekat, Lunas)',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const HutangScreen()),
      );
      await tester.pumpAndSettle();

      // Tap 'Aktif'
      await tester.tap(find.byKey(const Key('filter_debt_active')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('debt_card_debt_1')), findsOneWidget); // active
      expect(find.byKey(const Key('debt_card_debt_4')), findsNothing); // paid

      // Tap 'Lunas'
      await tester.tap(find.byKey(const Key('filter_debt_paid')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('debt_card_debt_1')), findsNothing); // active
      expect(find.byKey(const Key('debt_card_debt_4')), findsOneWidget); // paid

      // Tap 'Jatuh Tempo Dekat'
      await tester.tap(find.byKey(const Key('filter_debt_due_soon')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('debt_card_debt_1')), findsOneWidget); // due in 2 days
      expect(find.byKey(const Key('debt_card_debt_2')), findsNothing); // due in 12 days

      // Tap 'Semua'
      await tester.tap(find.byKey(const Key('filter_debt_all')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('debt_card_debt_1')), findsOneWidget);
      expect(find.byKey(const Key('debt_card_debt_4')), findsOneWidget);
    });

    testWidgets('searches debts by name and notes', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(const HutangScreen()),
      );
      await tester.pumpAndSettle();

      // Search 'laptop'
      await tester.enterText(find.byKey(const Key('debt_search_input')), 'laptop');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('debt_card_debt_2')), findsOneWidget);
      expect(find.byKey(const Key('debt_card_debt_1')), findsNothing);

      // Clear search
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('debt_card_debt_1')), findsOneWidget);
    });

    testWidgets('marking a debt as paid updates its card and summary state',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final customDebts = [
        DebtItem(
          id: 'test_debt_mark_1',
          name: 'Hutang Tes Pembayaran',
          totalAmount: 500000,
          remainingAmount: 500000,
          dueDate: now.add(const Duration(days: 3)),
          status: 'active',
          type: DebtType.paylater,
        ),
      ];

      await tester.pumpWidget(
        buildTestableWidget(HutangScreen(initialDebts: customDebts)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('btn_mark_paid_test_debt_mark_1')), findsOneWidget);
      expect(find.text('Rp 500.000'), findsWidgets);

      // Ensure visible and tap mark paid button
      final markPaidBtn = find.byKey(const Key('btn_mark_paid_test_debt_mark_1'));
      await tester.ensureVisible(markPaidBtn);
      await tester.pumpAndSettle();
      await tester.tap(markPaidBtn);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('berhasil ditandai lunas!'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('paid_indicator_test_debt_mark_1')), findsOneWidget);
      expect(find.byKey(const Key('btn_mark_paid_test_debt_mark_1')), findsNothing);
      expect(find.text('0 Tagihan Aktif'), findsOneWidget);
    });

    testWidgets('renders empty state when filter matches nothing and resets cleanly',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(const HutangScreen()),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('debt_search_input')),
        'keyword-pencarian-tidak-ada-999',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('debt_empty_state')), findsOneWidget);
      expect(find.text('Tidak ada catatan hutang ditemukan'), findsOneWidget);

      // Scroll to reset button and tap
      await tester.ensureVisible(find.byKey(const Key('btn_reset_debt_filters')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_reset_debt_filters')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('debt_empty_state')), findsNothing);
      expect(find.byKey(const Key('debt_card_debt_1')), findsOneWidget);
    });

    testWidgets('MainNavigationScreen bottom navigation tab opens HutangScreen',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(const MainNavigationScreen()),
      );
      await tester.pumpAndSettle();

      // Tap Hutang destination in NavigationBar
      final hutangDestFinder = find.text('Hutang');
      expect(hutangDestFinder, findsOneWidget);
      await tester.tap(hutangDestFinder);
      await tester.pumpAndSettle();

      // HutangScreen should be active
      expect(find.byKey(const Key('hutang_screen')), findsOneWidget);
      expect(find.byKey(const Key('debt_summary_card')), findsOneWidget);
      expect(find.text('Catatan Hutang & Paylater'), findsOneWidget);
    });
  });
}
