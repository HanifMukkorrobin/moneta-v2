import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/models/budget_item.dart';
import 'package:moneta/screens/budget/atur_budget_screen.dart';
import 'package:moneta/screens/budget/widgets/budget_warning_banner.dart';
import 'package:moneta/screens/budget/widgets/edit_budget_limit_sheet.dart';

void main() {
  group('BudgetWarningBanner Widget Tests', () {
    testWidgets('renders nothing when budget is safe and spending is below 80%', (WidgetTester tester) async {
      final safeSummary = MonthlyBudgetSummary.getMonthlyBudget(month: '2026-09');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BudgetWarningBanner(summary: safeSummary),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BudgetWarningBanner), findsOneWidget);
      expect(find.byKey(const Key('budget_near_limit_banner')), findsNothing);
      expect(find.byKey(const Key('budget_over_limit_banner')), findsNothing);
    });

    testWidgets('renders near limit warning banner when spending is >= 80%', (WidgetTester tester) async {
      final nearSummary = MonthlyBudgetSummary.getMonthlyBudget(month: '2026-08');
      bool adjustTapped = false;
      bool dismissTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BudgetWarningBanner(
              summary: nearSummary,
              onAdjustBudget: () => adjustTapped = true,
              onDismiss: () => dismissTapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Banner structure
      expect(find.byKey(const Key('budget_near_limit_banner')), findsOneWidget);
      expect(find.byKey(const Key('budget_over_limit_banner')), findsNothing);

      // Warning Title and Message
      expect(find.byKey(const Key('budget_warning_title')), findsOneWidget);
      expect(find.text('Peringatan: Budget Mendekati Batas!'), findsOneWidget);
      expect(find.byKey(const Key('budget_warning_message')), findsOneWidget);
      expect(find.textContaining('Pengeluaran telah mencapai 90.0% dari plafon Rp 6.000.000. Sisa batas: Rp 600.000.'), findsOneWidget);

      // Advice text
      expect(find.byKey(const Key('budget_warning_advice_text')), findsOneWidget);

      // Tap Ubah Budget
      await tester.tap(find.byKey(const Key('adjust_budget_from_banner_button')));
      expect(adjustTapped, isTrue);

      // Tap Dismiss button
      await tester.tap(find.byKey(const Key('dismiss_warning_banner_button')));
      expect(dismissTapped, isTrue);
    });

    testWidgets('renders over limit warning banner when budget is exceeded', (WidgetTester tester) async {
      final overSummary = MonthlyBudgetSummary.getMonthlyBudget(month: '2026-07');
      bool adjustTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BudgetWarningBanner(
              summary: overSummary,
              onAdjustBudget: () => adjustTapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Banner structure
      expect(find.byKey(const Key('budget_over_limit_banner')), findsOneWidget);
      expect(find.byKey(const Key('budget_near_limit_banner')), findsNothing);

      // Title & Message
      expect(find.byKey(const Key('budget_warning_title')), findsOneWidget);
      expect(find.text('Perhatian: Budget Melewati Batas!'), findsOneWidget);
      expect(find.byKey(const Key('budget_warning_message')), findsOneWidget);
      expect(find.textContaining('telah melewati plafon Rp 6.000.000 sebesar Rp 250.000.'), findsOneWidget);

      // Affected buckets chip
      expect(find.byKey(const Key('over_budget_buckets_chip')), findsOneWidget);
      expect(find.textContaining('Pos melebihi limit:'), findsOneWidget);

      // Tap adjust
      await tester.tap(find.byKey(const Key('adjust_budget_from_banner_button')));
      expect(adjustTapped, isTrue);
    });
  });

  group('AturBudgetScreen Integration with BudgetWarningBanner', () {
    testWidgets('dynamically shows warning banner when switching between safe and warned months', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      await tester.pumpWidget(
        const MaterialApp(
          home: AturBudgetScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // September 2026: safe (47.5% spent) -> no warning banner
      expect(find.byKey(const Key('budget_near_limit_banner')), findsNothing);
      expect(find.byKey(const Key('budget_over_limit_banner')), findsNothing);

      // Switch to Agustus 2026 (90% spent)
      final dropdownFinder = find.byKey(const Key('budget_month_dropdown'));
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      final agustusOption = find.text('Agustus 2026').last;
      await tester.tap(agustusOption);
      await tester.pumpAndSettle();

      // Near limit banner appears
      expect(find.byKey(const Key('budget_near_limit_banner')), findsOneWidget);
      expect(find.text('Peringatan: Budget Mendekati Batas!'), findsOneWidget);

      // Dismiss banner
      await tester.tap(find.byKey(const Key('dismiss_warning_banner_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('budget_near_limit_banner')), findsNothing);

      // Switch to Juli 2026 (over budget)
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      final juliOption = find.text('Juli 2026').last;
      await tester.tap(juliOption);
      await tester.pumpAndSettle();

      // Over limit banner appears
      expect(find.byKey(const Key('budget_over_limit_banner')), findsOneWidget);
      expect(find.text('Perhatian: Budget Melewati Batas!'), findsOneWidget);

      // Tapping Ubah Budget on the banner opens EditBudgetLimitSheet
      await tester.tap(find.byKey(const Key('adjust_budget_from_banner_button')));
      await tester.pumpAndSettle();

      expect(find.byType(EditBudgetLimitSheet), findsOneWidget);
      expect(find.text('Ubah Batas Budget Bulanan'), findsOneWidget);
    });
  });
}
