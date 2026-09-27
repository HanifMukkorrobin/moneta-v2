import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/main.dart';

void main() {
  testWidgets('Direct manual input from AppBar action button',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MonetaApp());
    await tester.pumpAndSettle();

    // Tap AppBar manual input button
    final manualActionFinder = find.byTooltip('Input Transaksi Manual');
    expect(manualActionFinder, findsOneWidget);
    await tester.tap(manualActionFinder);
    await tester.pumpAndSettle();

    // Verify ManualInputSheet is displayed
    expect(find.text('Input Transaksi Manual'), findsOneWidget);

    // Enter nominal 65000
    final amountFinder = find.widgetWithText(TextField, 'Contoh: 50000');
    expect(amountFinder, findsOneWidget);
    await tester.enterText(amountFinder, '65000');
    await tester.pump();

    // Enter note
    final noteFinder =
        find.widgetWithText(TextField, 'Contoh: Belanja sayur di pasar');
    expect(noteFinder, findsOneWidget);
    await tester.enterText(noteFinder, 'Isi token listrik');
    await tester.pump();

    // Select category 'Tagihan & Utilitas'
    await tester.tap(find.text('Tagihan & Utilitas'));
    await tester.pump();

    // Save
    await tester.tap(find.text('Simpan Transaksi'));
    await tester.pumpAndSettle();

    // Verify transaction appears in the list
    expect(
        find.textContaining('Transaksi berhasil dicatat secara manual'),
        findsOneWidget);
    expect(find.text('Isi token listrik'), findsOneWidget);
    expect(find.text('- Rp 65.000'), findsOneWidget);
  });

  testWidgets(
      'AI fallback card appears on unrecognized prompt and allows manual input',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MonetaApp());
    await tester.pumpAndSettle();

    // Type ambiguous text with no amount to trigger AI parse failure
    final textFieldFinder = find.byType(TextField);
    await tester.enterText(textFieldFinder, 'error sistem belanja');
    await tester.pump(); // Allow state to update _hasText

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();

    // Fast forward for simulated AI parsing
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    // Verify AI fallback card is rendered
    expect(find.text('AI Gagal Mengenali Transaksi'), findsOneWidget);
    expect(find.textContaining('error sistem belanja'), findsWidgets);
    expect(find.text('Input Manual'), findsOneWidget);

    // Tap "Input Manual" on fallback card
    await tester.tap(find.text('Input Manual'));
    await tester.pumpAndSettle();

    // Verify sheet opened with prefilled note
    expect(find.text('Input Transaksi Manual'), findsOneWidget);
    expect(find.text('error sistem belanja'), findsWidgets);

    // Enter amount
    final amountFinder = find.widgetWithText(TextField, 'Contoh: 50000');
    await tester.enterText(amountFinder, '45000');
    await tester.pump();

    // Save
    await tester.tap(find.text('Simpan Transaksi'));
    await tester.pumpAndSettle();

    // Verify fallback card was replaced by confirmed manual transaction
    expect(find.text('AI Gagal Mengenali Transaksi'), findsNothing);
    expect(find.text('- Rp 45.000'), findsOneWidget);
  });
}
