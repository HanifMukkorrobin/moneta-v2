import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/models/saving_tip_item.dart';
import 'package:moneta/screens/beranda/beranda_screen.dart';
import 'package:moneta/screens/beranda/widgets/daily_saving_tips_card.dart';
import 'package:moneta/state/app_state.dart';

void main() {
  setUp(() {
    AppState.instance.resetToDefault();
  });

  group('DailySavingTipsCard Widget Tests', () {
    testWidgets('renders daily saving tips card with mock items and counter',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailySavingTipsCard(),
            ),
          ),
        ),
      );

      // Verify card key & title
      expect(find.byKey(const Key('daily_saving_tips_card')), findsOneWidget);
      expect(find.text('Tips Hemat Harian'), findsOneWidget);

      // Verify applied counter badge
      expect(find.byKey(const Key('tips_applied_counter_badge')), findsOneWidget);
      expect(find.text('0/5 Diterapkan'), findsOneWidget);

      // Verify default tips exist
      expect(find.text('Bawa Bekal Makan Siang 2x Sepekan'), findsOneWidget);
      expect(find.text('Aturan Tunda 24 Jam Belanja Online'), findsOneWidget);
      expect(find.textContaining('Hemat Rp 150.000'), findsOneWidget);

      // Verify total potential savings footer
      expect(find.byKey(const Key('total_potential_savings_text')), findsOneWidget);
      expect(find.textContaining('Potensi hemat kolektif: Rp 684.000'), findsOneWidget);
    });

    testWidgets('toggling tip application updates UI status and counter',
        (WidgetTester tester) async {
      SavingTipItem? toggledTip;
      bool? isAppliedStatus;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailySavingTipsCard(
                onToggleTip: (tip, applied) {
                  toggledTip = tip;
                  isAppliedStatus = applied;
                },
              ),
            ),
          ),
        ),
      );

      // Tap apply button on first tip
      final applyBtn = find.byKey(const Key('btn_apply_tip_tip_1'));
      expect(applyBtn, findsOneWidget);
      await tester.tap(applyBtn);
      await tester.pumpAndSettle();

      // Verify callback triggered
      expect(toggledTip, isNotNull);
      expect(toggledTip!.id, equals('tip_1'));
      expect(isAppliedStatus, isTrue);

      // Verify counter updated to 1/5
      expect(find.text('1/5 Diterapkan'), findsOneWidget);
      expect(find.text('Sudah Diterapkan'), findsOneWidget);

      // Verify SnackBar appeared
      expect(find.textContaining('Tip diterapkan: "Bawa Bekal Makan Siang 2x Sepekan"'),
          findsOneWidget);
    });

    testWidgets('category filter chips filter tips dynamically',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailySavingTipsCard(),
            ),
          ),
        ),
      );

      // Tap 'Belanja' category chip
      final belanjaChip = find.text('Belanja');
      expect(belanjaChip, findsOneWidget);
      await tester.tap(belanjaChip);
      await tester.pumpAndSettle();

      // Belanja tip should be visible
      expect(find.text('Aturan Tunda 24 Jam Belanja Online'), findsOneWidget);

      // Makan & Minuman tip should be filtered out
      expect(find.text('Bawa Bekal Makan Siang 2x Sepekan'), findsNothing);

      // Switch back to 'Semua'
      final semuaChip = find.text('Semua');
      await tester.tap(semuaChip);
      await tester.pumpAndSettle();

      // Both should be visible again
      expect(find.text('Bawa Bekal Makan Siang 2x Sepekan'), findsOneWidget);
      expect(find.text('Aturan Tunda 24 Jam Belanja Online'), findsOneWidget);
    });
  });

  group('BerandaScreen Integration with DailySavingTipsCard', () {
    testWidgets('BerandaScreen includes DailySavingTipsCard in feed',
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

      // Verify DailySavingTipsCard is present in BerandaScreen
      expect(find.byKey(const Key('daily_saving_tips_card')), findsOneWidget);
      expect(find.text('Tips Hemat Harian'), findsOneWidget);
    });
  });
}
