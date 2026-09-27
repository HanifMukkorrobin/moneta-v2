import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/mock/ai_insight_mock_data.dart';
import 'package:moneta/models/ai_insight_item.dart';
import 'package:moneta/screens/beranda/beranda_screen.dart';
import 'package:moneta/screens/beranda/widgets/daily_advice_card.dart';
import 'package:moneta/screens/chat/chat_screen.dart';
import 'package:moneta/state/app_state.dart';

void main() {
  setUp(() {
    AppState.instance.resetToDefault();
  });

  group('DailyAdviceCard Widget Tests', () {
    testWidgets('renders daily advice card with normal level by default',
        (WidgetTester tester) async {
      final defaultInsight = AiInsightMockData.getDefaultInsight();
      bool tappedAnalysis = false;
      bool tappedApply = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailyAdviceCard(
                insight: defaultInsight,
                onDetailedAnalysis: () => tappedAnalysis = true,
                onApplyAdvice: () => tappedApply = true,
              ),
            ),
          ),
        ),
      );

      // Verify card key & header
      expect(find.byKey(const Key('daily_advice_card')), findsOneWidget);
      expect(find.text('Saran Belanja Hari Ini'), findsOneWidget);

      // Verify status chip
      expect(find.byKey(const Key('advice_status_chip')), findsOneWidget);
      expect(find.text('Keuangan Aman'), findsOneWidget);

      // Verify recommended daily budget
      expect(find.byKey(const Key('daily_budget_target_text')), findsOneWidget);
      expect(find.text('Rp 65.000'), findsOneWidget);

      // Verify advice message box and text
      expect(find.byKey(const Key('daily_advice_message_box')), findsOneWidget);
      expect(find.byKey(const Key('daily_advice_text')), findsOneWidget);
      expect(find.textContaining('Pertahankan ritme belanja Anda'), findsOneWidget);

      // Test action buttons
      final btnAnalysis = find.byKey(const Key('btn_view_full_analysis'));
      expect(btnAnalysis, findsOneWidget);
      await tester.tap(btnAnalysis);
      expect(tappedAnalysis, isTrue);

      final btnApply = find.byKey(const Key('btn_apply_advice'));
      expect(btnApply, findsOneWidget);
      await tester.tap(btnApply);
      expect(tappedApply, isTrue);
    });

    testWidgets('renders warning level advice card properly',
        (WidgetTester tester) async {
      final warningInsight = AiInsightMockData.getWarningInsight();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailyAdviceCard(
                insight: warningInsight,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Perlu Waspada'), findsOneWidget);
      expect(find.text('Rp 42.000'), findsOneWidget);
      expect(find.textContaining('Perhatian: Pengeluaran 3 hari terakhir'),
          findsOneWidget);
    });

    testWidgets('renders critical level advice card properly',
        (WidgetTester tester) async {
      final criticalInsight = AiInsightMockData.getCriticalInsight();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailyAdviceCard(
                insight: criticalInsight,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Kondisi Kritis'), findsOneWidget);
      expect(find.text('Rp 15.000'), findsOneWidget);
      expect(find.textContaining('Kritis: Sisa saldo menipis lebih cepat'),
          findsOneWidget);
    });
  });

  group('BerandaScreen Widget Tests', () {
    testWidgets(
        'renders BerandaScreen with greeting, advice card, stats, and quick actions',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: BerandaScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title & greeting
      expect(find.text('Beranda'), findsOneWidget);
      expect(find.text('Selamat Datang di Moneta ✨'), findsOneWidget);

      // Verify Daily Advice Card exists
      expect(find.byKey(const Key('daily_advice_card')), findsOneWidget);

      // Verify Financial summary section
      expect(find.text('Ringkasan Finansial'), findsOneWidget);
      expect(find.text('Sisa Saldo'), findsOneWidget);
      expect(find.text('Daya Tahan'), findsOneWidget);

      // Verify Quick Action buttons
      expect(find.text('Aksi Cepat'), findsOneWidget);
      expect(find.byKey(const Key('btn_quick_chat_input')), findsOneWidget);
      expect(find.byKey(const Key('btn_quick_manual_input')), findsOneWidget);
      expect(find.byKey(const Key('btn_quick_rekap')), findsOneWidget);
      expect(find.byKey(const Key('btn_quick_budget')), findsOneWidget);

      // Test preset cycle button
      final presetBtn = find.byKey(const Key('beranda_preset_toggle_button'));
      expect(presetBtn, findsOneWidget);

      await tester.tap(presetBtn);
      await tester.pumpAndSettle();

      // Verify snackbar feedback and updated status
      expect(find.textContaining('Simulasi Saran AI: Perlu Waspada'),
          findsOneWidget);

      // Test refresh button
      final refreshBtn = find.byKey(const Key('beranda_refresh_button'));
      expect(refreshBtn, findsOneWidget);

      await tester.tap(refreshBtn);
      await tester.pumpAndSettle();

      expect(find.text('Saran harian dan analisa berhasil diperbarui.'),
          findsOneWidget);
    });

    testWidgets('navigates from ChatScreen AppBar to BerandaScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: ChatScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Find Beranda button in Chat AppBar
      final berandaBtn = find.byKey(const Key('chat_appbar_beranda_button'));
      expect(berandaBtn, findsOneWidget);

      await tester.tap(berandaBtn);
      await tester.pumpAndSettle();

      // Verify navigated to BerandaScreen
      expect(find.byType(BerandaScreen), findsOneWidget);
      expect(find.text('Beranda'), findsOneWidget);
      expect(find.byKey(const Key('daily_advice_card')), findsOneWidget);
    });
  });
}
