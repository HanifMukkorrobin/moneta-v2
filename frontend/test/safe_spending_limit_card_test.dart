import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/mock/ai_insight_mock_data.dart';
import 'package:moneta/models/ai_insight_item.dart';
import 'package:moneta/screens/beranda/beranda_screen.dart';
import 'package:moneta/screens/beranda/widgets/safe_spending_limit_card.dart';
import 'package:moneta/state/app_state.dart';

void main() {
  setUp(() {
    AppState.instance.resetToDefault();
  });

  group('SafeSpendingLimitCard Widget Tests', () {
    testWidgets('renders safe spending limit card with normal safe state',
        (WidgetTester tester) async {
      final defaultInsight = AiInsightMockData.getDefaultInsight();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SafeSpendingLimitCard(
                insight: defaultInsight,
                todaySpent: 20000,
              ),
            ),
          ),
        ),
      );

      // Verify card key & title
      expect(find.byKey(const Key('safe_spending_limit_card')), findsOneWidget);
      expect(find.text('Batas Aman Belanja'), findsOneWidget);

      // Verify safe limit and remaining
      expect(find.byKey(const Key('safe_limit_amount_text')), findsOneWidget);
      expect(find.text('Rp 65.000'), findsOneWidget);

      expect(find.byKey(const Key('remaining_safe_limit_text')), findsOneWidget);
      expect(find.text('Rp 45.000'), findsOneWidget);

      // Verify normal safe badge
      expect(find.byKey(const Key('penanda_aman_badge')), findsOneWidget);
      expect(find.text('Batas Aman'), findsOneWidget);
      expect(find.byKey(const Key('penanda_rendah_badge')), findsNothing);

      // Verify progress bar
      expect(find.byKey(const Key('safe_limit_progress_bar')), findsOneWidget);
      final progressBar =
          tester.widget<LinearProgressIndicator>(find.byKey(const Key('safe_limit_progress_bar')));
      expect(progressBar.value, closeTo(20000 / 65000, 0.01));

      // Verify guidance message
      expect(find.byKey(const Key('safe_limit_guidance_box')), findsOneWidget);
      expect(find.textContaining('Batas aman belanja Anda dalam kondisi sehat'),
          findsOneWidget);
    });

    testWidgets('renders Penanda Rendah badge when daily limit is low (critical preset)',
        (WidgetTester tester) async {
      final criticalInsight = AiInsightMockData.getCriticalInsight();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SafeSpendingLimitCard(
                insight: criticalInsight,
                todaySpent: 5000,
              ),
            ),
          ),
        ),
      );

      // Verify Penanda Rendah badge appears
      expect(find.byKey(const Key('penanda_rendah_badge')), findsOneWidget);
      expect(find.text('Batas Rendah'), findsOneWidget);
      expect(find.byKey(const Key('penanda_aman_badge')), findsNothing);

      // Verify limit text is Rp 15.000
      expect(find.text('Rp 15.000'), findsOneWidget);

      // Verify guidance mentions low threshold
      expect(find.textContaining('Penanda Rendah: Batas belanja harian Anda minim'),
          findsOneWidget);
    });

    testWidgets('renders over-limit warning state when today spending exceeds safe limit',
        (WidgetTester tester) async {
      final defaultInsight = AiInsightMockData.getDefaultInsight();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SafeSpendingLimitCard(
                insight: defaultInsight,
                todaySpent: 85000, // Exceeds Rp 65.000 limit
              ),
            ),
          ),
        ),
      );

      // Verify over limit label
      expect(find.text('Melebihi Batas'), findsOneWidget);
      expect(find.byKey(const Key('penanda_rendah_badge')), findsOneWidget);

      // Remaining is clamped to Rp 0
      expect(find.text('Rp 0'), findsOneWidget);

      // Verify over-limit guidance warning
      expect(
          find.textContaining('Pengeluaran hari ini telah melampaui batas aman'),
          findsOneWidget);
    });
  });

  group('BerandaScreen Integration with SafeSpendingLimitCard', () {
    testWidgets('BerandaScreen displays SafeSpendingLimitCard and updates with presets',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: BerandaScreen(
            initialInsight: AiInsightMockData.getDefaultInsight().copyWith(
              recommendedDailyBudget: 150000,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify SafeSpendingLimitCard is rendered
      expect(find.byKey(const Key('safe_spending_limit_card')), findsOneWidget);
      expect(find.text('Batas Aman Belanja'), findsOneWidget);

      // With 150k limit and 75k spent, Penanda Aman is visible
      expect(find.byKey(const Key('penanda_aman_badge')), findsOneWidget);
      expect(find.text('Batas Aman'), findsOneWidget);

      // Tap preset toggle to switch to warning/critical
      final presetBtn = find.byKey(const Key('beranda_preset_toggle_button'));
      await tester.tap(presetBtn); // First toggle -> Warning
      await tester.pumpAndSettle();

      await tester.tap(presetBtn); // Second toggle -> Critical
      await tester.pumpAndSettle();

      // In critical state where spent exceeds safe limit, Penanda Rendah is rendered with Melebihi Batas
      expect(find.byKey(const Key('penanda_rendah_badge')), findsOneWidget);
      expect(find.text('Melebihi Batas'), findsOneWidget);
    });
  });
}
