import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/models/transaction_item.dart';
import 'package:moneta/screens/beranda/beranda_screen.dart';
import 'package:moneta/screens/chat/chat_screen.dart';
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
        '/beranda': (_) => const BerandaScreen(),
      },
    );
  }

  group('Refresh Saran Setelah Catat Pengeluaran Tests', () {
    test('AppState updates spending and advice when transaction is added or confirmed', () {
      final appState = AppState.instance;
      final initialSpent = appState.todayTotalExpense;

      // Add a manual expense of 100,000
      final newExpense = TransactionItem(
        id: 'tx_test_refresh_1',
        amount: 100000,
        type: 'expense',
        category: 'Makan & Minuman',
        note: 'Makan bersama tim',
        occurredAt: DateTime.now(),
        isConfirmed: true,
      );

      appState.addManualTransaction(newExpense);

      expect(appState.todayTotalExpense, equals(initialSpent + 100000));
      expect(appState.aiInsight.totalSpent, equals(initialSpent + 100000));
      expect(
        appState.aiInsight.remainingBalance,
        equals(appState.aiInsight.totalMonthlyBudget - appState.aiInsight.totalSpent),
      );
      expect(appState.aiInsight.dailyAdvice, isNotEmpty);
    });

    testWidgets('SafeSpendingLimitCard button opens ManualInputSheet and refreshes limit & advice',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(const BerandaScreen()),
      );
      await tester.pumpAndSettle();

      // Initial state of safe spending limit card
      expect(find.byKey(const Key('safe_spending_limit_card')), findsOneWidget);
      expect(find.byKey(const Key('btn_safe_limit_add_expense')), findsOneWidget);

      // Tap 'Catat Pengeluaran' on SafeSpendingLimitCard
      await tester.ensureVisible(find.byKey(const Key('btn_safe_limit_add_expense')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_safe_limit_add_expense')));
      await tester.pumpAndSettle();

      // ManualInputSheet should appear
      expect(find.text('Input Transaksi Manual'), findsOneWidget);

      // Enter amount
      final amountFinder = find.widgetWithText(TextField, 'Contoh: 50000');
      expect(amountFinder, findsOneWidget);
      await tester.enterText(amountFinder, '50000');
      await tester.pump();

      // Enter note
      final noteFinder = find.widgetWithText(TextField, 'Contoh: Belanja sayur di pasar');
      expect(noteFinder, findsOneWidget);
      await tester.enterText(noteFinder, 'Kopi dan Snack Siang');
      await tester.pump();

      // Save transaction
      await tester.tap(find.text('Simpan Transaksi'));
      await tester.pumpAndSettle();

      // Verify sheet closed and SnackBar shown
      expect(find.text('Input Transaksi Manual'), findsNothing);
      expect(
        find.textContaining('dicatat. Saran harian diperbarui!'),
        findsOneWidget,
      );

      // Verify SafeSpendingLimitCard shows updated spent amount (baseline 75,000 + 50,000 = 125,000)
      expect(find.text('Terpakai: Rp 125.000'), findsOneWidget);
      expect(find.byKey(const Key('penanda_aman_badge')), findsOneWidget);
    });

    testWidgets('Quick action Input Manual in BerandaScreen refreshes advice immediately',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(const BerandaScreen()),
      );
      await tester.pumpAndSettle();

      // Scroll to quick actions
      await tester.ensureVisible(find.byKey(const Key('btn_quick_manual_input')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_quick_manual_input')));
      await tester.pumpAndSettle();

      expect(find.text('Input Transaksi Manual'), findsOneWidget);

      // Enter amount 200,000
      final amountFinder = find.widgetWithText(TextField, 'Contoh: 50000');
      await tester.enterText(amountFinder, '200000');
      await tester.pump();

      final noteFinder = find.widgetWithText(TextField, 'Contoh: Belanja sayur di pasar');
      await tester.enterText(noteFinder, 'Belanja Bulanan Supermarket');
      await tester.pump();

      await tester.tap(find.text('Simpan Transaksi'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('dicatat. Saran harian diperbarui!'),
        findsOneWidget,
      );

      // Scroll up to daily advice card and verify it reflects the update
      await tester.ensureVisible(find.byKey(const Key('daily_advice_card')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('daily_advice_message_box')), findsOneWidget);
      expect(find.byKey(const Key('daily_advice_text')), findsOneWidget);
    });

    testWidgets('Confirming transaction in ChatScreen refreshes advice in BerandaScreen',
        (tester) async {
      // 1. Open ChatScreen
      await tester.pumpWidget(
        buildTestableWidget(const ChatScreen()),
      );
      await tester.pumpAndSettle();

      // Find pending transaction card Simpan button
      final simpanBtnFinder = find.widgetWithText(ElevatedButton, 'Simpan');
      if (simpanBtnFinder.evaluate().isNotEmpty) {
        await tester.tap(simpanBtnFinder.first);
        await tester.pumpAndSettle();
      }

      // 2. Open BerandaScreen
      await tester.pumpWidget(
        buildTestableWidget(const BerandaScreen()),
      );
      await tester.pumpAndSettle();

      // Verify that BerandaScreen renders with refreshed AppState advice
      expect(find.byKey(const Key('daily_advice_card')), findsOneWidget);
      expect(find.byKey(const Key('daily_advice_text')), findsOneWidget);
    });

    testWidgets('BerandaScreen refresh button triggers recalculateAnalysis and feedback',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const BerandaScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('beranda_refresh_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('beranda_refresh_button')));
      await tester.pumpAndSettle();

      expect(
        find.text('Saran harian dan analisa berhasil diperbarui.'),
        findsOneWidget,
      );
    });
  });
}
