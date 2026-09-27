import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/main.dart';
import 'package:moneta/models/chat_log_item.dart';
import 'package:moneta/screens/chat/chat_history_screen.dart';

void main() {
  testWidgets('ChatHistoryScreen renders logs, filters by status, and searches',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ChatHistoryScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify AppBar title
    expect(find.text('Riwayat Obrolan'), findsOneWidget);

    // Verify stats counters
    expect(find.text('Semua'), findsWidgets);
    expect(find.text('Tersimpan'), findsWidgets);
    expect(find.text('Menunggu'), findsWidgets);
    expect(find.text('Dibatalkan'), findsWidgets);

    // Verify log items are displayed
    expect(find.text('Makan siang ayam geprek 25rb'), findsOneWidget);
    expect(find.text('Bensin pertamax 50rb'), findsOneWidget);
    expect(find.text('Kopi americano 22rb'), findsOneWidget);

    // Test filtering by 'Tersimpan'
    await tester.tap(find.widgetWithText(ChoiceChip, 'Tersimpan'));
    await tester.pumpAndSettle();

    // Pending item should no longer be visible
    expect(find.text('Kopi americano 22rb'), findsNothing);
    expect(find.text('Makan siang ayam geprek 25rb'), findsOneWidget);

    // Reset filter to 'Semua'
    await tester.tap(find.widgetWithText(ChoiceChip, 'Semua'));
    await tester.pumpAndSettle();

    // Test search functionality
    final searchFieldFinder = find.byType(TextField);
    await tester.enterText(searchFieldFinder, 'bensin');
    await tester.pumpAndSettle();

    expect(find.text('Bensin pertamax 50rb'), findsOneWidget);
    expect(find.text('Makan siang ayam geprek 25rb'), findsNothing);

    // Clear search
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    expect(find.text('Makan siang ayam geprek 25rb'), findsOneWidget);
  });

  testWidgets('ChatHistoryScreen allows confirming pending chat log',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    ChatLogItem? confirmedItem;

    await tester.pumpWidget(
      MaterialApp(
        home: ChatHistoryScreen(
          onConfirmPending: (item) {
            confirmedItem = item;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Filter to 'Menunggu'
    await tester.tap(find.widgetWithText(ChoiceChip, 'Menunggu'));
    await tester.pumpAndSettle();

    expect(find.text('Kopi americano 22rb'), findsOneWidget);
    expect(find.text('Simpan'), findsOneWidget);

    // Tap Simpan on the pending item
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(confirmedItem, isNotNull);
    expect(confirmedItem!.isConfirmed, isTrue);
  });

  testWidgets('Navigate to ChatHistoryScreen from ChatScreen AppBar',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MonetaApp());
    await tester.pumpAndSettle();

    // Tap Riwayat Obrolan icon in AppBar
    await tester.tap(find.byTooltip('Riwayat Obrolan'));
    await tester.pumpAndSettle();

    // Verify ChatHistoryScreen is pushed
    expect(find.text('Riwayat Obrolan'), findsOneWidget);
    expect(find.text('Makan siang ayam geprek 25rb'), findsOneWidget);
  });
}
