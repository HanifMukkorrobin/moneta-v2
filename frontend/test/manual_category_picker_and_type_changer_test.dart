import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/models/category_confirmation_item.dart';
import 'package:moneta/screens/category_confirmation/category_confirmation_screen.dart';
import 'package:moneta/screens/category_confirmation/widgets/category_confirmation_card.dart';
import 'package:moneta/screens/category_confirmation/widgets/category_picker_sheet.dart';
import 'package:moneta/state/app_state.dart';
import 'package:moneta/theme/app_theme.dart';

void main() {
  setUp(() {
    AppState.instance.resetToDefault();
  });

  group('CategoryPickerSheet', () {
    testWidgets('renders type switcher, categories, and allows selection',
        (WidgetTester tester) async {
      String? selectedCategory;
      String? selectedType;
      bool? isCustom;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: CategoryPickerSheet(
              initialCategory: 'Makan & Minuman',
              initialType: 'expense',
              onSelected: (cat, type, custom) {
                selectedCategory = cat;
                selectedType = type;
                isCustom = custom;
              },
            ),
          ),
        ),
      );

      // Verify title & type switcher
      expect(find.text('Pemilih Kategori Manual'), findsOneWidget);
      expect(find.text('Pengeluaran'), findsOneWidget);
      expect(find.text('Pemasukan'), findsOneWidget);

      // Verify default expense categories
      expect(find.text('Makan & Minuman'), findsWidgets);
      expect(find.text('Transportasi'), findsOneWidget);

      // Switch to Pemasukan
      await tester.tap(find.text('Pemasukan'));
      await tester.pumpAndSettle();

      // Income categories should now be visible
      expect(find.text('Gaji'), findsOneWidget);
      expect(find.text('Freelance'), findsOneWidget);

      // Select "Freelance"
      final freelanceChip = find.widgetWithText(ChoiceChip, 'Freelance');
      expect(freelanceChip, findsOneWidget);
      await tester.tap(freelanceChip);
      await tester.pumpAndSettle();

      // Tap Terapkan Kategori
      await tester.tap(find.text('Terapkan Kategori'));
      await tester.pumpAndSettle();

      expect(selectedCategory, equals('Freelance'));
      expect(selectedType, equals('income'));
      expect(isCustom, isFalse);
    });

    testWidgets('search bar filters categories in CategoryPickerSheet',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: CategoryPickerSheet(
              initialCategory: 'Makan & Minuman',
              initialType: 'expense',
              onSelected: (_, __, ___) {},
            ),
          ),
        ),
      );

      // Type "Trans" in search field
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'Trans');
      await tester.pumpAndSettle();

      // Transportasi should be visible, Makan & Minuman should not be in filtered chips
      expect(find.text('Transportasi'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Makan & Minuman'), findsNothing);
    });

    testWidgets('custom category mode allows creating new custom category',
        (WidgetTester tester) async {
      String? selectedCategory;
      bool? isCustom;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: CategoryPickerSheet(
              initialCategory: 'Makan & Minuman',
              initialType: 'expense',
              onSelected: (cat, _, custom) {
                selectedCategory = cat;
                isCustom = custom;
              },
            ),
          ),
        ),
      );

      // Tap "+ Kategori Sendiri"
      await tester.tap(find.text('+ Kategori Sendiri'));
      await tester.pumpAndSettle();

      expect(find.text('Kategori Kustom Baru'), findsOneWidget);

      // Enter custom category name
      final customField = find.byType(TextField);
      await tester.enterText(customField, 'Hobi Fotografi');
      await tester.pumpAndSettle();

      // Tap apply button
      await tester.tap(find.text('Terapkan Kategori'));
      await tester.pumpAndSettle();

      expect(selectedCategory, equals('Hobi Fotografi'));
      expect(isCustom, isTrue);
    });
  });

  group('Ubah jenis di kartu & CategoryConfirmationScreen integration', () {
    testWidgets('tapping type indicator on card toggles between expense and income',
        (WidgetTester tester) async {
      bool toggled = false;

      final item = CategoryConfirmationItem(
        id: 'test_card_1',
        rawSentence: 'Beli kopi 20rb',
        detectedCategory: 'Makan & Minuman',
        confidenceScore: 0.95,
        aiReasoning: 'Kata kunci kopi',
        type: 'expense',
        typeReasoning: 'Pengeluaran harian',
        amount: 20000,
        occurredAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: CategoryConfirmationCard(
              item: item,
              onConfirm: () {},
              onEditCategory: () {},
              onSelectAlternative: (_) {},
              onToggleType: () => toggled = true,
              onDelete: () {},
            ),
          ),
        ),
      );

      // Tap type indicator "Pengeluaran"
      expect(find.text('Pengeluaran'), findsOneWidget);
      await tester.tap(find.text('Pengeluaran'));
      expect(toggled, isTrue);
    });

    testWidgets('CategoryConfirmationScreen allows type change on card and opens manual picker',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: AppStateScope(
            notifier: AppState.instance,
            child: const CategoryConfirmationScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap type indicator on first card to toggle from Pengeluaran to Pemasukan
      final pengeluaranIndicator = find.text('Pengeluaran').first;
      await tester.tap(pengeluaranIndicator);
      await tester.pumpAndSettle();

      // SnackBar should confirm type change
      expect(find.textContaining('Jenis transaksi diubah menjadi Pemasukan'),
          findsOneWidget);

      // Now tap "Ubah Kategori" button on that card
      final editButton = find.widgetWithText(OutlinedButton, 'Ubah Kategori').first;
      await tester.tap(editButton);
      await tester.pumpAndSettle();

      // CategoryPickerSheet should open
      expect(find.byType(CategoryPickerSheet), findsOneWidget);
      expect(find.text('Pemilih Kategori Manual'), findsOneWidget);
    });
  });
}
