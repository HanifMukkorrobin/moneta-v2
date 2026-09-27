import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/mock/budget_mock_data.dart';
import 'package:moneta/models/budget_item.dart';
import 'package:moneta/screens/budget/atur_budget_screen.dart';
import 'package:moneta/screens/budget/widgets/sisa_batas_bulan_berjalan_card.dart';

void main() {
  group('MonthlyBudgetSummary - Sisa Batas Bulan Berjalan Unit Tests', () {
    test('calculates remaining budget and formats in Rupiah accurately', () {
      final summary = BudgetMockData.getMonthlyBudget(month: '2026-09');

      // Total 6.000.000, Spent 2.850.000 -> Remaining 3.150.000
      expect(summary.totalBudget, 6000000.0);
      expect(summary.totalSpent, 2850000.0);
      expect(summary.totalRemaining, 3150000.0);
      expect(summary.formattedTotalRemaining, 'Rp 3.150.000');
      expect(summary.formattedRemainingWithSign, 'Rp 3.150.000');
      expect(summary.remainingPercentage, closeTo(52.5, 0.1));
      expect(summary.isOverBudget, isFalse);
      expect(summary.remainingStatusLabel, 'Batas Aman');
    });

    test('calculates days in month and daily remaining average spend in Rupiah', () {
      final summary = BudgetMockData.getMonthlyBudget(month: '2026-09');

      // September has 30 days
      expect(summary.daysInMonth, 30);
      // 3.150.000 / 30 = 105.000
      expect(summary.dailyRemainingAverage, 105000.0);
      expect(summary.formattedDailyRemainingAverage, 'Rp 105.000 / hari');
    });

    test('handles August with 31 days correctly', () {
      final summary = BudgetMockData.getMonthlyBudget(month: '2026-08');

      // August has 31 days
      expect(summary.daysInMonth, 31);
      expect(summary.totalBudget, 6000000.0);
      expect(summary.totalSpent, 5400000.0);
      expect(summary.totalRemaining, 600000.0);
      expect(summary.formattedTotalRemaining, 'Rp 600.000');
      // 600.000 / 31 = ~19.354,83 -> Rp 19.355 / hari
      expect(summary.dailyRemainingAverage, closeTo(19354.8, 1.0));
      expect(summary.formattedDailyRemainingAverage, contains('Rp '));
      expect(summary.formattedDailyRemainingAverage, contains('/ hari'));
      expect(summary.remainingPercentage, closeTo(10.0, 0.1));
      expect(summary.remainingStatusLabel, 'Batas Menipis');
    });

    test('handles over-budget state with negative sign and proper label', () {
      const overSummary = MonthlyBudgetSummary(
        month: '2026-09',
        monthLabel: 'September 2026',
        totalBudget: 4000000.0,
        totalSpent: 4500000.0,
        needsPercentage: 50,
        savingsPercentage: 30,
        funPercentage: 20,
        buckets: [],
        categoryBudgets: [],
      );

      expect(overSummary.totalRemaining, -500000.0);
      expect(overSummary.isOverBudget, isTrue);
      expect(overSummary.formattedTotalRemaining, 'Rp 500.000');
      expect(overSummary.formattedRemainingWithSign, '- Rp 500.000');
      expect(overSummary.remainingStatusLabel, 'Batas Terlampaui');
      expect(overSummary.dailyRemainingAverage, 0.0);
      expect(overSummary.formattedDailyRemainingAverage, 'Rp 0 / hari');
    });
  });

  group('SisaBatasBulanBerjalanCard Widget Tests', () {
    testWidgets('renders SisaBatasBulanBerjalanCard with normal safe budget in Rupiah', (WidgetTester tester) async {
      final summary = BudgetMockData.getMonthlyBudget(month: '2026-09');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SisaBatasBulanBerjalanCard(summary: summary),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Card structure
      expect(find.byKey(const Key('sisa_batas_bulan_berjalan_card')), findsOneWidget);
      expect(find.byKey(const Key('sisa_batas_bulan_berjalan_label')), findsOneWidget);
      expect(find.text('Sisa Batas Bulan Berjalan'), findsOneWidget);
      expect(find.text('September 2026'), findsOneWidget);

      // Status badge
      expect(find.byKey(const Key('sisa_batas_status_badge')), findsOneWidget);
      expect(find.text('Batas Aman'), findsOneWidget);

      // Hero Amount in Rupiah
      expect(find.byKey(const Key('sisa_batas_bulan_berjalan_amount')), findsOneWidget);
      expect(find.text('Rp 3.150.000'), findsOneWidget);

      // Progress bar and context percentage
      expect(find.byKey(const Key('sisa_batas_progress_bar')), findsOneWidget);
      expect(find.byKey(const Key('sisa_batas_persentase_text')), findsOneWidget);
      expect(find.textContaining('Tersisa 52.5% dari total plafon Rp 6.000.000'), findsOneWidget);

      // Daily average recommendation
      expect(find.byKey(const Key('sisa_batas_harian_info')), findsOneWidget);
      expect(find.byKey(const Key('sisa_batas_keterangan_text')), findsOneWidget);
      expect(find.textContaining('Estimasi aman belanja: Rp 105.000 / hari (tersisa 30 hari)'), findsOneWidget);
    });

    testWidgets('renders warning state when budget remaining is low', (WidgetTester tester) async {
      final summary = BudgetMockData.getMonthlyBudget(month: '2026-08');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SisaBatasBulanBerjalanCard(summary: summary),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Batas Menipis'), findsOneWidget);
      expect(find.text('Rp 600.000'), findsOneWidget);
      expect(find.textContaining('Tersisa 10.0% dari total plafon Rp 6.000.000'), findsOneWidget);
    });

    testWidgets('renders over-budget state with negative sign and warning banner', (WidgetTester tester) async {
      const overSummary = MonthlyBudgetSummary(
        month: '2026-09',
        monthLabel: 'September 2026',
        totalBudget: 5000000.0,
        totalSpent: 5500000.0,
        needsPercentage: 50,
        savingsPercentage: 30,
        funPercentage: 20,
        buckets: [],
        categoryBudgets: [],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SisaBatasBulanBerjalanCard(summary: overSummary),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Batas Terlampaui'), findsOneWidget);
      expect(find.text('- Rp 500.000'), findsOneWidget);
      expect(find.textContaining('Pengeluaran Rp 5.500.000 telah melebihi plafon Rp 5.000.000'), findsOneWidget);
      expect(find.textContaining('Batas terlampaui sebesar Rp 500.000.'), findsOneWidget);
    });
  });

  group('AturBudgetScreen Integration - Sisa Batas Bulan Berjalan', () {
    testWidgets('displays Sisa Batas Bulan Berjalan inside AturBudgetScreen and updates on month switch', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AturBudgetScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Card is displayed in AturBudgetScreen
      expect(find.byKey(const Key('sisa_batas_bulan_berjalan_card')), findsOneWidget);
      expect(find.text('Sisa Batas Bulan Berjalan'), findsWidgets);
      expect(find.byKey(const Key('sisa_batas_bulan_berjalan_amount')), findsOneWidget);
      expect(find.text('Rp 3.150.000'), findsNWidgets(2));
      expect(find.text('Batas Aman'), findsOneWidget);

      // Select Agustus 2026 from month dropdown
      final dropdownFinder = find.byKey(const Key('budget_month_dropdown'));
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      final agustusOption = find.text('Agustus 2026').last;
      await tester.tap(agustusOption);
      await tester.pumpAndSettle();

      // Verify that Sisa Batas Bulan Berjalan updated to Agustus 2026 values
      expect(find.text('Agustus 2026'), findsWidgets);
      expect(find.byKey(const Key('sisa_batas_bulan_berjalan_amount')), findsOneWidget);
      expect(find.text('Rp 600.000'), findsNWidgets(2));
      expect(find.text('Batas Menipis'), findsOneWidget);
    });
  });
}
