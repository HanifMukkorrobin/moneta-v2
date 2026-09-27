import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/models/transaction_item.dart';
import 'package:moneta/screens/category_confirmation/widgets/guessed_category_badge.dart';
import 'package:moneta/screens/category_confirmation/widgets/transaction_type_indicator.dart';
import 'package:moneta/screens/chat/widgets/transaction_card.dart';
import 'package:moneta/theme/app_theme.dart';

void main() {
  group('TransactionTypeIndicator', () {
    testWidgets('renders expense type with correct label and icon',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TransactionTypeIndicator(
              type: 'expense',
            ),
          ),
        ),
      );

      expect(find.text('Pengeluaran'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_outward_rounded), findsOneWidget);
    });

    testWidgets('renders income type with correct label and icon',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TransactionTypeIndicator(
              type: 'income',
            ),
          ),
        ),
      );

      expect(find.text('Pemasukan'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
    });

    testWidgets('triggers onToggle callback when tapped',
        (WidgetTester tester) async {
      bool toggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionTypeIndicator(
              type: 'expense',
              onToggle: () => toggled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Pengeluaran'));
      expect(toggled, isTrue);
    });

    testWidgets('renders type reasoning when showReasoning is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TransactionTypeIndicator(
              type: 'expense',
              showReasoning: true,
              reasoning: 'Pola pembelian konsumsi harian',
            ),
          ),
        ),
      );

      expect(find.text('Pola pembelian konsumsi harian'), findsOneWidget);
    });
  });

  group('GuessedCategoryBadge', () {
    testWidgets('renders compact badge with category and confidence score',
        (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GuessedCategoryBadge(
              category: 'Makan & Minuman',
              isExpense: true,
              confidenceScore: 0.98,
              isCompact: true,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Makan & Minuman'), findsOneWidget);
      expect(find.text('98% Akurat'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);

      await tester.tap(find.text('Makan & Minuman'));
      expect(tapped, isTrue);
    });

    testWidgets('renders detailed badge with AI reasoning and custom tag',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GuessedCategoryBadge(
              category: 'Skincare',
              isExpense: true,
              confidenceScore: 0.95,
              reasoning: 'Kata kunci skincare cocok dengan perawatan',
              isCustom: true,
              isCompact: false,
            ),
          ),
        ),
      );

      expect(find.text('Tebakan Kategori AI:'), findsOneWidget);
      expect(find.text('Skincare'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
      expect(find.text('95% Akurat'), findsOneWidget);
      expect(find.text('Kata kunci skincare cocok dengan perawatan'),
          findsOneWidget);
    });
  });

  group('TransactionCard integration', () {
    testWidgets('TransactionCard displays type indicator and guessed category badge',
        (WidgetTester tester) async {
      bool typeToggled = false;
      bool categoryChanged = false;

      final tx = TransactionItem(
        id: 'tx_int_1',
        note: 'Makan sate ayam 30rb',
        amount: 30000,
        type: 'expense',
        category: 'Makan & Minuman',
        occurredAt: DateTime.now(),
        confidenceScore: 0.97,
        isConfirmed: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: TransactionCard(
              transaction: tx,
              onConfirm: () {},
              onChangeCategory: () => categoryChanged = true,
              onDelete: () {},
              onToggleType: () => typeToggled = true,
            ),
          ),
        ),
      );

      // Verify type indicator
      expect(find.text('Pengeluaran'), findsOneWidget);
      await tester.tap(find.text('Pengeluaran'));
      expect(typeToggled, isTrue);

      // Verify guessed category badge
      expect(find.text('Makan & Minuman'), findsOneWidget);
      expect(find.text('97% Akurat'), findsOneWidget);
      await tester.tap(find.text('Makan & Minuman'));
      expect(categoryChanged, isTrue);
    });

    testWidgets('does not overflow on narrow mobile screen when confirmed',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final tx = TransactionItem(
        id: 'tx_int_narrow',
        note: 'Makan siang nasi padang dan es teh manis',
        amount: 45000,
        type: 'expense',
        category: 'Makan & Minuman',
        occurredAt: DateTime.now(),
        confidenceScore: 0.95,
        isConfirmed: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: TransactionCard(
              transaction: tx,
              onConfirm: () {},
              onChangeCategory: () {},
              onDelete: () {},
              onToggleType: () {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Makan & Minuman'), findsOneWidget);
      expect(find.text('Tersimpan'), findsOneWidget);
    });
  });
}
