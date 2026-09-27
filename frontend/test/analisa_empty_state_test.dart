import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/screens/analisa/analisa_keuangan_screen.dart';
import 'package:moneta/screens/analisa/widgets/analisa_empty_state_card.dart';
import 'package:moneta/state/app_state.dart';

void main() {
  setUp(() {
    AppState.instance.resetToDefault();
  });

  group('AnalisaEmptyStateCard Widget Tests', () {
    testWidgets('renders title, description, sample prompts, and CTA buttons',
        (WidgetTester tester) async {
      bool chatClicked = false;
      bool manualClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalisaEmptyStateCard(
                onStartChat: () {
                  chatClicked = true;
                },
                onManualInput: () {
                  manualClicked = true;
                },
              ),
            ),
          ),
        ),
      );

      // Verify card key & title
      expect(find.byKey(const Key('analisa_empty_state_card')), findsOneWidget);
      expect(
          find.text('Belum Ada Data Transaksi untuk Dianalisa'), findsOneWidget);
      expect(
          find.textContaining('AI memerlukan minimal 1 transaksi pengeluaran'),
          findsOneWidget);

      // Verify sample chips
      expect(find.text('☕ Kopi 25rb'), findsOneWidget);
      expect(find.text('🍛 Makan siang 30rb'), findsOneWidget);
      expect(find.text('🛒 Belanja minimarket 75rb'), findsOneWidget);

      // Verify buttons
      final chatBtn = find.byKey(const Key('btn_empty_start_chat'));
      expect(chatBtn, findsOneWidget);
      expect(find.text('Mulai Catat Lewat Chat'), findsOneWidget);

      final manualBtn = find.byKey(const Key('btn_empty_manual_input'));
      expect(manualBtn, findsOneWidget);
      expect(find.text('Input Transaksi Manual'), findsOneWidget);

      // Tap Chat CTA button
      await tester.tap(chatBtn);
      await tester.pumpAndSettle();
      expect(chatClicked, isTrue);

      // Tap Manual Input CTA button
      await tester.tap(manualBtn);
      await tester.pumpAndSettle();
      expect(manualClicked, isTrue);
    });
  });

  group('AnalisaKeuanganScreen Empty State Integration', () {
    testWidgets('renders empty state card when initialEmpty is true',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AnalisaKeuanganScreen(initialEmpty: true),
        ),
      );
      await tester.pumpAndSettle();

      // Empty state card is visible
      expect(find.byKey(const Key('analisa_empty_state_card')), findsOneWidget);
      expect(
          find.text('Belum Ada Data Transaksi untuk Dianalisa'), findsOneWidget);

      // Charts and metrics are hidden in empty state
      expect(find.byKey(const Key('avg_daily_spend_card')), findsNothing);
      expect(find.byKey(const Key('money_depletion_card')), findsNothing);

      // Toggle button in AppBar switches to populated state
      final toggleBtn = find.byTooltip('Tampilkan Data Analisa');
      expect(toggleBtn, findsOneWidget);
      await tester.tap(toggleBtn);
      await tester.pumpAndSettle();

      // Now populated state is visible
      expect(find.byKey(const Key('analisa_empty_state_card')), findsNothing);
      expect(find.byKey(const Key('financial_analysis_card')), findsOneWidget);
      expect(find.byKey(const Key('avg_daily_spend_card')), findsOneWidget);
      expect(find.byKey(const Key('money_depletion_card')), findsOneWidget);
    });
  });
}
