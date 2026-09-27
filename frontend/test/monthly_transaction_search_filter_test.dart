import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/models/transaction_item.dart';
import 'package:moneta/screens/rekap/widgets/monthly_transaction_search_filter.dart';

void main() {
  group('MonthlyTransactionSearchFilter (Pencarian dan Filter Transaksi per Bulan)', () {
    late List<TransactionItem> sampleTransactions;

    setUp(() {
      sampleTransactions = [
        TransactionItem(
          id: 'tx_f_1',
          note: 'Makan Nasi Goreng Kambing',
          amount: 45000,
          type: 'expense',
          category: 'Makan & Minuman',
          occurredAt: DateTime(2026, 9, 25, 19, 0),
          isConfirmed: true,
        ),
        TransactionItem(
          id: 'tx_f_2',
          note: 'Belanja Mingguan Sayur Buah',
          amount: 250000,
          type: 'expense',
          category: 'Belanja',
          occurredAt: DateTime(2026, 9, 24, 10, 0),
          isConfirmed: false,
        ),
        TransactionItem(
          id: 'tx_f_3',
          note: 'Gaji Bulanan Software Engineer',
          amount: 12000000,
          type: 'income',
          category: 'Gaji',
          occurredAt: DateTime(2026, 9, 25, 8, 30),
          isConfirmed: true,
        ),
        TransactionItem(
          id: 'tx_f_4',
          note: 'Beli Token Listrik PLN',
          amount: 600000,
          type: 'expense',
          category: 'Tagihan',
          occurredAt: DateTime(2026, 9, 20, 14, 0),
          isConfirmed: true,
        ),
      ];
    });

    testWidgets('searches transactions by keyword in note and category', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyTransactionSearchFilter(
                transactions: sampleTransactions,
                onCategoryFilterChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      // Verify all 4 transactions initially
      expect(find.text('4 Transaksi'), findsOneWidget);

      // Type 'Goreng' into search input
      await tester.enterText(find.byKey(const Key('transaction_search_input')), 'Goreng');
      await tester.pumpAndSettle();

      expect(find.text('Makan Nasi Goreng Kambing'), findsOneWidget);
      expect(find.text('Gaji Bulanan Software Engineer'), findsNothing);
      expect(find.text('1 Transaksi'), findsOneWidget);

      // Search by category 'Tagihan'
      await tester.enterText(find.byKey(const Key('transaction_search_input')), 'Tagihan');
      await tester.pumpAndSettle();

      expect(find.text('Beli Token Listrik PLN'), findsOneWidget);
      expect(find.text('1 Transaksi'), findsOneWidget);
    });

    testWidgets('opens filter bottom sheet and filters by verification status', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyTransactionSearchFilter(
                transactions: sampleTransactions,
                onCategoryFilterChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      // Tap filter sheet button
      await tester.tap(find.byKey(const Key('open_filter_sheet_button')));
      await tester.pumpAndSettle();

      expect(find.text('Filter Transaksi'), findsOneWidget);
      expect(find.text('Status Verifikasi'), findsOneWidget);

      // Select 'Menunggu Konfirmasi'
      await tester.tap(find.text('Menunggu Konfirmasi'));
      await tester.pumpAndSettle();

      // Tap 'Terapkan Filter'
      await tester.ensureVisible(find.byKey(const Key('apply_filter_modal_button')));
      await tester.tap(find.byKey(const Key('apply_filter_modal_button')));
      await tester.pumpAndSettle();

      // Only tx_f_2 is pending (Belanja Mingguan Sayur Buah)
      expect(find.text('Belanja Mingguan Sayur Buah'), findsOneWidget);
      expect(find.text('Makan Nasi Goreng Kambing'), findsNothing);
      expect(find.text('Gaji Bulanan Software Engineer'), findsNothing);
      expect(find.text('1 Transaksi'), findsOneWidget);

      // Active status filter chip should appear
      expect(find.byKey(const Key('active_status_filter_chip')), findsOneWidget);
    });

    testWidgets('filters by amount range (< 100rb)', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyTransactionSearchFilter(
                transactions: sampleTransactions,
                onCategoryFilterChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      // Tap filter sheet button
      await tester.tap(find.byKey(const Key('open_filter_sheet_button')));
      await tester.pumpAndSettle();

      // Select '< Rp 100rb'
      await tester.tap(find.text('< Rp 100rb'));
      await tester.pumpAndSettle();

      // Tap 'Terapkan Filter'
      await tester.ensureVisible(find.byKey(const Key('apply_filter_modal_button')));
      await tester.tap(find.byKey(const Key('apply_filter_modal_button')));
      await tester.pumpAndSettle();

      // Only tx_f_1 (45.000) is < 100rb
      expect(find.text('Makan Nasi Goreng Kambing'), findsOneWidget);
      expect(find.text('Belanja Mingguan Sayur Buah'), findsNothing);
      expect(find.text('Beli Token Listrik PLN'), findsNothing);
      expect(find.text('1 Transaksi'), findsOneWidget);
    });

    testWidgets('resets all filters using clear_all_filters_chip', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyTransactionSearchFilter(
                transactions: sampleTransactions,
                onCategoryFilterChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      // Tap Pengeluaran filter chip
      await tester.tap(find.byKey(const Key('filter_chip_expense')));
      await tester.pumpAndSettle();

      expect(find.text('3 Transaksi'), findsOneWidget);
      expect(find.byKey(const Key('clear_all_filters_chip')), findsOneWidget);

      // Tap Reset Filter chip
      await tester.tap(find.byKey(const Key('clear_all_filters_chip')));
      await tester.pumpAndSettle();

      expect(find.text('4 Transaksi'), findsOneWidget);
    });
  });
}
