import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/screens/budget/atur_budget_screen.dart';
import 'package:moneta/screens/budget/widgets/budget_allocation_buckets_section.dart';
import 'package:moneta/screens/budget/widgets/budget_header_summary_card.dart';
import 'package:moneta/screens/budget/widgets/category_budget_list_section.dart';
import 'package:moneta/screens/main_navigation_screen.dart';

void main() {
  group('AturBudgetScreen (Halaman Utama Atur Budget dengan Data Tiruan)', () {
    testWidgets('renders AppBar, month bar, and core budget sections', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AturBudgetScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify AppBar
      expect(find.text('Atur Budget'), findsOneWidget);

      // Verify month selector
      expect(find.byKey(const Key('current_budget_month_label')), findsOneWidget);
      expect(find.text('September 2026'), findsWidgets);

      // Verify Core Sections
      expect(find.byType(BudgetHeaderSummaryCard), findsOneWidget);
      expect(find.byType(BudgetAllocationBucketsSection), findsOneWidget);
      expect(find.byType(CategoryBudgetListSection), findsOneWidget);
    });

    testWidgets('displays total budget, spent, and remaining in header summary card', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AturBudgetScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total Anggaran Bulanan'), findsOneWidget);
      expect(find.text('Plafon Budget'), findsOneWidget);
      expect(find.byKey(const Key('total_budget_limit_text')), findsOneWidget);
      expect(find.text('Rp 6.000.000'), findsOneWidget);

      expect(find.byKey(const Key('total_budget_spent_text')), findsOneWidget);
      expect(find.byKey(const Key('total_budget_remaining_text')), findsOneWidget);
      expect(find.byKey(const Key('budget_total_progress_bar')), findsOneWidget);
      expect(find.byKey(const Key('budget_status_badge')), findsOneWidget);
    });

    testWidgets('displays 50/30/20 allocation buckets with correct percentages', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AturBudgetScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alokasi Kantong (50/30/20)'), findsOneWidget);
      expect(find.text('Kebutuhan Pokok'), findsOneWidget);
      expect(find.text('50% dari Total Budget'), findsOneWidget);

      expect(find.text('Tabungan & Investasi'), findsOneWidget);
      expect(find.text('30% dari Total Budget'), findsOneWidget);

      expect(find.text('Hiburan & Keinginan'), findsOneWidget);
      expect(find.text('20% dari Total Budget'), findsOneWidget);
    });

    testWidgets('displays category budget list with individual limits', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AturBudgetScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Budget per Kategori'), findsOneWidget);
      expect(find.text('Sewa Kos & Tagihan Rumah'), findsOneWidget);
      expect(find.text('Makan & Minuman'), findsOneWidget);
      expect(find.text('Reksadana & Tabungan Darurat'), findsOneWidget);

      // Verify category item tap shows snackbar
      final itemFinder = find.text('Makan & Minuman');
      await tester.ensureVisible(itemFinder);
      await tester.tap(itemFinder);
      await tester.pumpAndSettle();
      expect(find.textContaining('Makan & Minuman: Sisa'), findsOneWidget);
    });

    testWidgets('renders empty state when budget is zero', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AturBudgetScreen(initialMonth: 'empty_month'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('budget_empty_banner')), findsOneWidget);
      expect(find.text('Belum Ada Budget Bulanan'), findsOneWidget);
      expect(find.byKey(const Key('create_budget_empty_button')), findsOneWidget);

      // Tap Create Budget button populates mock budget
      await tester.tap(find.byKey(const Key('create_budget_empty_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('budget_empty_banner')), findsNothing);
      expect(find.byType(BudgetHeaderSummaryCard), findsOneWidget);
    });

    testWidgets('navigates to AturBudgetScreen from MainNavigationScreen tab', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MainNavigationScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Budget tab (index 2)
      await tester.tap(find.text('Budget'));
      await tester.pumpAndSettle();

      expect(find.byType(AturBudgetScreen), findsOneWidget);
      expect(find.text('Atur Budget'), findsOneWidget);
      expect(find.text('Alokasi Kantong (50/30/20)'), findsOneWidget);
    });
  });
}
