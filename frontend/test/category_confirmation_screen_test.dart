import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/screens/category_confirmation/category_confirmation_screen.dart';
import 'package:moneta/screens/category_confirmation/widgets/category_confirmation_card.dart';
import 'package:moneta/screens/category_confirmation/widgets/edit_category_sheet.dart';
import 'package:moneta/state/app_state.dart';
import 'package:moneta/theme/app_theme.dart';

void main() {
  setUp(() {
    AppState.instance.resetToDefault();
  });

  Widget buildTestableWidget() {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: AppStateScope(
        notifier: AppState.instance,
        child: const CategoryConfirmationScreen(),
      ),
    );
  }

  testWidgets('renders CategoryConfirmationScreen with title, summary banner, and mock cards',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Check AppBar
    expect(find.text('Konfirmasi Kategori AI'), findsOneWidget);
    expect(find.text('Kategori Otomatis & Pilah Masuk/Keluar'), findsOneWidget);

    // Check Summary Banner
    expect(find.textContaining('Transaksi Perlu Konfirmasi'), findsOneWidget);
    expect(find.textContaining('Total tertunda:'), findsOneWidget);

    // Check Search bar and Filter chips
    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('Perlu Ditinjau'), findsOneWidget);
    expect(find.textContaining('Semua'), findsWidgets);
    expect(find.textContaining('Pengeluaran'), findsWidgets);
    expect(find.textContaining('Pemasukan'), findsWidgets);

    // Check cards
    expect(find.byType(CategoryConfirmationCard), findsWidgets);
    expect(find.text('Kopi kenangan mantan large 24rb'), findsOneWidget);
    expect(find.text('Makan & Minuman'), findsWidgets);
  });

  testWidgets('filter tabs filter transactions correctly',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Tap "Pengeluaran" filter chip
    final expenseChip = find.widgetWithText(FilterChip, 'Pengeluaran (4)');
    expect(expenseChip, findsOneWidget);
    await tester.tap(expenseChip);
    await tester.pumpAndSettle();

    // Income items like Gaji should not appear in Pengeluaran filter
    expect(find.text('Transfer gaji kantor PT Maju Jaya 8.500.000'), findsNothing);
    // Expense items should appear
    expect(find.text('Kopi kenangan mantan large 24rb'), findsOneWidget);

    // Tap "Pemasukan" filter chip
    final incomeChip = find.widgetWithText(FilterChip, 'Pemasukan (2)');
    expect(incomeChip, findsOneWidget);
    await tester.tap(incomeChip);
    await tester.pumpAndSettle();

    // Income items should appear
    expect(find.text('Transfer gaji kantor PT Maju Jaya 8.500.000'), findsOneWidget);
    // Expense items should not appear
    expect(find.text('Kopi kenangan mantan large 24rb'), findsNothing);
  });

  testWidgets('confirming an item marks it as confirmed',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Find the first "Konfirmasi" button
    final confirmButtons = find.widgetWithText(ElevatedButton, 'Konfirmasi');
    expect(confirmButtons, findsWidgets);

    await tester.tap(confirmButtons.first);
    await tester.pumpAndSettle();

    // Check SnackBar appeared
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('dikonfirmasi!'), findsOneWidget);
  });

  testWidgets('tapping alternative category chip updates category',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Look for alternative chip "Jajan & Camilan" on the first card
    final altChip = find.widgetWithText(ActionChip, 'Jajan & Camilan');
    expect(altChip, findsOneWidget);

    await tester.tap(altChip);
    await tester.pumpAndSettle();

    // Category should be updated
    expect(find.text('Jajan & Camilan'), findsWidgets);
    expect(find.textContaining('Kategori diperbarui:'), findsOneWidget);
  });

  testWidgets('batch confirm all marks all pending items as confirmed',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Tap "Semua" button on the summary banner
    final confirmAllButton = find.widgetWithText(ElevatedButton, 'Semua');
    expect(confirmAllButton, findsOneWidget);

    await tester.tap(confirmAllButton);
    await tester.pumpAndSettle();

    // Banner should show celebratory state
    expect(find.text('Semua Kategori Sudah Dikonfirmasi! 🎉'), findsOneWidget);
  });

  testWidgets('opening EditCategorySheet allows editing category and type',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Tap "Ubah Kategori" button
    final editButtons = find.widgetWithText(OutlinedButton, 'Ubah Kategori');
    expect(editButtons, findsWidgets);

    await tester.tap(editButtons.first);
    await tester.pumpAndSettle();

    // Sheet should be visible
    expect(find.byType(EditCategorySheet), findsOneWidget);
    expect(find.text('Perbaiki / Ganti Kategori'), findsOneWidget);

    // Pick "Belanja" category
    final belanjaChip = find.widgetWithText(ChoiceChip, 'Belanja');
    if (belanjaChip.evaluate().isNotEmpty) {
      await tester.tap(belanjaChip);
      await tester.pumpAndSettle();
    }

    // Tap apply button
    final applyButton =
        find.widgetWithText(ElevatedButton, 'Terapkan Perubahan Kategori');
    expect(applyButton, findsOneWidget);
    await tester.tap(applyButton);
    await tester.pumpAndSettle();

    // Sheet should close and SnackBar appear
    expect(find.byType(EditCategorySheet), findsNothing);
    expect(find.textContaining('Kategori diperbarui:'), findsOneWidget);
  });

  testWidgets('reset button restores initial mock data',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Delete one item
    final deleteButtons = find.byTooltip('Abaikan / Hapus');
    expect(deleteButtons, findsWidgets);
    await tester.tap(deleteButtons.first);
    await tester.pumpAndSettle();

    // Now tap Reset button in AppBar
    final resetButton = find.byTooltip('Reset Data Tiruan');
    expect(resetButton, findsOneWidget);
    await tester.tap(resetButton);
    await tester.pumpAndSettle();

    expect(find.text('Data tiruan konfirmasi kategori berhasil di-reset'),
        findsOneWidget);
  });
}
