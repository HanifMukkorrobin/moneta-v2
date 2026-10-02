import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/models/monthly_rekap_data.dart';
import 'package:moneta/models/transaction_item.dart';
import 'package:moneta/screens/rekap/rekap_bulanan_screen.dart';
import 'package:moneta/screens/rekap/widgets/category_nominal_persentase_list.dart';
import 'package:moneta/screens/rekap/widgets/monthly_transaction_list_section.dart';
import 'package:moneta/screens/rekap/widgets/rekap_comparison_card.dart';
import 'package:moneta/screens/rekap/widgets/rekap_summary_card.dart';
import 'package:moneta/state/app_state.dart';

void main() {
  setUp(() {
    AppState.instance.resetToDefault();
  });

  group('Tampilkan Pesan Kosong di Seluruh Bagian Rekap (Empty States)', () {
    testWidgets('renders all empty state messages when month has zero transactions in RekapBulananScreen', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RekapBulananScreen(initialMonth: '2026-10'),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Top banner empty state in RekapBulananScreen
      expect(find.byKey(const Key('rekap_month_empty_banner')), findsOneWidget);
      expect(find.text('Belum Ada Catatan Keuangan'), findsOneWidget);
      expect(find.textContaining('Belum ada transaksi tercatat di Oktober 2026'), findsOneWidget);

      // 2. Financial Summary Card empty state
      expect(find.byKey(const Key('rekap_summary_empty_message')), findsOneWidget);
      expect(find.text('Belum Ada Data'), findsOneWidget);
      expect(find.text('Rp 0'), findsWidgets);

      // 3. Comparison Card empty placeholder
      expect(find.byKey(const Key('rekap_comparison_empty_card')), findsOneWidget);
      expect(find.text('Belum ada data transaksi di bulan sebelumnya untuk dibandingkan.'), findsOneWidget);

      // 4. Category proportion chart empty message (Pengeluaran tab active)
      expect(find.byKey(const Key('category_proportion_empty_message')), findsOneWidget);
      expect(find.text('Belum ada transaksi pengeluaran untuk ditampilkan.'), findsOneWidget);

      // Switch to Pemasukan tab and verify empty message
      final incomeBtn = find.byKey(const Key('breakdown_type_button_income'));
      await tester.ensureVisible(incomeBtn);
      await tester.tap(incomeBtn);
      await tester.pumpAndSettle();
      expect(find.text('Belum ada transaksi pemasukan untuk ditampilkan.'), findsOneWidget);

      // 5. Monthly Transactions List Section empty state
      final emptyTxList = find.byKey(const Key('monthly_transactions_empty_state'));
      await tester.ensureVisible(emptyTxList);
      expect(emptyTxList, findsOneWidget);
      expect(find.text('Belum ada transaksi di Oktober 2026.'), findsOneWidget);
    });

    testWidgets('RekapSummaryCard displays empty message when totals are zero', (WidgetTester tester) async {
      final emptyData = MonthlyRekapData.getEmptyMonthlyRekap();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RekapSummaryCard(data: emptyData),
          ),
        ),
      );

      expect(find.byKey(const Key('rekap_summary_empty_message')), findsOneWidget);
      expect(find.text('Belum Ada Data'), findsOneWidget);
      expect(find.text('Tabungan Bersih (Net Savings)'), findsOneWidget);
    });

    testWidgets('RekapComparisonCard toggles empty placeholder with showEmptyPlaceholder', (WidgetTester tester) async {
      final emptyData = MonthlyRekapData.getEmptyMonthlyRekap();

      // Default (showEmptyPlaceholder = false) -> renders nothing
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RekapComparisonCard(data: emptyData),
          ),
        ),
      );
      expect(find.byKey(const Key('rekap_comparison_card')), findsNothing);
      expect(find.byKey(const Key('rekap_comparison_empty_card')), findsNothing);

      // showEmptyPlaceholder = true -> renders empty placeholder card
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RekapComparisonCard(data: emptyData, showEmptyPlaceholder: true),
          ),
        ),
      );
      expect(find.byKey(const Key('rekap_comparison_empty_card')), findsOneWidget);
      expect(find.text('Belum ada data transaksi di bulan sebelumnya untuk dibandingkan.'), findsOneWidget);
    });

    testWidgets('MonthlyTransactionListSection shows monthly_transactions_empty_state when transactions list is empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyTransactionListSection(
                transactions: const [],
                monthLabel: 'November 2026',
                onCategoryFilterChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('monthly_transactions_empty_state')), findsOneWidget);
      expect(find.text('Belum ada transaksi di November 2026.'), findsOneWidget);
      expect(find.text('Catat transaksi baru melalui chat untuk mulai mencatat keuangan.'), findsOneWidget);
      expect(find.byKey(const Key('filtered_transactions_empty_state')), findsNothing);
    });

    testWidgets('MonthlyTransactionListSection shows filtered_transactions_empty_state on search keyword mismatch', (WidgetTester tester) async {
      final tx = TransactionItem(
        id: 'tx_s_1',
        note: 'Beli bensin pertamax',
        amount: 50000,
        type: 'expense',
        category: 'Transportasi',
        occurredAt: DateTime(2026, 9, 20),
        isConfirmed: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyTransactionListSection(
                transactions: [tx],
                monthLabel: 'September 2026',
                onCategoryFilterChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      // Search non-existent keyword
      await tester.enterText(find.byKey(const Key('transaction_search_input')), 'XYZ_TIDAK_ADA');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('filtered_transactions_empty_state')), findsOneWidget);
      expect(find.text('Tidak ada transaksi yang cocok.'), findsOneWidget);
      expect(find.byKey(const Key('reset_filters_empty_state_button')), findsOneWidget);

      // Reset filters restores transaction row
      await tester.tap(find.byKey(const Key('reset_filters_empty_state_button')));
      await tester.pumpAndSettle();

      expect(find.text('Beli bensin pertamax'), findsOneWidget);
    });

    testWidgets('CategoryNominalPersentaseList shows category_list_empty_message when empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryNominalPersentaseList(
              items: const [],
              type: 'expense',
              onCategorySelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('category_list_empty_message')), findsOneWidget);
      expect(find.text('Tidak ada kategori pengeluaran.'), findsOneWidget);
    });

    testWidgets('CategoryNominalPersentaseList shows category_list_search_empty_message when search does not match', (WidgetTester tester) async {
      const items = [
        CategoryBreakdownItem(
          category: 'Makanan',
          type: 'expense',
          total: 100000,
          percentage: 100,
          transactionCount: 2,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CategoryNominalPersentaseList(
                items: items,
                type: 'expense',
                onCategorySelected: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Asuransi');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('category_list_search_empty_message')), findsOneWidget);
      expect(find.text('Tidak ditemukan kategori untuk "Asuransi"'), findsOneWidget);
    });
  });
}
