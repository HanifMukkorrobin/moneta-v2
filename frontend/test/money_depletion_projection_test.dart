import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/models/ai_insight_item.dart';
import 'package:moneta/screens/analisa/analisa_keuangan_screen.dart';
import 'package:moneta/screens/analisa/widgets/money_depletion_projection_card.dart';
import 'package:moneta/screens/chat/widgets/financial_analysis_card.dart';
import 'package:moneta/state/app_state.dart';

void main() {
  setUp(() {
    AppState.instance.resetToDefault();
  });

  group('Depletion Date Calculation & Status Tests', () {
    test('projectedDepletionDate adds estimatedDaysLeft correctly', () {
      final baseDate = DateTime(2026, 9, 27);
      final insight = AiInsightItem(
        id: 'test_1',
        date: baseDate,
        avgDailySpend: 50000,
        estimatedDaysLeft: 10,
        dailyAdvice: 'Test advice',
      );

      expect(insight.projectedDepletionDate, DateTime(2026, 10, 7));
      expect(insight.formattedDepletionDate, contains('Oktober 2026'));
      expect(insight.formattedShortDepletionDate, contains('Okt 2026'));
    });

    test('runsOutBeforeEndOfMonth detects early depletion', () {
      final baseDate = DateTime(2026, 9, 20); // 10 days until end of month (30 Sept)
      final earlyInsight = AiInsightItem(
        id: 'test_early',
        date: baseDate,
        avgDailySpend: 100000,
        estimatedDaysLeft: 5,
        dailyAdvice: 'Early warning',
      );

      expect(earlyInsight.runsOutBeforeEndOfMonth, isTrue);
      expect(earlyInsight.depletionStatusMessage,
          contains('Habis 5 hari sebelum akhir bulan'));

      final safeInsight = AiInsightItem(
        id: 'test_safe',
        date: baseDate,
        avgDailySpend: 40000,
        estimatedDaysLeft: 20,
        dailyAdvice: 'Safe advice',
      );

      expect(safeInsight.runsOutBeforeEndOfMonth, isFalse);
      expect(safeInsight.depletionStatusMessage,
          contains('Aman melampaui akhir bulan'));
    });
  });

  group('MoneyDepletionProjectionCard Widget Tests', () {
    testWidgets('renders days, date, and status banner properly',
        (WidgetTester tester) async {
      final insight = AiInsightItem.getDefaultInsight();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MoneyDepletionProjectionCard(insight: insight),
            ),
          ),
        ),
      );

      // Verify card and title
      expect(find.byKey(const Key('money_depletion_card')), findsOneWidget);
      expect(find.text('Perkiraan Uang Bertahan'), findsOneWidget);

      // Verify metrics
      expect(find.byKey(const Key('depletion_days_metric')), findsOneWidget);
      expect(find.byKey(const Key('depletion_days_value')), findsOneWidget);
      expect(find.textContaining('~18 Hari'), findsWidgets);

      expect(find.byKey(const Key('depletion_date_metric')), findsOneWidget);
      expect(find.byKey(const Key('depletion_date_value')), findsOneWidget);
      expect(find.text(insight.formattedShortDepletionDate), findsOneWidget);

      // Verify status banner
      expect(find.byKey(const Key('depletion_status_banner')), findsOneWidget);

      // Verify what-if simulator slider exists
      expect(find.byKey(const Key('simulated_spend_slider')), findsOneWidget);
    });

    testWidgets('what-if slider interaction updates days and date dynamically',
        (WidgetTester tester) async {
      final insight = AiInsightItem.getDefaultInsight();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MoneyDepletionProjectionCard(insight: insight),
            ),
          ),
        ),
      );

      // Initial days
      expect(find.text('~18 Hari'), findsWidgets);

      // Drag slider to higher spend (simulate spending more)
      final sliderFinder = find.byKey(const Key('simulated_spend_slider'));
      await tester.drag(sliderFinder, const Offset(150, 0));
      await tester.pumpAndSettle();

      // Number of days should update / decrease
      expect(find.text('~18 Hari'), findsNothing);
    });
  });

  group('Integration with AnalisaKeuanganScreen and FinancialAnalysisCard', () {
    testWidgets('AnalisaKeuanganScreen includes MoneyDepletionProjectionCard',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AnalisaKeuanganScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('money_depletion_card')), findsOneWidget);
      expect(find.byKey(const Key('avg_daily_spend_card')), findsOneWidget);
      expect(find.byKey(const Key('financial_analysis_card')), findsOneWidget);
    });

    testWidgets(
        'FinancialAnalysisCard displays depletion date in subtitle and modal',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final insight = AiInsightItem.getDefaultInsight();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FinancialAnalysisCard(
                insight: insight,
                initialExpanded: true,
              ),
            ),
          ),
        ),
      );

      // Verify subtitle in Metric 1 contains short depletion date
      expect(
        find.text('Habis: ${insight.formattedShortDepletionDate}'),
        findsOneWidget,
      );

      // Tap 'Lihat Detail'
      await tester.tap(
          find.byKey(const Key('financial_analysis_view_detail_button')));
      await tester.pumpAndSettle();

      // Verify Tanggal Proyeksi Habis row exists in detail modal
      expect(find.text('Tanggal Proyeksi Habis'), findsOneWidget);
      expect(find.text(insight.formattedDepletionDate), findsOneWidget);
    });
  });
}
