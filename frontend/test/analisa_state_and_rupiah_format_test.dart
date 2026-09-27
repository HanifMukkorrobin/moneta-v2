import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/models/ai_insight_item.dart';
import 'package:moneta/models/daily_spending_item.dart';
import 'package:moneta/models/transaction_item.dart';
import 'package:moneta/screens/analisa/analisa_keuangan_screen.dart';
import 'package:moneta/state/app_state.dart';
import 'package:moneta/utils/currency_format.dart';

void main() {
  group('CurrencyFormat Utility Tests', () {
    test('formatRupiah formats standard amounts correctly', () {
      expect(CurrencyFormat.formatRupiah(0), equals('Rp 0'));
      expect(CurrencyFormat.formatRupiah(500), equals('Rp 500'));
      expect(CurrencyFormat.formatRupiah(50000), equals('Rp 50.000'));
      expect(CurrencyFormat.formatRupiah(1250500), equals('Rp 1.250.500'));
      expect(CurrencyFormat.formatRupiah(10000000), equals('Rp 10.000.000'));
    });

    test('formatRupiah handles null, negative, and custom options', () {
      expect(CurrencyFormat.formatRupiah(null), equals('Rp 0'));
      expect(CurrencyFormat.formatRupiah(null, withSymbol: false), equals('0'));
      expect(CurrencyFormat.formatRupiah(-25000), equals('-Rp 25.000'));
      expect(CurrencyFormat.formatRupiah(-25000, withSymbol: false),
          equals('-25.000'));
      expect(CurrencyFormat.formatRupiah(50000, withSymbol: false),
          equals('50.000'));
      expect(CurrencyFormat.formatRupiah(15000, showSign: true),
          equals('+Rp 15.000'));
      expect(CurrencyFormat.formatRupiah(15000, showSign: true, withSymbol: false),
          equals('+15.000'));
    });

    test('formatCompactRupiah formats values into readable abbreviations', () {
      expect(CurrencyFormat.formatCompactRupiah(null), equals('Rp 0'));
      expect(CurrencyFormat.formatCompactRupiah(500), equals('Rp 500'));
      expect(CurrencyFormat.formatCompactRupiah(50000), equals('Rp 50rb'));
      expect(CurrencyFormat.formatCompactRupiah(1500000), equals('Rp 1.5jt'));
      expect(CurrencyFormat.formatCompactRupiah(2000000), equals('Rp 2jt'));
      expect(CurrencyFormat.formatCompactRupiah(2500000000), equals('Rp 2.5M'));
      expect(CurrencyFormat.formatCompactRupiah(-150000), equals('-Rp 150rb'));
      expect(CurrencyFormat.formatCompactRupiah(75000, withSymbol: false),
          equals('75rb'));
    });

    test('parseRupiah converts formatted strings to double accurately', () {
      expect(CurrencyFormat.parseRupiah(null), isNull);
      expect(CurrencyFormat.parseRupiah(''), isNull);
      expect(CurrencyFormat.parseRupiah('invalid text'), isNull);
      expect(CurrencyFormat.parseRupiah('Rp 50.000'), equals(50000.0));
      expect(CurrencyFormat.parseRupiah('Rp 1.250.500'), equals(1250500.0));
      expect(CurrencyFormat.parseRupiah('75.000'), equals(75000.0));
      expect(CurrencyFormat.parseRupiah('Rp 25.000,50'), equals(25000.5));
    });
  });

  group('AppState Analysis State Updating Tests', () {
    setUp(() {
      AppState.instance.resetToDefault();
    });

    test('initial state initializes with default insights and spending analysis',
        () {
      final state = AppState.instance;
      expect(state.aiInsight, isNotNull);
      expect(state.dailySpendingAnalysis, isNotNull);
      expect(state.aiInsight.formattedTotalMonthlyBudget, equals('Rp 6.000.000'));
      expect(state.dailySpendingAnalysis.topCategoryName, isNotEmpty);
    });

    test('recalculateAnalysis updates spending totals and warning level from transactions',
        () {
      final state = AppState.instance;

      // Add a manual high expense transaction
      final highExpense = TransactionItem(
        id: 'tx_test_large',
        note: 'Sewa Apartemen & Operasional',
        amount: 4500000,
        type: 'expense',
        category: 'Tagihan & Utilitas',
        occurredAt: DateTime.now(),
        isConfirmed: true,
      );

      state.addManualTransaction(highExpense);

      // Verify analysis recalculated
      expect(state.aiInsight.totalSpent, greaterThanOrEqualTo(4500000));
      expect(state.aiInsight.remainingBalance,
          lessThan(state.aiInsight.totalMonthlyBudget));
      expect(state.dailySpendingAnalysis.dailyPoints.isNotEmpty, isTrue);
    });

    test('updating transaction amount re-runs analysis calculation', () {
      final state = AppState.instance;
      state.recalculateAnalysis();
      final initialSpent = state.aiInsight.totalSpent;
      final tx = state.confirmedTransactions.first;

      state.updateTransaction(tx.copyWith(amount: tx.amount + 500000));

      expect(state.aiInsight.totalSpent, equals(initialSpent + 500000));
    });

    test('custom preset updates via setDailySpendingAnalysis and setAiInsight',
        () {
      final state = AppState.instance;
      final customInsight = state.aiInsight.copyWith(
        avgDailySpend: 150000,
        warnLevel: AiWarnLevel.critical,
      );

      state.setAiInsight(customInsight);
      expect(state.aiInsight.isCritical, isTrue);
      expect(state.aiInsight.formattedAvgDailySpend, equals('Rp 150.000'));

      final customAnalysis = DailySpendingAnalysis(
        avgDailySpend: 120000,
        targetDailySpend: 65000,
        weekOverWeekPercent: 12.5,
        highestSpendAmount: 200000,
        highestSpendDay: 'Sabtu',
        lowestSpendAmount: 50000,
        lowestSpendDay: 'Senin',
        topCategoryName: 'Hiburan',
        topCategoryPercentage: 60.0,
        dailyPoints: [],
      );

      state.setDailySpendingAnalysis(customAnalysis);
      expect(state.dailySpendingAnalysis.topCategoryName, equals('Hiburan'));
      expect(state.dailySpendingAnalysis.formattedHighestSpend, equals('Rp 200.000'));
    });
  });

  group('AnalisaKeuanganScreen State and Rupiah Format Integration Tests', () {
    setUp(() {
      AppState.instance.resetToDefault();
    });

    testWidgets(
        'renders formatted Rupiah values and triggers refresh action successfully',
        (WidgetTester tester) async {
      final state = AppState.instance;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnalisaKeuanganScreen(
              initialInsight: state.aiInsight,
              initialAnalysis: state.dailySpendingAnalysis,
              initialEmpty: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Screen title and AppBar icons
      expect(find.text('Analisa & Saran AI'), findsOneWidget);
      expect(find.byKey(const Key('action_refresh_analysis')), findsOneWidget);

      // Verify formatted Rupiah values appear on screen
      expect(find.textContaining('Rp '), findsWidgets);

      // Verify Rekomendasi Hemat AI section is present
      expect(find.text('Rekomendasi Hemat AI'), findsOneWidget);
      expect(find.textContaining('Saran AI:'), findsOneWidget);

      // Tap refresh action
      await tester.tap(find.byKey(const Key('action_refresh_analysis')));
      await tester.pumpAndSettle();

      // Verify snackbar feedback
      expect(find.byKey(const Key('analysis_refreshed_snackbar')), findsOneWidget);
      expect(find.text('Pembaruan state analisa berhasil.'), findsOneWidget);
    });

    testWidgets('simulation preset toggle updates Rupiah text and snackbar',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnalisaKeuanganScreen(
              initialEmpty: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find tune icon for simulation toggle
      final tuneIcon = find.byIcon(Icons.tune_rounded);
      expect(tuneIcon, findsOneWidget);

      await tester.tap(tuneIcon);
      await tester.pumpAndSettle();

      // Verify snackbar indicating simulation changed
      expect(find.textContaining('Data simulasi diganti: Rata-rata Rp '),
          findsOneWidget);
    });
  });
}
