import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/models/transaction_item.dart';
import 'package:moneta/screens/category_management/manage_categories_screen.dart';
import 'package:moneta/state/app_state.dart';

Widget createTestWidget() {
  return const MaterialApp(
    home: ManageCategoriesScreen(),
  );
}

void main() {
  group('ManageCategoriesScreen Widget Tests', () {
    setUp(() {
      AppState.instance.resetToDefault();
    });

    testWidgets('renders category stats, search bar, and initial categories', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify app bar title
      expect(find.text('Kelola Kategori Sendiri'), findsOneWidget);

      // Verify stats overview
      expect(find.textContaining('Kategori Sendiri •'), findsOneWidget);
      expect(find.text('+ Buat'), findsOneWidget);

      // Verify search field
      expect(find.widgetWithText(TextField, 'Cari kategori...'), findsOneWidget);

      // Verify categories appear (both default and custom)
      expect(find.text('Makan & Minuman'), findsOneWidget);
      expect(find.text('Gym & Fitness'), findsOneWidget);
      expect(find.text('Bawaan'), findsWidgets);
    });

    testWidgets('filters categories by filter chips and search text', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap 'Kategori Sendiri (...)' choice chip
      final customFilterFinder = find.byWidgetPredicate((widget) =>
          widget is ChoiceChip &&
          widget.label is Text &&
          (widget.label as Text).data!.startsWith('Kategori Sendiri'));
      expect(customFilterFinder, findsOneWidget);
      await tester.tap(customFilterFinder);
      await tester.pumpAndSettle();

      // Should show custom categories and not default ones
      expect(find.text('Gym & Fitness'), findsOneWidget);
      expect(find.text('Makan & Minuman'), findsNothing);

      // Search for 'Skincare'
      await tester.enterText(find.widgetWithText(TextField, 'Cari kategori...'), 'Skincare');
      await tester.pumpAndSettle();

      expect(find.text('Skincare & Perawatan'), findsOneWidget);
      expect(find.text('Gym & Fitness'), findsNothing);
    });

    testWidgets('adds a new custom category successfully', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap floating action button
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Verify bottom sheet title
      expect(find.text('Tambah Kategori Sendiri'), findsOneWidget);

      // Enter category name
      final nameField = find.widgetWithText(TextField, 'Contoh: Gym, Skincare, Hobi Kamera');
      await tester.enterText(nameField, 'Hobi & Game');
      await tester.pumpAndSettle();

      // Tap 'Simpan Kategori'
      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan Kategori'));
      await tester.pumpAndSettle();

      // Should close sheet and show the new category
      expect(find.text('Hobi & Game'), findsOneWidget);
      expect(AppState.instance.categories.any((c) => c.name == 'Hobi & Game'), isTrue);
      expect(find.textContaining('berhasil ditambahkan'), findsOneWidget);
    });

    testWidgets('edits an existing custom category', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Filter to custom categories to easily locate 'Gym & Fitness'
      final customFilterFinder = find.byWidgetPredicate((widget) =>
          widget is ChoiceChip &&
          widget.label is Text &&
          (widget.label as Text).data!.startsWith('Kategori Sendiri'));
      await tester.tap(customFilterFinder);
      await tester.pumpAndSettle();

      expect(find.text('Gym & Fitness'), findsOneWidget);

      // Tap edit icon on 'Gym & Fitness'
      final editButton = find.widgetWithIcon(IconButton, Icons.edit_outlined).first;
      await tester.tap(editButton);
      await tester.pumpAndSettle();

      // Verify dialog title
      expect(find.text('Ubah Nama Kategori'), findsOneWidget);

      // Change name
      final nameField = find.widgetWithText(TextField, 'Gym & Fitness');
      await tester.enterText(nameField, 'Gym & Wellness');
      await tester.pumpAndSettle();

      // Tap 'Simpan'
      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
      await tester.pumpAndSettle();

      // Check updated name
      expect(find.text('Gym & Wellness'), findsOneWidget);
      expect(AppState.instance.categories.any((c) => c.name == 'Gym & Wellness'), isTrue);
    });

    testWidgets('deletes a custom category and warns if used', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // First add a custom category and assign a transaction to it
      AppState.instance.addCustomCategory(
        'Kategori Test Hapus',
        type: 'expense',
        icon: Icons.delete,
        color: Colors.red,
      );
      AppState.instance.addManualTransaction(
        TransactionItem(
          id: 'test_tx_hapus',
          note: 'Transaksi uji hapus',
          amount: 25000,
          type: 'expense',
          category: 'Kategori Test Hapus',
          occurredAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Filter to custom categories
      final customFilterFinder = find.byWidgetPredicate((widget) =>
          widget is ChoiceChip &&
          widget.label is Text &&
          (widget.label as Text).data!.startsWith('Kategori Sendiri'));
      await tester.tap(customFilterFinder);
      await tester.pumpAndSettle();

      expect(find.text('Kategori Test Hapus'), findsOneWidget);

      // Tap delete icon
      final deleteButtons = find.widgetWithIcon(IconButton, Icons.delete_outline_rounded);
      await tester.tap(deleteButtons.last);
      await tester.pumpAndSettle();

      // Confirm dialog appears
      expect(find.text('Hapus Kategori Sendiri?'), findsOneWidget);
      expect(find.textContaining('dialihkan ke kategori "Lainnya"'), findsOneWidget);

      // Confirm deletion
      await tester.tap(find.widgetWithText(ElevatedButton, 'Hapus'));
      await tester.pumpAndSettle();

      // Category should be deleted
      expect(AppState.instance.categories.any((c) => c.name == 'Kategori Test Hapus'), isFalse);
      expect(find.text('Kategori Test Hapus'), findsNothing);

      // Transaction's category should now be 'Lainnya'
      final updatedTx = AppState.instance.allTransactions.firstWhere((t) => t.note == 'Transaksi uji hapus');
      expect(updatedTx.category, 'Lainnya');
    });
  });

  group('AppState Category Management Unit Tests', () {
    late AppState state;

    setUp(() {
      state = AppState.instance;
      state.resetToDefault();
    });

    test('addCustomCategory prevents duplicates case-insensitively', () {
      final initialCount = state.categories.length;
      final added = state.addCustomCategory(
        'makan & minuman', // exists in defaults
        type: 'expense',
        icon: Icons.fastfood,
        color: Colors.orange,
      );

      expect(added, isFalse);
      expect(state.categories.length, initialCount);

      final addedNew = state.addCustomCategory(
        'Investasi Emas',
        type: 'expense',
        icon: Icons.monetization_on,
        color: Colors.amber,
      );
      expect(addedNew, isTrue);
      expect(state.categories.any((c) => c.name == 'Investasi Emas'), isTrue);
    });

    test('updateCategory renames transactions using old category name', () {
      state.addCustomCategory(
        'Streaming Musik',
        type: 'expense',
        icon: Icons.music_note,
        color: Colors.purple,
      );
      state.addManualTransaction(
        TransactionItem(
          id: 'test_tx_music',
          note: 'Langganan Spotify',
          amount: 54000,
          type: 'expense',
          category: 'Streaming Musik',
          occurredAt: DateTime.now(),
        ),
      );

      final cat = state.categories.firstWhere((c) => c.name == 'Streaming Musik');
      final updated = state.updateCategory(
        cat.id,
        'Streaming Audio & Musik',
        icon: Icons.headphones,
        color: Colors.deepPurple,
      );

      expect(updated, isTrue);
      final tx = state.allTransactions.firstWhere((t) => t.note == 'Langganan Spotify');
      expect(tx.category, 'Streaming Audio & Musik');
    });

    test('deleteCategory reassigns all matching transactions to Lainnya', () {
      state.addCustomCategory(
        'Laundry Kiloan',
        type: 'expense',
        icon: Icons.local_laundry_service,
        color: Colors.blue,
      );
      state.addManualTransaction(
        TransactionItem(
          id: 'test_tx_laundry',
          note: 'Cuci baju seminggu',
          amount: 30000,
          type: 'expense',
          category: 'Laundry Kiloan',
          occurredAt: DateTime.now(),
        ),
      );

      final cat = state.categories.firstWhere((c) => c.name == 'Laundry Kiloan');
      final deleted = state.deleteCategory(cat.id);

      expect(deleted, isTrue);
      expect(state.categories.any((c) => c.id == cat.id), isFalse);

      final tx = state.allTransactions.firstWhere((t) => t.note == 'Cuci baju seminggu');
      expect(tx.category, 'Lainnya');
    });
  });
}
