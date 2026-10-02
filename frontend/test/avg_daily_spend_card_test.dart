import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/models/daily_spending_item.dart';
import 'package:moneta/screens/analisa/analisa_keuangan_screen.dart';
import 'package:moneta/screens/analisa/widgets/avg_daily_spend_card.dart';
import 'package:moneta/state/app_state.dart';

void main() {
  setUp(() {
    AppState.instance.resetToDefault();
  });

  group('DailySpendingAnalysis Model & Mock Tests', () {
    test('default analysis returns correct metrics and values', () {
      final analysis = DailySpendingAnalysis.getDefaultDailyAnalysis();

      expect(analysis.avgDailySpend, 78500);
      expect(analysis.formattedAvgDailySpend, contains('78.500'));
      expect(analysis.formattedTargetDailySpend, contains('65.000'));
      expect(analysis.isAboveTarget, isTrue);
      expect(analysis.comparisonBadgeLabel, contains('+6.8% vs pekan lalu'));
      expect(analysis.highestSpendDay, 'Sabtu');
      expect(analysis.lowestSpendDay, 'Selasa');
      expect(analysis.dailyPoints.length, 7);
      expect(analysis.maxBarAmount, 145000);
    });

    test('high spending analysis returns correct metrics and values', () {
      final high = DailySpendingAnalysis.getHighSpendingAnalysis();

      expect(high.avgDailySpend, 139285);
      expect(high.isAboveTarget, isTrue);
      expect(high.comparisonBadgeLabel, contains('+34.5% vs pekan lalu'));
      expect(high.highestSpendDay, 'Sabtu');
      expect(high.dailyPoints.length, 7);
    });
  });

  group('AvgDailySpendCard Widget Tests', () {
    testWidgets('renders all average spending metrics, chart, and highlights',
        (WidgetTester tester) async {
      final analysis = DailySpendingAnalysis.getDefaultDailyAnalysis();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AvgDailySpendCard(analysis: analysis),
            ),
          ),
        ),
      );

      // Verify card key & title
      expect(find.byKey(const Key('avg_daily_spend_card')), findsOneWidget);
      expect(find.text('Rata-rata Pengeluaran Harian'), findsOneWidget);
      expect(find.text('Tren belanja 7 hari terakhir (Data Tiruan)'),
          findsOneWidget);

      // Verify comparison badge
      expect(find.byKey(const Key('avg_spend_comparison_badge')),
          findsOneWidget);
      expect(find.text(analysis.comparisonBadgeLabel), findsOneWidget);

      // Verify big nominal & target
      expect(find.byKey(const Key('avg_daily_spend_nominal')), findsOneWidget);
      expect(find.text(analysis.formattedAvgDailySpend), findsOneWidget);
      expect(find.text('Target: ${analysis.formattedTargetDailySpend}'),
          findsOneWidget);

      // Verify 7-day bar chart and day labels
      expect(
          find.byKey(const Key('daily_spending_bar_chart')), findsOneWidget);
      expect(find.text('Sen'), findsOneWidget);
      expect(find.text('Sel'), findsOneWidget);
      expect(find.text('Rab'), findsOneWidget);
      expect(find.text('Kam'), findsOneWidget);
      expect(find.text('Jum'), findsOneWidget);
      expect(find.text('Sab'), findsOneWidget);
      expect(find.text('Min'), findsOneWidget);

      // Verify highlights
      expect(find.text('Tertinggi'), findsOneWidget);
      expect(find.textContaining('Sabtu (Rp 145.000)'), findsOneWidget);
      expect(find.text('Terhemat'), findsOneWidget);
      expect(find.textContaining('Selasa (Rp 35.000)'), findsOneWidget);
      expect(find.text('Kontribusi Terbesar'), findsOneWidget);
      expect(find.textContaining('Makan & Minuman (48% dari total)'),
          findsOneWidget);
    });
  });

  group('AnalisaKeuanganScreen Widget Tests', () {
    testWidgets(
        'renders screen with FinancialAnalysisCard, AvgDailySpendCard, and AI tips',
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

      // Verify AppBar
      expect(find.text('Analisa & Saran AI'), findsOneWidget);

      // Verify body has scroll view
      expect(find.byKey(const Key('analisa_body_scroll_view')), findsOneWidget);

      // Verify both cards exist
      expect(find.byKey(const Key('financial_analysis_card')), findsOneWidget);
      expect(find.byKey(const Key('avg_daily_spend_card')), findsOneWidget);

      // Verify tips section
      expect(find.text('Rekomendasi Hemat AI'), findsOneWidget);

      // Tap tune button to toggle preset
      await tester.tap(find.byTooltip('Ganti Data Simulasi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify high spending analysis is now active
      expect(find.textContaining('139.285'), findsWidgets);

      // Tap reset button
      await tester.tap(find.byTooltip('Reset Analisa'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Returned to default
      expect(find.textContaining('78.500'), findsWidgets);
    });
  });
}
