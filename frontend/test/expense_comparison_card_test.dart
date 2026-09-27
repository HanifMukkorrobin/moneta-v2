import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/models/monthly_rekap_data.dart';
import 'package:moneta/screens/rekap/widgets/expense_comparison_card.dart';

void main() {
  group('ExpenseComparisonCard (Kartu Perbandingan Pengeluaran dengan Bulan Lalu)', () {
    testWidgets('renders lower expense comparison state (hemat / berkurang)', (WidgetTester tester) async {
      final data = MonthlyRekapData(
        month: '2026-09',
        monthLabel: 'September 2026',
        totalIncome: 10000000,
        totalExpense: 4700000,
        netSavings: 5300000,
        savingsRate: 53.0,
        confirmedTransactionsCount: 5,
        pendingTransactionsCount: 0,
        lastMonthTotalExpense: 6250000,
        lastMonthTotalIncome: 9500000,
        expenseDiffPct: -24.8,
        incomeDiffPct: 5.3,
        categoryBreakdown: const [],
        transactions: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseComparisonCard(data: data),
          ),
        ),
      );

      expect(find.byKey(const Key('rekap_comparison_card')), findsOneWidget);
      expect(find.text('Perbandingan Bulan Lalu'), findsOneWidget);
      expect(find.text('Hemat 24.8%'), findsOneWidget);
      expect(find.text('Rp 6.250.000'), findsOneWidget);
      expect(find.text('Rp 4.700.000'), findsOneWidget);
      expect(
        find.text('Pengeluaran bulan ini lebih hemat Rp 1.550.000 dibandingkan bulan lalu.'),
        findsOneWidget,
      );
    });

    testWidgets('renders higher expense comparison state (naik / meningkat)', (WidgetTester tester) async {
      final data = MonthlyRekapData(
        month: '2026-09',
        monthLabel: 'September 2026',
        totalIncome: 8000000,
        totalExpense: 6000000,
        netSavings: 2000000,
        savingsRate: 25.0,
        confirmedTransactionsCount: 5,
        pendingTransactionsCount: 0,
        lastMonthTotalExpense: 4500000,
        lastMonthTotalIncome: 8000000,
        expenseDiffPct: 33.3,
        incomeDiffPct: 0.0,
        categoryBreakdown: const [],
        transactions: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseComparisonCard(data: data),
          ),
        ),
      );

      expect(find.byKey(const Key('rekap_comparison_card')), findsOneWidget);
      expect(find.text('Naik 33.3%'), findsOneWidget);
      expect(find.text('Rp 4.500.000'), findsOneWidget);
      expect(find.text('Rp 6.000.000'), findsOneWidget);
      expect(
        find.text('Pengeluaran bulan ini meningkat Rp 1.500.000 dibandingkan bulan lalu.'),
        findsOneWidget,
      );
    });

    testWidgets('renders nothing when previous month expense is 0', (WidgetTester tester) async {
      final data = MonthlyRekapData(
        month: '2026-09',
        monthLabel: 'September 2026',
        totalIncome: 8000000,
        totalExpense: 6000000,
        netSavings: 2000000,
        savingsRate: 25.0,
        confirmedTransactionsCount: 5,
        pendingTransactionsCount: 0,
        lastMonthTotalExpense: 0,
        lastMonthTotalIncome: 0,
        expenseDiffPct: 0.0,
        incomeDiffPct: 0.0,
        categoryBreakdown: const [],
        transactions: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseComparisonCard(data: data),
          ),
        ),
      );

      expect(find.byKey(const Key('rekap_comparison_card')), findsNothing);
    });
  });
}
