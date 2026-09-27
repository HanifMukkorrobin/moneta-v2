import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/main.dart';

void main() {
  testWidgets('Moneta smoke test and ChatScreen verification',
      (WidgetTester tester) async {
    // Set a large screen size so elements are visible
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Build the app
    await tester.pumpWidget(const MonetaApp());
    await tester.pumpAndSettle();

    // Verify AppBar header and AI status
    expect(find.text('Moneta AI'), findsOneWidget);
    expect(find.text('9Router AI Siap'), findsOneWidget);

    // Verify Navigation destinations
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Rekap'), findsOneWidget);
    expect(find.text('Budget'), findsOneWidget);
    expect(find.text('Hutang'), findsOneWidget);
    expect(find.text('Analisa'), findsOneWidget);

    // Verify initial chat messages and transactions exist
    expect(find.textContaining('Halo! Aku Moneta AI'), findsOneWidget);

    // Scroll to see the unconfirmed transaction card
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('Simpan'), findsWidgets);

    // Verify quick suggestion chips exist
    expect(find.text('☕ Kopi 25rb'), findsOneWidget);

    // Tap a suggestion chip
    await tester.tap(find.text('☕ Kopi 25rb'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify user message appears in list
    expect(find.text('Kopi americano 25rb'), findsOneWidget);

    // Advance time for simulated AI response
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    // Verify AI response parsed card is rendered
    expect(find.textContaining('AI berhasil mengenali transaksi'),
        findsOneWidget);

    // Test typing a custom transaction into the input field
    final textFieldFinder = find.byType(TextField);
    expect(textFieldFinder, findsOneWidget);
    await tester.enterText(textFieldFinder, 'Makan siang soto 15rb');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Makan siang soto 15rb'), findsWidgets);

    // Advance for AI response
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.textContaining('Makan siang soto 15rb'), findsWidgets);
    expect(find.text('Makan & Minuman'), findsWidgets);
  });

  testWidgets('All main tabs render without overflow on mobile phone viewport',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MonetaApp());
    await tester.pumpAndSettle();

    // 1. Chat tab
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();

    // 2. Rekap tab
    await tester.tap(find.text('Rekap'));
    await tester.pumpAndSettle();
    await tester.drag(
        find.byKey(const Key('rekap_body_scroll_view')), const Offset(0, -500));
    await tester.pumpAndSettle();

    // 3. Budget tab
    await tester.tap(find.text('Budget'));
    await tester.pumpAndSettle();

    // 4. Hutang tab
    await tester.tap(find.text('Hutang'));
    await tester.pumpAndSettle();

    // 5. Analisa tab
    await tester.tap(find.text('Analisa'));
    await tester.pumpAndSettle();
  });
}
