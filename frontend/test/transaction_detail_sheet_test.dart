import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/models/transaction_item.dart';
import 'package:moneta/screens/rekap/widgets/monthly_transaction_list_section.dart';
import 'package:moneta/screens/rekap/widgets/transaction_detail_sheet.dart';
import 'package:moneta/state/app_state.dart';

void main() {
  group('TransactionDetailSheet (Tampilan Detail Transaksi Saat Ditekan)', () {
    testWidgets('renders all transaction metadata correctly for expense item', (WidgetTester tester) async {
      final tx = TransactionItem(
        id: 'tx_101',
        amount: 45000,
        type: 'expense',
        category: 'Makanan & Minuman',
        occurredAt: DateTime(2026, 9, 15, 12, 30),
        note: 'Makan siang ayam geprek',
        confidenceScore: 0.96,
        isConfirmed: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => TransactionDetailSheet.show(context, tx),
                child: const Text('Buka Detail'),
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Buka Detail'));
      await tester.pumpAndSettle();

      // Verify header & basic elements
      expect(find.text('Detail Transaksi'), findsOneWidget);
      expect(find.text('Makan siang ayam geprek'), findsOneWidget);
      expect(find.text('Pengeluaran'), findsOneWidget);
      expect(find.byKey(const Key('detail_formatted_amount_text')), findsOneWidget);

      // Verify metadata rows
      expect(find.text('Kategori'), findsOneWidget);
      expect(find.text('Makanan & Minuman'), findsOneWidget);
      expect(find.text('Tanggal & Waktu'), findsOneWidget);
      expect(find.text('15 September 2026 • 12:30 WIB'), findsOneWidget);
      expect(find.text('Status Verifikasi'), findsOneWidget);
      expect(find.text('Terkonfirmasi'), findsOneWidget);
      expect(find.text('Akurasi AI'), findsOneWidget);
      expect(find.text('96% Akurat'), findsOneWidget);
      expect(find.text('ID Transaksi'), findsOneWidget);
      expect(find.text('#tx_101'), findsOneWidget);

      // Since isConfirmed is true, "Konfirmasi" button should not be present
      expect(find.byKey(const Key('detail_confirm_transaction_button')), findsNothing);
      expect(find.byKey(const Key('detail_change_category_button')), findsOneWidget);
      expect(find.byKey(const Key('detail_close_button')), findsOneWidget);

      // Dismiss via Tutup button
      await tester.tap(find.byKey(const Key('detail_close_button')));
      await tester.pumpAndSettle();
      expect(find.text('Detail Transaksi'), findsNothing);
    });

    testWidgets('renders pending income transaction and confirms it', (WidgetTester tester) async {
      bool updatedCalled = false;
      final tx = TransactionItem(
        id: 'tx_202',
        amount: 3500000,
        type: 'income',
        category: 'Gaji',
        occurredAt: DateTime(2026, 9, 25, 9, 0),
        note: 'Gaji Bulanan',
        confidenceScore: 0.88,
        isConfirmed: false,
      );

      AppState.instance.addManualTransaction(tx);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => TransactionDetailSheet.show(
                  context,
                  tx,
                  onUpdated: () {
                    updatedCalled = true;
                  },
                ),
                child: const Text('Buka Detail'),
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Buka Detail'));
      await tester.pumpAndSettle();

      expect(find.text('Detail Transaksi'), findsOneWidget);
      expect(find.text('Pemasukan'), findsOneWidget);
      expect(find.text('Menunggu Konfirmasi'), findsOneWidget);
      expect(find.byKey(const Key('detail_confirm_transaction_button')), findsOneWidget);

      // Tap Confirm button
      await tester.tap(find.byKey(const Key('detail_confirm_transaction_button')));
      await tester.pumpAndSettle();

      expect(updatedCalled, isTrue);
      expect(tx.isConfirmed, isTrue);
      expect(find.text('Transaksi berhasil dikonfirmasi.'), findsOneWidget);
    });

    testWidgets('tapping Ganti Kategori opens category picker sheet', (WidgetTester tester) async {
      final tx = TransactionItem(
        id: 'tx_303',
        amount: 25000,
        type: 'expense',
        category: 'Transportasi',
        occurredAt: DateTime(2026, 9, 20, 8, 15),
        note: 'Ojek online ke kantor',
        confidenceScore: 0.92,
        isConfirmed: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => TransactionDetailSheet.show(context, tx),
                child: const Text('Buka Detail'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka Detail'));
      await tester.pumpAndSettle();

      // Tap "Ganti Kategori"
      final changeBtn = find.byKey(const Key('detail_change_category_button'));
      expect(changeBtn, findsOneWidget);
      await tester.tap(changeBtn);
      await tester.pumpAndSettle();

      // Category picker sheet should now be open
      expect(find.text('Pemilih Kategori Manual'), findsOneWidget);
    });

    testWidgets('tapping item in MonthlyTransactionListSection opens TransactionDetailSheet', (WidgetTester tester) async {
      final tx = TransactionItem(
        id: 'tx_test_tap',
        amount: 50000,
        type: 'expense',
        category: 'Hiburan',
        occurredAt: DateTime(2026, 9, 10, 19, 0),
        note: 'Nonton bioskop',
        confidenceScore: 0.95,
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

      final itemRow = find.byKey(const Key('transaction_item_row_tx_test_tap'));
      expect(itemRow, findsOneWidget);

      await tester.tap(itemRow);
      await tester.pumpAndSettle();

      expect(find.text('Detail Transaksi'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TransactionDetailSheet),
          matching: find.text('Nonton bioskop'),
        ),
        findsOneWidget,
      );
      expect(find.text('#tx_test_tap'), findsOneWidget);

      // Close via top close button
      await tester.tap(find.byKey(const Key('close_detail_sheet_button')));
      await tester.pumpAndSettle();

      expect(find.text('Detail Transaksi'), findsNothing);
    });
  });
}
