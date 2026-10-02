import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/models/debt_item.dart';
import 'package:moneta/screens/hutang/hutang_screen.dart';
import 'package:moneta/screens/main_navigation_screen.dart';
import 'package:moneta/state/app_state.dart';
import 'package:moneta/theme/app_theme.dart';

void main() {
  setUp(() {
    AppState.instance.resetToDefault();
  });

  group('AppState Catatan Hutang Unit Tests', () {
    test('initializes with default mock debts from DebtItem', () {
      final state = AppState.instance;
      expect(state.debts.isNotEmpty, isTrue);
      expect(state.debts.length, 5);
      expect(state.activeDebtsCount, 3);
      expect(state.paidDebtsCount, 2);
      expect(state.totalRemainingDebt, 450000 + 3000000 + 850000);
      expect(state.totalOriginalDebt, 1250000 + 6000000 + 850000 + 300000 + 275000);
    });

    test('addDebt adds debt at front and notifies listeners', () {
      final state = AppState.instance;
      int notifyCount = 0;
      state.addListener(() => notifyCount++);

      final newDebt = DebtItem(
        id: 'new_debt_test',
        name: 'Cicilan HP Samsung',
        totalAmount: 4000000,
        remainingAmount: 4000000,
        dueDate: DateTime.now().add(const Duration(days: 15)),
        status: 'active',
        type: DebtType.cicilan,
      );

      state.addDebt(newDebt);

      expect(notifyCount, 1);
      expect(state.debts.first.id, 'new_debt_test');
      expect(state.debts.length, 6);
      expect(state.activeDebtsCount, 4);
      expect(state.totalRemainingDebt, 4300000 + 4000000);
    });

    test('markDebtPaid marks debt as paid and clears remaining amount', () {
      final state = AppState.instance;
      int notifyCount = 0;
      state.addListener(() => notifyCount++);

      state.markDebtPaid('debt_1');

      expect(notifyCount, 1);
      final debt1 = state.debts.firstWhere((d) => d.id == 'debt_1');
      expect(debt1.isPaid, isTrue);
      expect(debt1.remainingAmount, 0);
      expect(state.activeDebtsCount, 2);
      expect(state.paidDebtsCount, 3);
    });

    test('reopenDebt reactivates paid debt and restores remaining amount', () {
      final state = AppState.instance;
      int notifyCount = 0;
      state.addListener(() => notifyCount++);

      state.reopenDebt('debt_4');

      expect(notifyCount, 1);
      final debt4 = state.debts.firstWhere((d) => d.id == 'debt_4');
      expect(debt4.isPaid, isFalse);
      expect(debt4.remainingAmount, 300000);
      expect(state.activeDebtsCount, 4);
      expect(state.paidDebtsCount, 1);
    });

    test('recordDebtPayment handles partial and full payment cleanly', () {
      final state = AppState.instance;

      // Partial payment
      state.recordDebtPayment('debt_3', 350000, isFull: false);
      var debt3 = state.debts.firstWhere((d) => d.id == 'debt_3');
      expect(debt3.remainingAmount, 500000);
      expect(debt3.isPaid, isFalse);

      // Full payment via remaining amount
      state.recordDebtPayment('debt_3', 500000, isFull: true);
      debt3 = state.debts.firstWhere((d) => d.id == 'debt_3');
      expect(debt3.remainingAmount, 0);
      expect(debt3.isPaid, isTrue);
    });

    test('restoreDebt reverts a debt to previous state for Undo', () {
      final state = AppState.instance;
      final original = state.debts.firstWhere((d) => d.id == 'debt_1');

      state.markDebtPaid('debt_1');
      expect(state.debts.firstWhere((d) => d.id == 'debt_1').isPaid, isTrue);

      state.restoreDebt('debt_1', original);
      final restored = state.debts.firstWhere((d) => d.id == 'debt_1');
      expect(restored.isPaid, isFalse);
      expect(restored.remainingAmount, 450000);
    });

    test('resetDebts restores default initial mock debts', () {
      final state = AppState.instance;
      state.markDebtPaid('debt_1');
      state.markDebtPaid('debt_2');
      expect(state.activeDebtsCount, 1);

      state.resetDebts();
      expect(state.activeDebtsCount, 3);
      expect(state.paidDebtsCount, 2);
    });
  });

  group('HutangScreen and AppState Live Integration Tests', () {
    Widget buildApp({Widget? child}) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: AppStateScope(
          notifier: AppState.instance,
          child: child ?? const HutangScreen(),
        ),
      );
    }

    testWidgets('HutangScreen loads from AppState.instance when initialDebts is omitted',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hutang_screen')), findsOneWidget);
      expect(find.text('3 Tagihan Aktif'), findsOneWidget);
      expect(find.byKey(const Key('debt_card_debt_1')), findsOneWidget);
      expect(find.byKey(const Key('debt_card_debt_2')), findsOneWidget);
      expect(find.byKey(const Key('debt_card_debt_3')), findsOneWidget);
    });

    testWidgets('adding debt via TambahHutangBottomSheet modifies AppState.instance',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      final initialCount = AppState.instance.debts.length;

      // Open bottom sheet
      await tester.tap(find.byKey(const Key('btn_add_debt_fab')));
      await tester.pumpAndSettle();

      // Enter debt info
      await tester.enterText(
          find.byKey(const Key('input_debt_name')), 'Paylater Tokopedia Live');
      await tester.enterText(
          find.byKey(const Key('input_debt_total_amount')), '500000');

      final submitBtn = find.byKey(const Key('btn_submit_debt'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Verify SnackBar & AppState updated
      expect(find.byKey(const Key('snackbar_debt_added')), findsOneWidget);
      expect(AppState.instance.debts.length, initialCount + 1);
      expect(AppState.instance.debts.first.name, 'Paylater Tokopedia Live');
      expect(find.text('4 Tagihan Aktif'), findsOneWidget);
    });

    testWidgets('marking debt as paid updates AppState and moves item to Lunas',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Mark debt_1 as paid
      await tester.tap(find.byKey(const Key('btn_mark_paid_debt_1')));
      await tester.pumpAndSettle();

      // AppState updated
      expect(AppState.instance.debts.firstWhere((d) => d.id == 'debt_1').isPaid,
          isTrue);
      expect(AppState.instance.activeDebtsCount, 2);
      expect(find.text('2 Tagihan Aktif'), findsOneWidget);

      // Tap Undo
      await tester.tap(find.byKey(const Key('btn_undo_mark_paid')));
      await tester.pumpAndSettle();

      // AppState reverted
      expect(AppState.instance.debts.firstWhere((d) => d.id == 'debt_1').isPaid,
          isFalse);
      expect(AppState.instance.activeDebtsCount, 3);
      expect(find.text('3 Tagihan Aktif'), findsOneWidget);
    });

    testWidgets('reopening debt in Lunas tab updates AppState back to active',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Switch to Lunas filter tab
      await tester.tap(find.byKey(const Key('filter_debt_paid')));
      await tester.pumpAndSettle();

      // Tap reopen on debt_4
      final reopenBtn = find.byKey(const Key('btn_reopen_debt_debt_4'));
      expect(reopenBtn, findsOneWidget);
      await tester.tap(reopenBtn);
      await tester.pumpAndSettle();

      expect(AppState.instance.debts.firstWhere((d) => d.id == 'debt_4').isPaid,
          isFalse);
      expect(AppState.instance.activeDebtsCount, 4);
    });

    testWidgets('appbar refresh resets AppState debts back to initial mock data',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Mark debt_1 paid
      await tester.tap(find.byKey(const Key('btn_mark_paid_debt_1')));
      await tester.pumpAndSettle();
      expect(AppState.instance.activeDebtsCount, 2);

      // Tap refresh in AppBar
      await tester.tap(find.byKey(const Key('btn_refresh_debts')));
      await tester.pumpAndSettle();

      expect(AppState.instance.activeDebtsCount, 3);
      expect(find.text('3 Tagihan Aktif'), findsOneWidget);
    });

    testWidgets('debt state persists when switching tabs in MainNavigationScreen',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: AppStateScope(
            notifier: AppState.instance,
            child: const MainNavigationScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Hutang tab
      await tester.tap(find.text('Hutang'));
      await tester.pumpAndSettle();

      // Mark debt_1 as paid
      await tester.tap(find.byKey(const Key('btn_mark_paid_debt_1')));
      await tester.pumpAndSettle();
      expect(find.text('2 Tagihan Aktif'), findsOneWidget);

      // Switch to Chat tab
      await tester.tap(find.text('Chat'));
      await tester.pumpAndSettle();
      expect(find.text('Moneta AI'), findsOneWidget);

      // Switch back to Hutang tab
      await tester.tap(find.text('Hutang'));
      await tester.pumpAndSettle();

      // State is preserved!
      expect(find.text('2 Tagihan Aktif'), findsOneWidget);
      expect(AppState.instance.debts.firstWhere((d) => d.id == 'debt_1').isPaid,
          isTrue);
    });
  });
}
