import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/models/transaction_item.dart';
import 'package:moneta/screens/rekap/widgets/monthly_transaction_list_section.dart';

void main() {
  group('MonthlyTransactionListSection (Daftar Transaksi Bulan Terpilih)', () {
    late List<TransactionItem> testTransactions;

    setUp(() {
      testTransactions = [
        TransactionItem(
          id: 'tx_1',
          note: 'Makan Siang Sate Padang',
          amount: 55000,
          type: 'expense',
          category: 'Makan & Minuman',
          occurredAt: DateTime(2026, 9, 26, 12, 30),
          isConfirmed: true,
        ),
        TransactionItem(
          id: 'tx_2',
          note: 'Gaji Pokok Kantor',
          amount: 9500000,
          type: 'income',
          category: 'Gaji',
          occurredAt: DateTime(2026, 9, 25, 9, 0),
          isConfirmed: true,
        ),
        TransactionItem(
          id: 'tx_3',
          note: 'Beli Kopi Janji Jiwa',
          amount: 28000,
          type: 'expense',
          category: 'Makan & Minuman',
          occurredAt: DateTime(2026, 9, 25, 15, 0),
          isConfirmed: false,
        ),
        TransactionItem(
          id: 'tx_4',
          note: 'Bonus Kinerja Kuartal',
          amount: 2000000,
          type: 'income',
          category: 'Bonus',
          occurredAt: DateTime(2026, 9, 20, 10, 0),
          isConfirmed: true,
          isCustomCategory: true,
        ),
      ];
    });

    testWidgets('renders transactions list with date groups and amounts', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyTransactionListSection(
                transactions: testTransactions,
                monthLabel: 'September 2026',
                onCategoryFilterChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      // Verify header with month label
      expect(find.text('Daftar Transaksi: September 2026'), findsOneWidget);
      expect(find.text('4 Transaksi'), findsOneWidget);

      // Verify date headers
      expect(find.text('26 Sep 2026'), findsOneWidget);
      expect(find.text('25 Sep 2026'), findsOneWidget);
      expect(find.text('20 Sep 2026'), findsOneWidget);

      // Verify notes
      expect(find.text('Makan Siang Sate Padang'), findsOneWidget);
      expect(find.text('Gaji Pokok Kantor'), findsOneWidget);
      expect(find.text('Beli Kopi Janji Jiwa'), findsOneWidget);
      expect(find.text('Bonus Kinerja Kuartal'), findsOneWidget);

      // Verify amounts
      expect(find.text('- Rp 55.000'), findsWidgets);
      expect(find.text('+ Rp 9.500.000'), findsWidgets);
      expect(find.text('- Rp 28.000'), findsWidgets);
      expect(find.text('+ Rp 2.000.000'), findsWidgets);
    });

    testWidgets('filters by transaction type chips (Semua, Pengeluaran, Pemasukan)', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyTransactionListSection(
                transactions: testTransactions,
                onCategoryFilterChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      // Tap Pengeluaran filter
      await tester.tap(find.byKey(const Key('filter_chip_expense')));
      await tester.pumpAndSettle();

      expect(find.text('Makan Siang Sate Padang'), findsOneWidget);
      expect(find.text('Beli Kopi Janji Jiwa'), findsOneWidget);
      expect(find.text('Gaji Pokok Kantor'), findsNothing);
      expect(find.text('Bonus Kinerja Kuartal'), findsNothing);
      expect(find.text('2 Transaksi'), findsOneWidget);

      // Tap Pemasukan filter
      await tester.tap(find.byKey(const Key('filter_chip_income')));
      await tester.pumpAndSettle();

      expect(find.text('Gaji Pokok Kantor'), findsOneWidget);
      expect(find.text('Bonus Kinerja Kuartal'), findsOneWidget);
      expect(find.text('Makan Siang Sate Padang'), findsNothing);
      expect(find.text('Beli Kopi Janji Jiwa'), findsNothing);
      expect(find.text('2 Transaksi'), findsOneWidget);

      // Tap Semua filter
      await tester.tap(find.byKey(const Key('filter_chip_all')));
      await tester.pumpAndSettle();

      expect(find.text('4 Transaksi'), findsOneWidget);
    });

    testWidgets('searches transactions by keyword and clears search', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyTransactionListSection(
                transactions: testTransactions,
                onCategoryFilterChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      // Search 'kopi'
      await tester.enterText(find.byKey(const Key('transaction_search_input')), 'kopi');
      await tester.pumpAndSettle();

      expect(find.text('Beli Kopi Janji Jiwa'), findsOneWidget);
      expect(find.text('Makan Siang Sate Padang'), findsNothing);
      expect(find.text('1 Transaksi'), findsOneWidget);

      // Clear search
      await tester.enterText(find.byKey(const Key('transaction_search_input')), '');
      await tester.pumpAndSettle();

      expect(find.text('4 Transaksi'), findsOneWidget);
    });

    testWidgets('shows active category filter chip and removes it when deleted', (WidgetTester tester) async {
      String? activeCategory = 'Makan & Minuman';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: MonthlyTransactionListSection(
                    transactions: testTransactions,
                    activeCategoryFilter: activeCategory,
                    onCategoryFilterChanged: (cat) {
                      setState(() => activeCategory = cat);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('active_category_filter_chip')), findsOneWidget);
      expect(find.text('Makan Siang Sate Padang'), findsOneWidget);
      expect(find.text('Beli Kopi Janji Jiwa'), findsOneWidget);
      expect(find.text('Gaji Pokok Kantor'), findsNothing);

      // Delete the chip
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(activeCategory, isNull);
    });

    testWidgets('opens transaction detail modal on item tap', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyTransactionListSection(
                transactions: testTransactions,
                onCategoryFilterChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      // Tap on tx_1 (Makan Siang Sate Padang)
      await tester.tap(find.byKey(const Key('transaction_item_row_tx_1')));
      await tester.pumpAndSettle();

      // Verify bottom sheet content
      expect(find.text('Makan Siang Sate Padang'), findsWidgets);
      expect(find.text('Terkonfirmasi'), findsOneWidget);
      expect(find.text('Kategori'), findsOneWidget);
      expect(find.text('Tutup'), findsOneWidget);

      // Tap Tutup to close modal
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();

      expect(find.text('Tutup'), findsNothing);
    });

    testWidgets('sorts transactions by highest and lowest amount', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyTransactionListSection(
                transactions: testTransactions,
                onCategoryFilterChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      // Open sort menu
      await tester.tap(find.byKey(const Key('transaction_sort_button')));
      await tester.pumpAndSettle();

      // Select 'Nominal Terbesar'
      await tester.tap(find.text('Nominal Terbesar'));
      await tester.pumpAndSettle();

      expect(find.text('Gaji Pokok Kantor'), findsOneWidget);
    });
  });
}
