import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/screens/budget/atur_budget_screen.dart';
import 'package:moneta/screens/budget/widgets/edit_budget_limit_sheet.dart';

void main() {
  group('EditBudgetLimitSheet (Form Input Ubah Hapus Batas Budget Bulanan)', () {
    testWidgets('renders input field, quick presets, and simulation preview', (WidgetTester tester) async {
      double? savedAmount;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => EditBudgetLimitSheet.show(
                  context,
                  currentAmount: 6000000,
                  monthLabel: 'September 2026',
                  onSave: (val) => savedAmount = val,
                ),
                child: const Text('Buka Form'),
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Buka Form'));
      await tester.pumpAndSettle();

      expect(find.text('Ubah Batas Budget Bulanan'), findsOneWidget);
      expect(find.text('Periode September 2026'), findsOneWidget);
      expect(find.byKey(const Key('budget_amount_input')), findsOneWidget);
      expect(find.text('Pilihan Cepat'), findsOneWidget);

      // Presets
      expect(find.byKey(const Key('preset_chip_3000000')), findsOneWidget);
      expect(find.byKey(const Key('preset_chip_5000000')), findsOneWidget);
      expect(find.byKey(const Key('preset_chip_7500000')), findsOneWidget);
      expect(find.byKey(const Key('preset_chip_10000000')), findsOneWidget);

      // Simulation preview
      expect(find.text('Simulasi Alokasi 50/30/20:'), findsOneWidget);

      // Tap preset 7.500.000
      await tester.tap(find.byKey(const Key('preset_chip_7500000')));
      await tester.pumpAndSettle();

      expect(find.text('7500000'), findsOneWidget);

      // Save
      await tester.tap(find.byKey(const Key('save_budget_button')));
      await tester.pumpAndSettle();

      expect(savedAmount, 7500000);
      expect(find.byType(EditBudgetLimitSheet), findsNothing);
    });

    testWidgets('validates zero or empty input amount', (WidgetTester tester) async {
      double? savedAmount;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => EditBudgetLimitSheet.show(
                  context,
                  currentAmount: 0,
                  monthLabel: 'September 2026',
                  onSave: (val) => savedAmount = val,
                ),
                child: const Text('Buka Form'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka Form'));
      await tester.pumpAndSettle();

      expect(find.text('Tetapkan Budget Bulanan'), findsOneWidget);

      // Attempt to save empty amount
      await tester.tap(find.byKey(const Key('save_budget_button')));
      await tester.pumpAndSettle();

      expect(find.text('Nominal budget harus lebih besar dari Rp 0.'), findsOneWidget);
      expect(savedAmount, isNull);

      // Enter valid amount
      await tester.enterText(find.byKey(const Key('budget_amount_input')), '4500000');
      await tester.pumpAndSettle();

      expect(find.text('Nominal budget harus lebih besar dari Rp 0.'), findsNothing);

      await tester.tap(find.byKey(const Key('save_budget_button')));
      await tester.pumpAndSettle();

      expect(savedAmount, 4500000);
    });

    testWidgets('cancelling delete dialog preserves budget', (WidgetTester tester) async {
      bool deleteCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => EditBudgetLimitSheet.show(
                  context,
                  currentAmount: 5000000,
                  monthLabel: 'September 2026',
                  onSave: (_) {},
                  onDelete: () => deleteCalled = true,
                ),
                child: const Text('Buka Form'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka Form'));
      await tester.pumpAndSettle();

      // Tap Hapus button
      await tester.tap(find.byKey(const Key('delete_budget_button')));
      await tester.pumpAndSettle();

      expect(find.text('Hapus Budget Bulanan?'), findsOneWidget);

      // Tap Batal
      await tester.tap(find.byKey(const Key('cancel_delete_budget_button')));
      await tester.pumpAndSettle();

      expect(find.text('Hapus Budget Bulanan?'), findsNothing);
      expect(deleteCalled, isFalse);
      expect(find.byType(EditBudgetLimitSheet), findsOneWidget);
    });

    testWidgets('confirming delete dialog deletes budget', (WidgetTester tester) async {
      bool deleteCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => EditBudgetLimitSheet.show(
                  context,
                  currentAmount: 5000000,
                  monthLabel: 'September 2026',
                  onSave: (_) {},
                  onDelete: () => deleteCalled = true,
                ),
                child: const Text('Buka Form'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka Form'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('delete_budget_button')));
      await tester.pumpAndSettle();

      // Confirm Delete
      await tester.tap(find.byKey(const Key('confirm_delete_budget_button')));
      await tester.pumpAndSettle();

      expect(deleteCalled, isTrue);
      expect(find.byType(EditBudgetLimitSheet), findsNothing);
    });

    testWidgets('integrates with AturBudgetScreen to update and delete budget', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AturBudgetScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Initial budget is Rp 6.000.000
      expect(find.text('Rp 6.000.000'), findsOneWidget);

      // 2. Tap Ubah button
      await tester.tap(find.byKey(const Key('edit_budget_button')));
      await tester.pumpAndSettle();

      expect(find.byType(EditBudgetLimitSheet), findsOneWidget);

      // Select Preset Rp 10.000.000
      await tester.tap(find.byKey(const Key('preset_chip_10000000')));
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.byKey(const Key('save_budget_button')));
      await tester.pumpAndSettle();

      // Verify screen updated with Rp 10.000.000
      expect(find.text('Rp 10.000.000'), findsOneWidget);
      expect(find.textContaining('Batas budget berhasil diperbarui'), findsOneWidget);

      // 3. Delete budget
      await tester.tap(find.byKey(const Key('edit_budget_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('delete_budget_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm_delete_budget_button')));
      await tester.pumpAndSettle();

      // Screen now enters empty budget state
      expect(find.byKey(const Key('budget_empty_banner')), findsOneWidget);
      expect(find.text('Belum Ada Budget Bulanan'), findsOneWidget);
      expect(find.text('Batas budget bulanan berhasil dihapus.'), findsOneWidget);
    });
  });
}
