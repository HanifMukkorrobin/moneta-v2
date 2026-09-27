import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/models/category_confirmation_item.dart';
import 'package:moneta/models/transaction_item.dart';
import 'package:moneta/screens/category_confirmation/widgets/category_confirmation_card.dart';
import 'package:moneta/screens/category_confirmation/widgets/category_picker_sheet.dart';
import 'package:moneta/screens/category_confirmation/widgets/frequent_category_suggestions.dart';
import 'package:moneta/state/app_state.dart';
import 'package:moneta/theme/app_theme.dart';

void main() {
  setUp(() {
    AppState.instance.resetToDefault();
  });

  void setupScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('AppState Frequently Used Categories Unit Tests', () {
    test('calculates category frequencies and orders by count descending', () {
      final state = AppState.instance;

      // In initial mock state:
      // 'Makan & Minuman' has transactions tx_1 and tx_3 (count = 2)
      // 'Transportasi' has transaction tx_2 (count = 1)
      final expenseFrequent = state.getFrequentlyUsedCategories(type: 'expense');

      expect(expenseFrequent, isNotEmpty);
      expect(expenseFrequent.first.name, equals('Makan & Minuman'));
      expect(expenseFrequent.first.count, equals(2));

      expect(expenseFrequent[1].name, equals('Transportasi'));
      expect(expenseFrequent[1].count, equals(1));
    });

    test('adding new transactions dynamically updates frequent category ranks', () {
      final state = AppState.instance;

      // Add 3 transactions for 'Belanja'
      for (int i = 0; i < 3; i++) {
        state.addManualTransaction(
          TransactionItem(
            id: 'tx_belanja_$i',
            note: 'Belanja $i',
            amount: 50000,
            type: 'expense',
            category: 'Belanja',
            occurredAt: DateTime.now(),
          ),
        );
      }

      final expenseFrequent = state.getFrequentlyUsedCategories(type: 'expense');

      // Now 'Belanja' should have count 4 (1 initial + 3 added) and be the #1 most frequent category
      expect(expenseFrequent.first.name, equals('Belanja'));
      expect(expenseFrequent.first.count, equals(4));
    });

    test('getFrequentCategoryNames returns string names list', () {
      final state = AppState.instance;
      final names = state.getFrequentCategoryNames(type: 'expense', limit: 3);

      expect(names.length, equals(3));
      expect(names, contains('Makan & Minuman'));
      expect(names, contains('Transportasi'));
    });
  });

  group('FrequentCategorySuggestions Widget Tests', () {
    testWidgets('renders title, badge, and interactive suggestion chips',
        (WidgetTester tester) async {
      setupScreen(tester);

      String? selected;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: FrequentCategorySuggestions(
                type: 'expense',
                selectedCategory: 'Transportasi',
                onCategorySelected: (cat) => selected = cat,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title and badge
      expect(find.text('Sering Dipakai'), findsOneWidget);
      expect(find.text('Saran Cepat'), findsOneWidget);

      // Verify chips render formatted with count
      expect(find.textContaining('Makan & Minuman (2x)'), findsOneWidget);
      expect(find.textContaining('Transportasi (1x)'), findsOneWidget);

      // Tap 'Makan & Minuman' chip
      await tester.tap(find.textContaining('Makan & Minuman (2x)'));
      await tester.pumpAndSettle();

      expect(selected, equals('Makan & Minuman'));
    });

    testWidgets('renders income frequent categories properly',
        (WidgetTester tester) async {
      setupScreen(tester);

      String? selected;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: FrequentCategorySuggestions(
                type: 'income',
                onCategorySelected: (cat) => selected = cat,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sering Dipakai'), findsOneWidget);
      // Income categories should appear
      expect(find.textContaining('Gaji'), findsOneWidget);

      await tester.tap(find.textContaining('Gaji'));
      await tester.pumpAndSettle();

      expect(selected, equals('Gaji'));
    });
  });

  group('CategoryPickerSheet Frequent Suggestions Integration', () {
    testWidgets('displays frequent suggestions and allows selection',
        (WidgetTester tester) async {
      setupScreen(tester);

      String? chosenCategory;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: CategoryPickerSheet(
              initialCategory: 'Transportasi',
              initialType: 'expense',
              onSelected: (cat, _, __) => chosenCategory = cat,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Frequent suggestions header should be visible
      expect(find.text('Sering Dipakai'), findsOneWidget);

      // Tap 'Makan & Minuman' in frequent suggestions
      final frequentChip = find.textContaining('Makan & Minuman (2x)');
      expect(frequentChip, findsOneWidget);
      await tester.tap(frequentChip);
      await tester.pumpAndSettle();

      // Tap 'Terapkan Kategori'
      await tester.tap(find.text('Terapkan Kategori'));
      await tester.pumpAndSettle();

      expect(chosenCategory, equals('Makan & Minuman'));
    });

    testWidgets('hides frequent suggestions when searching in CategoryPickerSheet',
        (WidgetTester tester) async {
      setupScreen(tester);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: CategoryPickerSheet(
              initialCategory: 'Transportasi',
              initialType: 'expense',
              onSelected: (_, __, ___) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sering Dipakai'), findsOneWidget);

      // Search for something
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Belanja');
      await tester.pumpAndSettle();

      // Frequent suggestions row should hide to prioritize search results
      expect(find.text('Sering Dipakai'), findsNothing);
    });
  });

  group('CategoryConfirmationCard Frequent Suggestions Integration', () {
    testWidgets('displays frequent suggestions on confirmation card and updates category',
        (WidgetTester tester) async {
      setupScreen(tester);

      String? altSelected;

      final item = CategoryConfirmationItem(
        id: 'item_conf_test',
        rawSentence: 'Beli bensin di pom pertamina 50rb',
        amount: 50000,
        type: 'expense',
        typeReasoning: 'Bensin merupakan pengeluaran rutin operasional',
        detectedCategory: 'Transportasi',
        alternativeCategories: const [], // Empty alternatives triggers frequent suggestions
        confidenceScore: 0.90,
        aiReasoning: 'Kata kunci bensin menandakan transportasi',
        occurredAt: DateTime.now(),
        isConfirmed: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: CategoryConfirmationCard(
                item: item,
                onConfirm: () {},
                onEditCategory: () {},
                onSelectAlternative: (alt) => altSelected = alt,
                onDelete: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Card should render 'Sering Dipakai' suggestions
      expect(find.text('Sering Dipakai'), findsOneWidget);

      // Tap 'Makan & Minuman' frequent chip
      final makanChip = find.textContaining('Makan & Minuman (2x)');
      expect(makanChip, findsOneWidget);
      await tester.tap(makanChip);
      await tester.pumpAndSettle();

      expect(altSelected, equals('Makan & Minuman'));
    });
  });
}
