import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/screens/budget/atur_budget_screen.dart';
import 'package:moneta/screens/budget/widgets/adjust_allocation_percentages_sheet.dart';

void main() {
  group('AdjustAllocationPercentagesSheet Tests', () {
    testWidgets('renders all controls, initial values, presets, and validation indicator', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AdjustAllocationPercentagesSheet.show(
                  context,
                  totalBudget: 6000000,
                  initialNeedsPct: 50,
                  initialSavingsPct: 30,
                  initialFunPct: 20,
                  onSave: (_, __, ___) {},
                ),
                child: const Text('Buka Alokasi'),
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Buka Alokasi'));
      await tester.pumpAndSettle();

      // Verify sheet title & total budget context
      expect(find.text('Atur Persentase Alokasi'), findsOneWidget);
      expect(find.text('Plafon Budget: Rp 6.000.000'), findsOneWidget);

      // Presets
      expect(find.byKey(const Key('preset_allocation_50_30_20')), findsOneWidget);
      expect(find.byKey(const Key('preset_allocation_40_40_20')), findsOneWidget);
      expect(find.byKey(const Key('preset_allocation_60_25_15')), findsOneWidget);
      expect(find.byKey(const Key('preset_allocation_35_50_15')), findsOneWidget);

      // Validation box shows 100% valid state
      expect(find.byKey(const Key('allocation_validation_box')), findsOneWidget);
      expect(find.textContaining('Total Alokasi 100% (Sempurna & Siap Digunakan)'), findsOneWidget);

      // 3 Buckets
      expect(find.text('Kebutuhan Pokok'), findsOneWidget);
      expect(find.text('Tabungan & Investasi'), findsOneWidget);
      expect(find.text('Hiburan & Keinginan'), findsOneWidget);

      // Save and Reset buttons
      expect(find.byKey(const Key('save_allocation_button')), findsOneWidget);
      expect(find.byKey(const Key('reset_allocation_button')), findsOneWidget);
    });

    testWidgets('preset buttons update percentages immediately to corresponding template', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      double? savedNeeds;
      double? savedSavings;
      double? savedFun;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AdjustAllocationPercentagesSheet.show(
                  context,
                  totalBudget: 6000000,
                  initialNeedsPct: 50,
                  initialSavingsPct: 30,
                  initialFunPct: 20,
                  onSave: (n, s, f) {
                    savedNeeds = n;
                    savedSavings = s;
                    savedFun = f;
                  },
                ),
                child: const Text('Buka Alokasi'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka Alokasi'));
      await tester.pumpAndSettle();

      // Tap preset 40/40/20
      await tester.tap(find.byKey(const Key('preset_allocation_40_40_20')));
      await tester.pumpAndSettle();

      // Verify validation is valid 100%
      expect(find.textContaining('Total Alokasi 100%'), findsOneWidget);

      // Save
      final saveBtn = find.byKey(const Key('save_allocation_button'));
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(savedNeeds, 40.0);
      expect(savedSavings, 40.0);
      expect(savedFun, 20.0);
      expect(find.byType(AdjustAllocationPercentagesSheet), findsNothing);
    });

    testWidgets('validates when sum is less than 100% and displays remaining deficit', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AdjustAllocationPercentagesSheet.show(
                  context,
                  totalBudget: 6000000,
                  initialNeedsPct: 50,
                  initialSavingsPct: 30,
                  initialFunPct: 20,
                  onSave: (_, __, ___) {},
                ),
                child: const Text('Buka Alokasi'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka Alokasi'));
      await tester.pumpAndSettle();

      // Decrement needs by 5% (50 -> 45) -> total = 95%
      await tester.tap(find.byKey(const Key('stepper_minus_needs')));
      await tester.pumpAndSettle();

      // Validation box shows deficit
      expect(find.textContaining('Total alokasi 95%. Kurang 5% lagi untuk mencapai 100%.'), findsOneWidget);

      // Attempt to save invalid allocation shows SnackBar
      final saveBtn = find.byKey(const Key('save_allocation_button'));
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Total persentase harus 100%. Masih kurang 5%.'), findsOneWidget);
      // Sheet should remain open
      expect(find.byType(AdjustAllocationPercentagesSheet), findsOneWidget);
    });

    testWidgets('validates when sum is greater than 100% and displays excess error', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AdjustAllocationPercentagesSheet.show(
                  context,
                  totalBudget: 6000000,
                  initialNeedsPct: 50,
                  initialSavingsPct: 30,
                  initialFunPct: 20,
                  onSave: (_, __, ___) {},
                ),
                child: const Text('Buka Alokasi'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka Alokasi'));
      await tester.pumpAndSettle();

      // Increment savings by 5% (30 -> 35) -> total = 105%
      await tester.tap(find.byKey(const Key('stepper_plus_savings')));
      await tester.pumpAndSettle();

      // Validation box shows excess
      expect(find.textContaining('Total alokasi 105%. Kelebihan 5% dari batas 100%.'), findsOneWidget);

      // Attempt to save invalid allocation shows SnackBar
      final saveBtn = find.byKey(const Key('save_allocation_button'));
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Total persentase harus 100%. Melebihi batas sebesar 5%.'), findsOneWidget);
      // Sheet should remain open
      expect(find.byType(AdjustAllocationPercentagesSheet), findsOneWidget);
    });

    testWidgets('reset button restores 50/30/20 allocation', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AdjustAllocationPercentagesSheet.show(
                  context,
                  totalBudget: 6000000,
                  initialNeedsPct: 60,
                  initialSavingsPct: 25,
                  initialFunPct: 15,
                  onSave: (_, __, ___) {},
                ),
                child: const Text('Buka Alokasi'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka Alokasi'));
      await tester.pumpAndSettle();

      // Tap Reset button
      final resetBtn = find.byKey(const Key('reset_allocation_button'));
      await tester.ensureVisible(resetBtn);
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Total Alokasi 100%'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('30%'), findsOneWidget);
      expect(find.text('20%'), findsOneWidget);
    });
  });

  group('AturBudgetScreen Integration with AdjustAllocationPercentagesSheet', () {
    testWidgets('tapping Atur % opens AdjustAllocationPercentagesSheet and applies new allocation', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      await tester.pumpWidget(
        const MaterialApp(
          home: AturBudgetScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state is 50/30/20
      expect(find.text('50% dari Total Budget'), findsOneWidget);
      expect(find.text('30% dari Total Budget'), findsOneWidget);
      expect(find.text('20% dari Total Budget'), findsOneWidget);

      // Find and tap Atur % button
      final adjustFinder = find.byKey(const Key('adjust_percentages_button'));
      await tester.ensureVisible(adjustFinder);
      await tester.tap(adjustFinder);
      await tester.pumpAndSettle();

      // Verify sheet opened
      expect(find.byType(AdjustAllocationPercentagesSheet), findsOneWidget);

      // Tap preset 60/25/15
      await tester.tap(find.byKey(const Key('preset_allocation_60_25_15')));
      await tester.pumpAndSettle();

      // Tap Simpan Alokasi
      final saveBtn = find.byKey(const Key('save_allocation_button'));
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify sheet is closed
      expect(find.byType(AdjustAllocationPercentagesSheet), findsNothing);

      // Verify AturBudgetScreen updated with new percentages
      expect(find.text('60% dari Total Budget'), findsOneWidget);
      expect(find.text('25% dari Total Budget'), findsOneWidget);
      expect(find.text('15% dari Total Budget'), findsOneWidget);

      // Verify success snackbar
      expect(find.textContaining('Persentase alokasi berhasil diperbarui: 60% / 25% / 15%'), findsOneWidget);
    });
  });
}
