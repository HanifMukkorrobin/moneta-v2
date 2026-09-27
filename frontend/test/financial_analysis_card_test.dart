import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/mock/ai_insight_mock_data.dart';
import 'package:moneta/models/ai_insight_item.dart';
import 'package:moneta/screens/chat/widgets/financial_analysis_card.dart';
import 'package:moneta/state/app_state.dart';

void main() {
  setUp(() {
    AppState.instance.resetToDefault();
  });

  group('AiInsightItem Model & Mock Tests', () {
    test('default insight has normal warn level and correct calculations', () {
      final insight = AiInsightMockData.getDefaultInsight();

      expect(insight.isNormal, isTrue);
      expect(insight.isWarning, isFalse);
      expect(insight.isCritical, isFalse);
      expect(insight.estimatedDaysLeft, 18);
      expect(insight.formattedAvgDailySpend, contains('78.500'));
      expect(insight.formattedRecommendedDailyBudget, contains('65.000'));
      expect(insight.warnLevel.label, 'Keuangan Aman');
      expect(insight.warnLevel.keyName, 'normal');
    });

    test('warning insight has warning warn level and expected fields', () {
      final warning = AiInsightMockData.getWarningInsight();

      expect(warning.isNormal, isFalse);
      expect(warning.isWarning, isTrue);
      expect(warning.isCritical, isFalse);
      expect(warning.warnLevel.label, 'Perlu Waspada');
      expect(warning.warnLevel.keyName, 'warning');
      expect(warning.estimatedDaysLeft, 9);
      expect(warning.formattedAvgDailySpend, contains('135.000'));
    });

    test('critical insight has critical warn level and expected fields', () {
      final critical = AiInsightMockData.getCriticalInsight();

      expect(critical.isNormal, isFalse);
      expect(critical.isWarning, isFalse);
      expect(critical.isCritical, isTrue);
      expect(critical.warnLevel.label, 'Kondisi Kritis');
      expect(critical.warnLevel.keyName, 'critical');
      expect(critical.estimatedDaysLeft, 3);
      expect(critical.formattedAvgDailySpend, contains('215.000'));
    });

    test('AiWarnLevel fromString maps correctly', () {
      expect(AiWarnLevel.fromString('critical'), AiWarnLevel.critical);
      expect(AiWarnLevel.fromString('kritis'), AiWarnLevel.critical);
      expect(AiWarnLevel.fromString('warning'), AiWarnLevel.warning);
      expect(AiWarnLevel.fromString('waspada'), AiWarnLevel.warning);
      expect(AiWarnLevel.fromString('normal'), AiWarnLevel.normal);
      expect(AiWarnLevel.fromString('aman'), AiWarnLevel.normal);
      expect(AiWarnLevel.fromString('other'), AiWarnLevel.normal);
    });
  });

  group('FinancialAnalysisCard Widget Tests', () {
    testWidgets('renders all components in expanded state by default',
        (WidgetTester tester) async {
      final insight = AiInsightMockData.getDefaultInsight();

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

      // Verify header and badge
      expect(find.byKey(const Key('financial_analysis_card')), findsOneWidget);
      expect(find.text('Analisa Keuangan AI'), findsOneWidget);
      expect(find.text('Keuangan Aman'), findsOneWidget);

      // Verify 3 metrics
      expect(find.byKey(const Key('metric_estimated_days')), findsOneWidget);
      expect(find.text('~18 Hari'), findsOneWidget);
      expect(find.byKey(const Key('metric_avg_daily_spend')), findsOneWidget);
      expect(find.text(insight.formattedAvgDailySpend), findsOneWidget);
      expect(find.byKey(const Key('metric_recommended_budget')), findsOneWidget);
      expect(find.text(insight.formattedRecommendedDailyBudget), findsOneWidget);

      // Verify AI daily advice box
      expect(find.byKey(const Key('financial_analysis_advice_box')),
          findsOneWidget);
      expect(find.text('Saran Belanja Hari Ini'), findsOneWidget);
      expect(find.text(insight.dailyAdvice), findsOneWidget);

      // Verify action strip
      expect(find.text('Lihat Detail'), findsOneWidget);
      expect(find.textContaining('9Router AI'), findsOneWidget);
    });

    testWidgets('toggles collapse and expand when header is tapped',
        (WidgetTester tester) async {
      final insight = AiInsightMockData.getDefaultInsight();

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

      // Initially expanded
      expect(find.byKey(const Key('metric_estimated_days')), findsOneWidget);

      // Tap header to collapse
      await tester.tap(find.byKey(const Key('financial_analysis_header_tap')));
      await tester.pumpAndSettle();

      // Expanded metrics should be hidden
      expect(find.byKey(const Key('metric_estimated_days')), findsNothing);

      // Collapsed preview should be visible
      expect(find.textContaining('Uang bertahan ~18 hari'), findsOneWidget);
      expect(find.textContaining('Saran:'), findsOneWidget);

      // Tap header again to expand
      await tester.tap(find.byKey(const Key('financial_analysis_header_tap')));
      await tester.pumpAndSettle();

      // Expanded metrics visible again
      expect(find.byKey(const Key('metric_estimated_days')), findsOneWidget);
    });

    testWidgets('renders warning state correctly', (WidgetTester tester) async {
      final warningInsight = AiInsightMockData.getWarningInsight();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FinancialAnalysisCard(
                insight: warningInsight,
                initialExpanded: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Perlu Waspada'), findsOneWidget);
      expect(find.text('~9 Hari'), findsOneWidget);
      expect(find.text(warningInsight.formattedAvgDailySpend), findsOneWidget);
      expect(find.text(warningInsight.dailyAdvice), findsOneWidget);
    });

    testWidgets('renders critical state correctly',
        (WidgetTester tester) async {
      final criticalInsight = AiInsightMockData.getCriticalInsight();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FinancialAnalysisCard(
                insight: criticalInsight,
                initialExpanded: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Kondisi Kritis'), findsOneWidget);
      expect(find.text('~3 Hari'), findsOneWidget);
      expect(find.text(criticalInsight.formattedAvgDailySpend), findsOneWidget);
      expect(find.text(criticalInsight.dailyAdvice), findsOneWidget);
    });

    testWidgets('opens detail modal and simulates scenario updates',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FinancialAnalysisCard(
                insight: AppState.instance.aiInsight,
                initialExpanded: true,
              ),
            ),
          ),
        ),
      );

      // Tap 'Lihat Detail' button
      await tester.tap(
          find.byKey(const Key('financial_analysis_view_detail_button')));
      await tester.pumpAndSettle();

      // Verify bottom sheet modal opened
      expect(find.text('Detail Analisa Keuangan AI'), findsOneWidget);
      expect(find.text('Ringkasan Finansial'), findsOneWidget);
      expect(find.text('Perkiraan Ketahanan Saldo'), findsOneWidget);

      // Tap scenario simulator 'Waspada'
      final warningBtn = find.byKey(const Key('btn_simulate_warning'));
      await tester.ensureVisible(warningBtn);
      await tester.tap(warningBtn);
      await tester.pumpAndSettle();

      // Verify AppState was updated to warning
      expect(AppState.instance.aiInsight.isWarning, isTrue);
    });
  });
}
