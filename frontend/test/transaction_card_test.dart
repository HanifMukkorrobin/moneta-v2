import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/models/transaction_item.dart';
import 'package:moneta/screens/chat/widgets/transaction_card.dart';

void main() {
  testWidgets('TransactionCard renders unconfirmed expense card with actions',
      (WidgetTester tester) async {
    bool confirmed = false;
    bool categoryChanged = false;
    bool deleted = false;
    bool typeToggled = false;

    final tx = TransactionItem(
      id: 'tx_test_1',
      note: 'Makan siang bakso',
      amount: 25000,
      type: 'expense',
      category: 'Makan & Minuman',
      occurredAt: DateTime(2026, 9, 27, 12, 30),
      isConfirmed: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransactionCard(
            transaction: tx,
            onConfirm: () => confirmed = true,
            onChangeCategory: () => categoryChanged = true,
            onDelete: () => deleted = true,
            onToggleType: () => typeToggled = true,
          ),
        ),
      ),
    );

    // Verify AI tag & amount
    expect(find.text('Hasil Parse AI'), findsOneWidget);
    expect(find.text('- Rp 25.000'), findsOneWidget);
    expect(find.text('Pengeluaran'), findsOneWidget);
    expect(find.text('Makan & Minuman'), findsOneWidget);
    expect(find.text('Makan siang bakso'), findsOneWidget);

    // Verify action buttons
    expect(find.text('Simpan'), findsOneWidget);
    expect(find.text('Ubah'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    // Tap Simpan
    await tester.tap(find.text('Simpan'));
    expect(confirmed, isTrue);

    // Tap Ubah
    await tester.tap(find.text('Ubah'));
    expect(categoryChanged, isTrue);

    // Tap Delete
    await tester.tap(find.byIcon(Icons.delete_outline));
    expect(deleted, isTrue);

    // Tap Type badge
    await tester.tap(find.text('Pengeluaran'));
    expect(typeToggled, isTrue);
  });

  testWidgets('TransactionCard renders confirmed income card',
      (WidgetTester tester) async {
    final tx = TransactionItem(
      id: 'tx_test_2',
      note: 'Gajian bulanan',
      amount: 8000000,
      type: 'income',
      category: 'Gaji',
      occurredAt: DateTime(2026, 9, 27, 9, 0),
      isConfirmed: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransactionCard(
            transaction: tx,
            onConfirm: () {},
            onChangeCategory: () {},
            onDelete: () {},
          ),
        ),
      ),
    );

    // Verify AI tag & amount
    expect(find.text('Tercatat Otomatis'), findsOneWidget);
    expect(find.text('+ Rp 8.000.000'), findsOneWidget);
    expect(find.text('Pemasukan'), findsOneWidget);
    expect(find.text('Gaji'), findsOneWidget);
    expect(find.text('Tersimpan'), findsOneWidget);

    // Pending buttons should not exist
    expect(find.text('Simpan'), findsNothing);
  });
}
