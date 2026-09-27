import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/models/category_confirmation_item.dart';
import 'package:moneta/screens/category_confirmation/category_confirmation_screen.dart';
import 'package:moneta/screens/category_confirmation/widgets/category_confirmation_card.dart';
import 'package:moneta/screens/category_confirmation/widgets/guessed_category_badge.dart';
import 'package:moneta/state/app_state.dart';
import 'package:moneta/theme/app_theme.dart';

void main() {
  setUp(() {
    AppState.instance.resetToDefault();
  });

  group('GuessedCategoryBadge fallback handling', () {
    testWidgets('renders fallback warning when category is empty or Belum Dikategorikan in compact mode',
        (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: GuessedCategoryBadge(
              category: 'Belum Dikategorikan',
              isExpense: true,
              confidenceScore: 0.35,
              isCompact: true,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      // Verify fallback indicators
      expect(find.text('Belum Dikategorikan'), findsOneWidget);
      expect(find.text('Tebakan Gagal'), findsOneWidget);
      expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);

      await tester.tap(find.text('Belum Dikategorikan'));
      expect(tapped, isTrue);
    });

    testWidgets('renders fallback warning in detailed mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: GuessedCategoryBadge(
              category: '',
              isExpense: true,
              confidenceScore: 0.20,
              isCompact: false,
              reasoning: 'Tebakan kategori tidak menemukan kata kunci',
            ),
          ),
        ),
      );

      expect(find.text('Tebakan Kategori Gagal'), findsOneWidget);
      expect(find.text('Kategori Kosong'), findsOneWidget);
      expect(find.text('Perlu Dipilih'), findsOneWidget);
      expect(find.text('Tebakan kategori tidak menemukan kata kunci'),
          findsOneWidget);
    });
  });

  group('CategoryConfirmationCard fallback UI', () {
    testWidgets('displays quick fallback category selection chips',
        (WidgetTester tester) async {
      String? selectedAlternative;

      final item = CategoryConfirmationItem(
        id: 'fallback_card_1',
        rawSentence: 'Keluar uang 75rb buat tadi',
        detectedCategory: 'Belum Dikategorikan',
        confidenceScore: 0.30,
        aiReasoning: 'Tebakan gagal',
        type: 'expense',
        typeReasoning: 'Pengeluaran',
        amount: 75000,
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
              onSelectAlternative: (alt) => selectedAlternative = alt,
              onDelete: () {},
            ),
          ),
        ),
      );

      // Verify quick fallback prompt
      expect(
          find.text('Pilih kategori langsung (Fallback Cepat):'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Makan & Minuman'), findsWidgets);
      expect(find.widgetWithText(ActionChip, 'Transportasi'), findsWidgets);

      // Tap on Transportasi
      await tester.tap(find.widgetWithText(ActionChip, 'Transportasi').first);
      expect(selectedAlternative, equals('Transportasi'));
    });
  });

  group('CategoryConfirmationScreen empty category fallback', () {
    testWidgets('filtering by Perlu Kategori shows only unclassified items',
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

      // Find Perlu Kategori filter chip
      final unclassifiedFilter =
          find.widgetWithText(FilterChip, 'Perlu Kategori (1)');
      expect(unclassifiedFilter, findsOneWidget);

      await tester.tap(unclassifiedFilter);
      await tester.pumpAndSettle();

      // conf_7 should be visible
      expect(find.text('Transfer bayar urusan tadi siang 75rb'), findsOneWidget);
      // Confirmed or classified items should not appear
      expect(find.text('Kopi kenangan mantan large 24rb'), findsNothing);
    });

    testWidgets('confirming unclassified item automatically defaults to Lainnya',
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

      // Filter to Perlu Kategori
      final unclassifiedFilter =
          find.widgetWithText(FilterChip, 'Perlu Kategori (1)');
      await tester.tap(unclassifiedFilter);
      await tester.pumpAndSettle();

      // Tap Konfirmasi button on this card
      final confirmButton = find.widgetWithText(ElevatedButton, 'Konfirmasi').first;
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      // SnackBar should notify about auto-defaulting to Lainnya
      expect(
        find.textContaining('Kategori belum dipilih. Disimpan sebagai "Lainnya"'),
        findsOneWidget,
      );
    });
  });
}
