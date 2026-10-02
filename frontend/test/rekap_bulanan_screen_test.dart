import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/screens/main_navigation_screen.dart';
import 'package:moneta/screens/rekap/rekap_bulanan_screen.dart';
import 'package:moneta/screens/rekap/widgets/category_breakdown_section.dart';
import 'package:moneta/screens/rekap/widgets/monthly_transaction_list_section.dart';
import 'package:moneta/screens/rekap/widgets/rekap_comparison_card.dart';
import 'package:moneta/screens/rekap/widgets/rekap_summary_card.dart';
import 'package:moneta/state/app_state.dart';

void main() {
  setUp(() {
    AppState.instance.resetToDefault();
  });

  Widget buildTestWidget({Widget? child}) {
    return MaterialApp(
      home: child ?? const RekapBulananScreen(),
    );
  }

  group('RekapBulananScreen Unit & Widget Tests', () {
    testWidgets('renders AppBar, Month Navigator, and essential widgets', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Verify AppBar
      expect(find.text('Rekap Bulanan'), findsOneWidget);

      // Verify Month Navigator displays September 2026 initially
      expect(find.text('September 2026'), findsWidgets);

      // Verify Core Sections
      expect(find.byType(RekapSummaryCard), findsOneWidget);
      expect(find.byType(RekapComparisonCard), findsOneWidget);
      expect(find.byType(CategoryBreakdownSection), findsOneWidget);
      expect(find.byType(MonthlyTransactionListSection), findsOneWidget);
    });

    testWidgets('displays accurate Net Savings, Income, Expense and Surplus status in RekapSummaryCard', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Tabungan Bersih (Net Savings)'), findsOneWidget);
      expect(find.text('Pemasukan'), findsWidgets);
      expect(find.text('Pengeluaran'), findsWidgets);
      expect(find.text('Surplus'), findsOneWidget);
      expect(find.textContaining('Rasio Tabungan'), findsOneWidget);
    });

    testWidgets('navigates through months with chevron buttons and quick chips', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Current is September 2026
      expect(find.text('September 2026'), findsWidgets);

      // Tap Chevron Left (Previous Month -> Agustus 2026)
      final prevBtn = find.byTooltip('Bulan Sebelumnya');
      expect(prevBtn, findsOneWidget);
      await tester.tap(prevBtn);
      await tester.pumpAndSettle();

      // Should now show Agustus 2026
      expect(find.text('Agustus 2026'), findsWidgets);

      // Tap Choice Chip 'Juli 2026'
      final juliChip = find.widgetWithText(ChoiceChip, 'Juli 2026');
      expect(juliChip, findsOneWidget);
      await tester.tap(juliChip);
      await tester.pumpAndSettle();

      expect(find.text('Juli 2026'), findsWidgets);

      // Tap Chevron Right (Next Month -> Agustus 2026)
      final nextBtn = find.byTooltip('Bulan Berikutnya');
      expect(nextBtn, findsOneWidget);
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();

      expect(find.text('Agustus 2026'), findsWidgets);
    });

    testWidgets('displays month-over-month comparison card with trend info', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Check comparison info
      expect(find.byType(RekapComparisonCard), findsOneWidget);
      expect(find.textContaining('dibandingkan bulan lalu'), findsOneWidget);
    });

    testWidgets('switches category breakdown between Pengeluaran and Pemasukan', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Initial tab is Pengeluaran
      expect(find.text('Grafik per Kategori'), findsOneWidget);
      expect(find.text('Makan & Minuman'), findsWidgets);

      // Switch to Pemasukan
      final pemasukanBtn = find.widgetWithText(InkWell, 'Pemasukan');
      expect(pemasukanBtn, findsWidgets);
      await tester.tap(pemasukanBtn.first);
      await tester.pumpAndSettle();

      // Should show income categories like Gaji and Freelance
      expect(find.text('Gaji'), findsWidgets);
      expect(find.text('Freelance'), findsWidgets);
    });

    testWidgets('filters transaction list by category selection in CategoryBreakdownSection', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap category 'Kebutuhan Rumah' in breakdown list
      final categoryTile = find.widgetWithText(InkWell, 'Kebutuhan Rumah').first;
      await tester.ensureVisible(categoryTile);
      await tester.tap(categoryTile);
      await tester.pumpAndSettle();

      // Active category filter chip should appear
      expect(find.textContaining('Kategori: Kebutuhan Rumah'), findsOneWidget);

      // Transactions list should be filtered to only Kebutuhan Rumah
      expect(find.text('Sewa Kamar Kos Bulanan'), findsOneWidget);
      expect(find.text('Makan Malam Sushi Tei bareng Teman'), findsNothing);

      // Clear filter chip
      final deleteIcon = find.byIcon(Icons.close_rounded);
      expect(deleteIcon, findsOneWidget);
      await tester.ensureVisible(deleteIcon);
      await tester.tap(deleteIcon);
      await tester.pumpAndSettle();

      // Full list restored
      final restoredItem = find.text('Makan Malam Sushi Tei bareng Teman');
      await tester.ensureVisible(restoredItem);
      expect(restoredItem, findsOneWidget);
    });

    testWidgets('searches transactions dynamically via search textfield', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final searchField = find.widgetWithText(TextField, 'Cari transaksi atau kategori...');
      expect(searchField, findsOneWidget);
      await tester.ensureVisible(searchField);

      // Type search query 'Sushi'
      await tester.enterText(searchField, 'Sushi');
      await tester.pumpAndSettle();

      // Only Sushi should be visible
      expect(find.text('Makan Malam Sushi Tei bareng Teman'), findsOneWidget);
      expect(find.text('Gaji Bulanan PT Teknologi Maju'), findsNothing);

      // Clear search via clear icon button
      final clearBtn = find.byIcon(Icons.clear_rounded);
      expect(clearBtn, findsOneWidget);
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      // All restored
      expect(find.text('Gaji Bulanan PT Teknologi Maju'), findsOneWidget);
    });

    testWidgets('filters transactions by type chips (Semua, Pengeluaran, Pemasukan)', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap Pengeluaran filter chip
      final expChip = find.widgetWithText(InkWell, 'Pengeluaran').last;
      await tester.ensureVisible(expChip);
      await tester.tap(expChip);
      await tester.pumpAndSettle();

      // Expenses should show, Incomes should not
      expect(find.text('Sewa Kamar Kos Bulanan'), findsOneWidget);
      expect(find.text('Gaji Bulanan PT Teknologi Maju'), findsNothing);

      // Tap Pemasukan filter chip
      final incChip = find.widgetWithText(InkWell, 'Pemasukan').last;
      await tester.ensureVisible(incChip);
      await tester.tap(incChip);
      await tester.pumpAndSettle();

      // Income should show, Expense should not
      expect(find.text('Gaji Bulanan PT Teknologi Maju'), findsOneWidget);
      expect(find.text('Sewa Kamar Kos Bulanan'), findsNothing);
    });
  });

  group('MainNavigationScreen Rekap Tab Integration Tests', () {
    testWidgets('switches to RekapBulananScreen when Rekap tab is tapped in bottom navigation', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MainNavigationScreen()));
      await tester.pumpAndSettle();

      // Initially on ChatScreen
      expect(find.byType(RekapBulananScreen), findsNothing);

      // Tap 'Rekap' in BottomNavigationBar
      final rekapTab = find.text('Rekap');
      expect(rekapTab, findsOneWidget);
      await tester.tap(rekapTab);
      await tester.pumpAndSettle();

      // Now on RekapBulananScreen
      expect(find.byType(RekapBulananScreen), findsOneWidget);
      expect(find.text('September 2026'), findsWidgets);
    });
  });
}
