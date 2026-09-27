import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/mock/ai_insight_mock_data.dart';
import 'package:moneta/models/ai_insight_item.dart';
import 'package:moneta/screens/analisa/analisa_keuangan_screen.dart';
import 'package:moneta/screens/analisa/widgets/early_warning_indicator_card.dart';
import 'package:moneta/state/app_state.dart';

void main() {
  setUp(() {
    AppState.instance.resetToDefault();
  });

  group('EarlyWarningIndicatorCard Widget Tests', () {
    testWidgets('renders all 3 levels with normal active by default',
        (WidgetTester tester) async {
      final insight = AiInsightMockData.getDefaultInsight();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EarlyWarningIndicatorCard(insight: insight),
            ),
          ),
        ),
      );

      // Verify card key & title
      expect(
          find.byKey(const Key('early_warning_indicator_card')), findsOneWidget);
      expect(find.text('Peringatan Dini Finansial'), findsOneWidget);

      // Verify active badge
      expect(find.byKey(const Key('active_warning_badge')), findsOneWidget);
      expect(find.text('Keuangan Aman'), findsOneWidget);

      // Verify all 3 level segments
      expect(find.byKey(const Key('segment_normal')), findsOneWidget);
      expect(find.text('1. Aman'), findsOneWidget);

      expect(find.byKey(const Key('segment_warning')), findsOneWidget);
      expect(find.text('2. Waspada'), findsOneWidget);

      expect(find.byKey(const Key('segment_critical')), findsOneWidget);
      expect(find.text('3. Kritis'), findsOneWidget);

      // Verify diagnostics box for normal level
      expect(find.byKey(const Key('warning_diagnostics_box')), findsOneWidget);
      expect(find.text('Tingkat 1: Finansial Terkendali'), findsOneWidget);
      expect(find.textContaining('Rasio pengeluaran harian berada di bawah'),
          findsOneWidget);
    });

    testWidgets('renders warning level diagnostics when passed warning insight',
        (WidgetTester tester) async {
      final warningInsight = AiInsightMockData.getWarningInsight();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EarlyWarningIndicatorCard(insight: warningInsight),
            ),
          ),
        ),
      );

      expect(find.text('Perlu Waspada'), findsOneWidget);
      expect(find.text('Tingkat 2: Peringatan Belanja Meningkat'), findsOneWidget);
      expect(find.textContaining('Terdeteksi lonjakan belanja'), findsOneWidget);
    });

    testWidgets('renders critical level diagnostics when passed critical insight',
        (WidgetTester tester) async {
      final criticalInsight = AiInsightMockData.getCriticalInsight();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EarlyWarningIndicatorCard(insight: criticalInsight),
            ),
          ),
        ),
      );

      expect(find.text('Kondisi Kritis'), findsOneWidget);
      expect(find.text('Tingkat 3: Kondisi Kritis / Darurat'), findsOneWidget);
      expect(find.textContaining('Sisa saldo menipis drastis'), findsOneWidget);
    });

    testWidgets('tapping segments switches level and triggers callback',
        (WidgetTester tester) async {
      AiWarnLevel? changedLevel;
      final insight = AiInsightMockData.getDefaultInsight();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EarlyWarningIndicatorCard(
                insight: insight,
                onLevelChanged: (lvl) {
                  changedLevel = lvl;
                },
              ),
            ),
          ),
        ),
      );

      // Tap segment 2 (Waspada)
      await tester.tap(find.byKey(const Key('segment_warning')));
      await tester.pumpAndSettle();
      expect(changedLevel, AiWarnLevel.warning);

      // Tap segment 3 (Kritis)
      await tester.tap(find.byKey(const Key('segment_critical')));
      await tester.pumpAndSettle();
      expect(changedLevel, AiWarnLevel.critical);

      // Tap segment 1 (Aman)
      await tester.tap(find.byKey(const Key('segment_normal')));
      await tester.pumpAndSettle();
      expect(changedLevel, AiWarnLevel.normal);
    });
  });

  group('Integration in AnalisaKeuanganScreen', () {
    testWidgets('AnalisaKeuanganScreen includes EarlyWarningIndicatorCard',
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

      expect(find.byKey(const Key('early_warning_indicator_card')), findsOneWidget);

      // Tap segment Waspada to update AppState
      await tester.tap(find.byKey(const Key('segment_warning')));
      await tester.pumpAndSettle();

      expect(AppState.instance.aiInsight.warnLevel, AiWarnLevel.warning);
    });
  });
}
