import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/models/transaction_item.dart';
import 'package:moneta/screens/chat/widgets/edit_transaction_sheet.dart';

void main() {
  testWidgets('EditTransactionSheet edits amount, note, and category',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    TransactionItem? savedResult;

    final initialTx = TransactionItem(
      id: 'tx_edit_1',
      note: 'Makan siang padang',
      amount: 25000,
      type: 'expense',
      category: 'Makan & Minuman',
      occurredAt: DateTime.now(),
      isConfirmed: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  EditTransactionSheet.show(
                    context,
                    transaction: initialTx,
                    onSave: (res) {
                      savedResult = res;
                    },
                  );
                },
                child: const Text('Open Sheet'),
              );
            },
          ),
        ),
      ),
    );

    // Open sheet
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Verify sheet title and fields
    expect(find.text('Ubah Data Transaksi'), findsOneWidget);
    expect(find.text('25000'), findsOneWidget);
    expect(find.text('Makan siang padang'), findsOneWidget);

    // Change amount to 35000
    final amountFinder = find.widgetWithText(TextField, '25000');
    await tester.enterText(amountFinder, '35000');
    await tester.pump();

    // Change note
    final noteFinder = find.widgetWithText(TextField, 'Makan siang padang');
    await tester.enterText(noteFinder, 'Makan siang rendang spesial');
    await tester.pump();

    // Select category 'Belanja'
    await tester.tap(find.text('Belanja'));
    await tester.pump();

    // Save changes
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();

    // Verify result passed to callback
    expect(savedResult, isNotNull);
    expect(savedResult!.amount, equals(35000));
    expect(savedResult!.note, equals('Makan siang rendang spesial'));
    expect(savedResult!.category, equals('Belanja'));
  });

  testWidgets('EditTransactionSheet allows custom category creation',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    TransactionItem? savedResult;

    final initialTx = TransactionItem(
      id: 'tx_edit_2',
      note: 'Beli buku bacaan',
      amount: 100000,
      type: 'expense',
      category: 'Belanja',
      occurredAt: DateTime.now(),
      isConfirmed: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  EditTransactionSheet.show(
                    context,
                    transaction: initialTx,
                    onSave: (res) {
                      savedResult = res;
                    },
                  );
                },
                child: const Text('Open Sheet'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Tap "Kategori Baru"
    await tester.tap(find.text('Kategori Baru'));
    await tester.pumpAndSettle();

    // Enter custom category name
    final customInputFinder =
        find.widgetWithText(TextField, 'Nama kategori baru...');
    expect(customInputFinder, findsOneWidget);
    await tester.enterText(customInputFinder, 'Edukasi & Buku');
    await tester.pump();

    // Tap "Tambah"
    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();

    // Save
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();

    expect(savedResult, isNotNull);
    expect(savedResult!.category, equals('Edukasi & Buku'));
  });
}
