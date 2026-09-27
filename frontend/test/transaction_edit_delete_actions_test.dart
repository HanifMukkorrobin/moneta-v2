import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/main.dart';
import 'package:moneta/models/transaction_item.dart';
import 'package:moneta/screens/chat/widgets/transaction_card.dart';

void main() {
  testWidgets('TransactionCard shows Ubah Data and Hapus when confirmed',
      (WidgetTester tester) async {
    bool editCalled = false;
    bool deleteCalled = false;

    final tx = TransactionItem(
      id: 'tx_confirmed_1',
      note: 'Makan siang ayam bakar',
      amount: 30000,
      type: 'expense',
      category: 'Makan & Minuman',
      occurredAt: DateTime.now(),
      isConfirmed: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransactionCard(
            transaction: tx,
            onConfirm: () {},
            onChangeCategory: () => editCalled = true,
            onDelete: () => deleteCalled = true,
          ),
        ),
      ),
    );

    // Verify confirmed badge
    expect(find.text('Tersimpan'), findsOneWidget);

    // Verify action buttons for confirmed card
    expect(find.text('Ubah Data'), findsOneWidget);
    expect(find.text('Hapus'), findsOneWidget);

    // Tap Ubah Data
    await tester.tap(find.text('Ubah Data'));
    expect(editCalled, isTrue);

    // Tap Hapus
    await tester.tap(find.text('Hapus'));
    expect(deleteCalled, isTrue);
  });

  testWidgets(
      'ChatScreen delete confirmation dialog and undo action works properly',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MonetaApp());
    await tester.pumpAndSettle();

    // Verify initial transaction exists
    expect(find.text('Makan siang ayam geprek'), findsOneWidget);

    // Find first 'Hapus' button on confirmed transaction card
    final deleteButtons = find.text('Hapus');
    expect(deleteButtons, findsWidgets);
    await tester.tap(deleteButtons.first);
    await tester.pumpAndSettle();

    // Verify confirmation dialog appeared
    expect(find.text('Hapus Catatan Transaksi?'), findsOneWidget);
    expect(find.text('Batal'), findsOneWidget);

    // Test dismiss/cancel dialog first
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    // Transaction is still present
    expect(find.text('Makan siang ayam geprek'), findsOneWidget);

    // Tap Hapus again and confirm
    await tester.tap(deleteButtons.first);
    await tester.pumpAndSettle();

    // Confirm deletion inside the dialog
    final dialogDeleteButton = find.widgetWithText(ElevatedButton, 'Hapus');
    expect(dialogDeleteButton, findsOneWidget);
    await tester.tap(dialogDeleteButton);
    await tester.pumpAndSettle();

    // Verify transaction removed
    expect(find.text('Makan siang ayam geprek'), findsNothing);
    expect(find.text('Transaksi berhasil dihapus'), findsOneWidget);
    expect(find.text('Urungkan'), findsOneWidget);

    // Tap Urungkan (Undo)
    await tester.tap(find.text('Urungkan'));
    await tester.pumpAndSettle();

    // Verify transaction restored
    expect(find.text('Makan siang ayam geprek'), findsOneWidget);
  });
}
