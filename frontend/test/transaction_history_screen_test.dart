import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/screens/category_confirmation/category_confirmation_screen.dart';
import 'package:moneta/screens/category_confirmation/widgets/category_picker_sheet.dart';
import 'package:moneta/screens/chat/chat_history_screen.dart';
import 'package:moneta/screens/chat/chat_screen.dart';
import 'package:moneta/screens/history/transaction_history_screen.dart';
import 'package:moneta/state/app_state.dart';

void main() {
  setUp(() {
    AppState.instance.resetToDefault();
  });

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  void setupScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('TransactionHistoryScreen renders summary, cards, and categories',
      (WidgetTester tester) async {
    setupScreen(tester);

    await tester.pumpWidget(buildTestableWidget(const TransactionHistoryScreen()));
    await tester.pumpAndSettle();

    // Verify Title and Subtitle
    expect(find.text('Riwayat Catatan Transaksi'), findsOneWidget);
    expect(find.text('Kelola catatan & ganti kategori transaksi'), findsOneWidget);

    // Verify Financial Summary
    expect(find.text('Total Catatan'), findsOneWidget);
    expect(find.text('Saldo Bersih'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_outward_rounded), findsWidgets);
    expect(find.byIcon(Icons.arrow_downward_rounded), findsWidgets);

    // Verify initial transaction cards
    expect(find.text('Makan siang ayam geprek'), findsOneWidget);
    expect(find.text('Bensin pertamax'), findsOneWidget);

    // Verify Ganti Kategori buttons exist
    expect(find.text('Ganti Kategori'), findsWidgets);
  });

  testWidgets('TransactionHistoryScreen filters by type and category',
      (WidgetTester tester) async {
    setupScreen(tester);

    await tester.pumpWidget(buildTestableWidget(const TransactionHistoryScreen()));
    await tester.pumpAndSettle();

    // Filter by 'Pemasukan'
    final pemasukanChip = find.widgetWithText(ChoiceChip, 'Pemasukan');
    expect(pemasukanChip, findsOneWidget);
    await tester.tap(pemasukanChip);
    await tester.pumpAndSettle();

    // 'Makan siang ayam geprek' is expense, should NOT be shown
    expect(find.text('Makan siang ayam geprek'), findsNothing);

    // If there is income in mock data (e.g., 'Gajian freelance'), it should appear
    if (find.text('Gajian freelance').evaluate().isNotEmpty) {
      expect(find.text('Gajian freelance'), findsOneWidget);
    }

    // Switch back to 'Semua Jenis'
    final semuaChip = find.widgetWithText(ChoiceChip, 'Semua Jenis');
    await tester.tap(semuaChip);
    await tester.pumpAndSettle();

    expect(find.text('Makan siang ayam geprek'), findsOneWidget);
  });

  testWidgets('TransactionHistoryScreen search query filters transactions',
      (WidgetTester tester) async {
    setupScreen(tester);

    await tester.pumpWidget(buildTestableWidget(const TransactionHistoryScreen()));
    await tester.pumpAndSettle();

    final searchField = find.byType(TextField);
    expect(searchField, findsOneWidget);

    await tester.enterText(searchField, 'bensin');
    await tester.pumpAndSettle();

    expect(find.text('Bensin pertamax'), findsOneWidget);
    expect(find.text('Makan siang ayam geprek'), findsNothing);

    // Clear search
    final clearButton = find.byIcon(Icons.clear);
    expect(clearButton, findsOneWidget);
    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    expect(find.text('Makan siang ayam geprek'), findsOneWidget);
  });

  testWidgets('Ganti Kategori button opens CategoryPickerSheet and updates category',
      (WidgetTester tester) async {
    setupScreen(tester);

    await tester.pumpWidget(buildTestableWidget(const TransactionHistoryScreen()));
    await tester.pumpAndSettle();

    // Find the first 'Ganti Kategori' button
    final gantiButtons = find.widgetWithText(TextButton, 'Ganti Kategori');
    expect(gantiButtons, findsWidgets);

    await tester.tap(gantiButtons.first);
    await tester.pumpAndSettle();

    // Verify CategoryPickerSheet opens
    expect(find.text('Pemilih Kategori Manual'), findsOneWidget);
    expect(find.text('Belanja'), findsWidgets);

    // Select 'Belanja' inside CategoryPickerSheet
    final belanjaChipInSheet = find.descendant(
      of: find.byType(CategoryPickerSheet),
      matching: find.widgetWithText(ChoiceChip, 'Belanja'),
    );
    expect(belanjaChipInSheet, findsOneWidget);
    await tester.tap(belanjaChipInSheet);
    await tester.pumpAndSettle();

    // Tap 'Terapkan Kategori'
    final applyButton = find.widgetWithText(ElevatedButton, 'Terapkan Kategori');
    expect(applyButton, findsOneWidget);
    await tester.tap(applyButton);
    await tester.pumpAndSettle();

    // SnackBar should confirm the update
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('diubah:'), findsOneWidget);
  });

  testWidgets('Toggle type on TransactionHistoryCard switches expense/income',
      (WidgetTester tester) async {
    setupScreen(tester);

    await tester.pumpWidget(buildTestableWidget(const TransactionHistoryScreen()));
    await tester.pumpAndSettle();

    // Find 'Ubah ke Masuk' on an expense transaction
    final toggleButtons = find.widgetWithText(TextButton, 'Ubah ke Masuk');
    expect(toggleButtons, findsWidgets);

    await tester.tap(toggleButtons.first);
    await tester.pumpAndSettle();

    // Verify SnackBar feedback
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Jenis transaksi diubah ke Pemasukan'), findsOneWidget);
  });

  testWidgets('Navigate to TransactionHistoryScreen from ChatScreen AppBar',
      (WidgetTester tester) async {
    setupScreen(tester);

    await tester.pumpWidget(buildTestableWidget(const ChatScreen()));
    await tester.pumpAndSettle();

    final historyIcon = find.byTooltip('Riwayat Catatan Transaksi');
    expect(historyIcon, findsOneWidget);

    await tester.tap(historyIcon);
    await tester.pumpAndSettle();

    expect(find.text('Riwayat Catatan Transaksi'), findsOneWidget);
  });

  testWidgets('Navigate to TransactionHistoryScreen from CategoryConfirmationScreen',
      (WidgetTester tester) async {
    setupScreen(tester);

    await tester.pumpWidget(buildTestableWidget(const CategoryConfirmationScreen()));
    await tester.pumpAndSettle();

    final historyIcon = find.byTooltip('Riwayat Catatan Transaksi');
    expect(historyIcon, findsOneWidget);

    await tester.tap(historyIcon);
    await tester.pumpAndSettle();

    expect(find.text('Riwayat Catatan Transaksi'), findsOneWidget);
  });

  testWidgets('ChatHistoryScreen has Ganti Kategori and opens CategoryPickerSheet',
      (WidgetTester tester) async {
    setupScreen(tester);

    await tester.pumpWidget(buildTestableWidget(const ChatHistoryScreen()));
    await tester.pumpAndSettle();

    // Verify link to TransactionHistoryScreen exists
    expect(find.byTooltip('Riwayat Catatan Transaksi'), findsOneWidget);
    expect(find.textContaining('Kelola & ganti kategori catatan transaksi lengkap'), findsOneWidget);

    // Verify 'Ganti Kategori' exists on transaction logs
    final gantiCatButtons = find.widgetWithText(TextButton, 'Ganti Kategori');
    expect(gantiCatButtons, findsWidgets);

    await tester.tap(gantiCatButtons.first);
    await tester.pumpAndSettle();

    expect(find.text('Pemilih Kategori Manual'), findsOneWidget);

    // Select category
    await tester.tap(find.widgetWithText(ChoiceChip, 'Transportasi').first);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Terapkan Kategori'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Kategori catatan diubah:'), findsOneWidget);
  });
}
