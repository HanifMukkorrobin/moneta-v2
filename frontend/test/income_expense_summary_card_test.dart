import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/models/monthly_rekap_data.dart';
import 'package:moneta/models/transaction_item.dart';
import 'package:moneta/screens/rekap/widgets/income_expense_summary_card.dart';

void main() {
  group('IncomeExpenseSummaryCard (Kartu Ringkasan Pemasukan dan Pengeluaran)', () {
    late MonthlyRekapData surplusData;
    late MonthlyRekapData deficitData;

    setUp(() {
      final transactions = [
        TransactionItem(
          id: 'tx_inc_1',
          note: 'Gaji Pokok',
          amount: 10000000,
          type: 'income',
          category: 'Gaji',
          occurredAt: DateTime(2026, 9, 25),
          isConfirmed: true,
        ),
        TransactionItem(
          id: 'tx_inc_2',
          note: 'Freelance Side Project',
          amount: 2000000,
          type: 'income',
          category: 'Freelance',
          occurredAt: DateTime(2026, 9, 18),
          isConfirmed: true,
        ),
        TransactionItem(
          id: 'tx_exp_1',
          note: 'Sewa Kosan',
          amount: 2500000,
          type: 'expense',
          category: 'Rumah',
          occurredAt: DateTime(2026, 9, 1),
          isConfirmed: true,
        ),
        TransactionItem(
          id: 'tx_exp_2',
          note: 'Makan & Minum',
          amount: 1500000,
          type: 'expense',
          category: 'Konsumsi',
          occurredAt: DateTime(2026, 9, 10),
          isConfirmed: false,
        ),
      ];

      surplusData = MonthlyRekapData(
        month: '2026-09',
        monthLabel: 'September 2026',
        totalIncome: 12000000,
        totalExpense: 4000000,
        netSavings: 8000000,
        savingsRate: 66.67,
        confirmedTransactionsCount: 3,
        pendingTransactionsCount: 1,
        lastMonthTotalExpense: 4500000,
        lastMonthTotalIncome: 10000000,
        expenseDiffPct: -11.1,
        incomeDiffPct: 20.0,
        categoryBreakdown: const [],
        transactions: transactions,
      );

      deficitData = MonthlyRekapData(
        month: '2026-09',
        monthLabel: 'September 2026',
        totalIncome: 3000000,
        totalExpense: 5000000,
        netSavings: -2000000,
        savingsRate: -66.67,
        confirmedTransactionsCount: 2,
        pendingTransactionsCount: 0,
        lastMonthTotalExpense: 4000000,
        lastMonthTotalIncome: 4500000,
        expenseDiffPct: 25.0,
        incomeDiffPct: -33.3,
        categoryBreakdown: const [],
        transactions: const [],
      );
    });

    testWidgets('renders net savings, surplus badge, income, and expense stats', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: IncomeExpenseSummaryCard(data: surplusData),
            ),
          ),
        ),
      );

      // Verify title & net savings
      expect(find.text('Tabungan Bersih (Net Savings)'), findsOneWidget);
      expect(find.byKey(const Key('net_savings_amount_text')), findsOneWidget);
      expect(find.text('+ Rp 8.000.000'), findsOneWidget);

      // Verify status badge
      expect(find.text('Surplus'), findsOneWidget);

      // Verify Pemasukan Card
      expect(find.text('Pemasukan'), findsOneWidget);
      expect(find.text('Rp 12.000.000'), findsOneWidget);
      expect(find.text('+20.0% vs lalu'), findsOneWidget);

      // Verify Pengeluaran Card
      expect(find.text('Pengeluaran'), findsOneWidget);
      expect(find.text('Rp 4.000.000'), findsOneWidget);
      expect(find.text('-11.1% vs lalu'), findsOneWidget);

      // Verify trx count
      expect(find.text('2 trx'), findsNWidgets(2));

      // Verify Savings rate bar & indicator
      expect(find.text('Rasio Tabungan: 66.7%'), findsOneWidget);
      expect(find.text('Kondisi Sehat 🎉'), findsOneWidget);
    });

    testWidgets('invokes onIncomeTap and onExpenseTap when cards are tapped', (WidgetTester tester) async {
      bool incomeTapped = false;
      bool expenseTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: IncomeExpenseSummaryCard(
                data: surplusData,
                onIncomeTap: () => incomeTapped = true,
                onExpenseTap: () => expenseTapped = true,
              ),
            ),
          ),
        ),
      );

      // Tap income card
      await tester.tap(find.byKey(const Key('income_summary_card_tap')));
      await tester.pump();
      expect(incomeTapped, isTrue);

      // Tap expense card
      await tester.tap(find.byKey(const Key('expense_summary_card_tap')));
      await tester.pump();
      expect(expenseTapped, isTrue);
    });

    testWidgets('expands and collapses detail analytics section', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: IncomeExpenseSummaryCard(data: surplusData),
            ),
          ),
        ),
      );

      // Initially collapsed
      expect(find.text('Lihat Rincian Analisa'), findsOneWidget);
      expect(find.text('Rata-rata Pengeluaran / Hari'), findsNothing);

      // Tap to expand
      await tester.tap(find.byKey(const Key('toggle_summary_details_button')));
      await tester.pumpAndSettle();

      expect(find.text('Sembunyikan Rincian'), findsOneWidget);
      expect(find.text('Rata-rata Pengeluaran / Hari'), findsOneWidget);
      expect(find.text('Porsi Pengeluaran vs Masuk'), findsOneWidget);
      expect(find.text('Pengeluaran Terbesar'), findsOneWidget);
      expect(find.text('Pemasukan Terbesar'), findsOneWidget);
      expect(find.text('Status Verifikasi'), findsOneWidget);

      // Tap to collapse
      await tester.tap(find.byKey(const Key('toggle_summary_details_button')));
      await tester.pumpAndSettle();

      expect(find.text('Lihat Rincian Analisa'), findsOneWidget);
      expect(find.text('Rata-rata Pengeluaran / Hari'), findsNothing);
    });

    testWidgets('renders deficit state correctly with warning badge', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: IncomeExpenseSummaryCard(data: deficitData),
            ),
          ),
        ),
      );

      expect(find.text('Defisit'), findsOneWidget);
      expect(find.text('- Rp 2.000.000'), findsOneWidget);
      expect(find.text('Perlu Evaluasi ⚠️'), findsOneWidget);
      expect(find.text('+25.0% vs lalu'), findsOneWidget);
      expect(find.text('-33.3% vs lalu'), findsOneWidget);
    });
  });
}
