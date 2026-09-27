import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/models/debt_item.dart';
import 'package:moneta/screens/hutang/hutang_screen.dart';
import 'package:moneta/screens/hutang/widgets/tambah_hutang_bottom_sheet.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  group('TambahHutangBottomSheet Unit & Validation Tests', () {
    testWidgets('renders all fields, type chips, and quick amount buttons',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          TambahHutangBottomSheet(onAdd: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tambah Hutang / Paylater'), findsOneWidget);
      expect(find.byKey(const Key('input_debt_name')), findsOneWidget);
      expect(find.byKey(const Key('input_debt_total_amount')), findsOneWidget);
      expect(find.byKey(const Key('btn_pick_due_date')), findsOneWidget);
      expect(find.byKey(const Key('switch_partial_paid')), findsOneWidget);
      expect(find.byKey(const Key('input_debt_notes')), findsOneWidget);
      expect(find.byKey(const Key('btn_submit_debt')), findsOneWidget);

      // Verify DebtType chips
      expect(find.byKey(const Key('debt_type_chip_paylater')), findsOneWidget);
      expect(find.byKey(const Key('debt_type_chip_cicilan')), findsOneWidget);
      expect(find.byKey(const Key('debt_type_chip_kartuKredit')), findsOneWidget);
      expect(
          find.byKey(const Key('debt_type_chip_pinjamanPribadi')), findsOneWidget);
      expect(find.byKey(const Key('debt_type_chip_lainnya')), findsOneWidget);

      // Verify quick amount chips
      expect(find.byKey(const Key('chip_quick_amount_100000')), findsOneWidget);
      expect(find.byKey(const Key('chip_quick_amount_500000')), findsOneWidget);
      expect(find.byKey(const Key('chip_quick_amount_1000000')), findsOneWidget);
    });

    testWidgets('validates required name field', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          TambahHutangBottomSheet(onAdd: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      // Submit with completely empty form
      final submitBtn = find.byKey(const Key('btn_submit_debt'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Nama hutang / paylater wajib diisi'), findsOneWidget);
      expect(find.text('Nominal hutang wajib diisi'), findsOneWidget);

      // Enter short name (< 3 chars)
      await tester.enterText(
          find.byKey(const Key('input_debt_name')), 'AB');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Nama minimal 3 karakter'), findsOneWidget);
    });

    testWidgets('validates zero and invalid amount', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          TambahHutangBottomSheet(onAdd: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('input_debt_name')), 'Shopee Paylater');
      await tester.enterText(
          find.byKey(const Key('input_debt_total_amount')), '0');

      final submitBtn = find.byKey(const Key('btn_submit_debt'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Nominal harus lebih dari Rp 0'), findsOneWidget);
    });

    testWidgets('quick amount chips increment total amount input properly',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          TambahHutangBottomSheet(onAdd: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      // Tap +500rb
      final chip500k = find.byKey(const Key('chip_quick_amount_500000'));
      await tester.ensureVisible(chip500k);
      await tester.tap(chip500k);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, '500000'), findsOneWidget);

      // Tap +100rb -> should become 600000
      final chip100k = find.byKey(const Key('chip_quick_amount_100000'));
      await tester.ensureVisible(chip100k);
      await tester.tap(chip100k);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, '600000'), findsOneWidget);
    });

    testWidgets(
        'validates partial payment cannot exceed total amount when switch is active',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          TambahHutangBottomSheet(onAdd: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('input_debt_name')), 'Kredit Motor');
      await tester.enterText(
          find.byKey(const Key('input_debt_total_amount')), '5000000');

      // Turn on partial paid switch
      final switchFinder = find.byKey(const Key('switch_partial_paid'));
      await tester.ensureVisible(switchFinder);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('input_debt_paid_amount')), findsOneWidget);

      // Enter paid amount larger than total (e.g. 6.000.000 > 5.000.000)
      await tester.enterText(
          find.byKey(const Key('input_debt_paid_amount')), '6000000');

      final submitBtn = find.byKey(const Key('btn_submit_debt'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(
          find.text('Jumlah terbayar tidak boleh melebihi total hutang'),
          findsOneWidget);
    });

    testWidgets('submits valid debt with callback data',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      DebtItem? submittedDebt;

      await tester.pumpWidget(
        buildTestableWidget(
          TambahHutangBottomSheet(
            onAdd: (debt) {
              submittedDebt = debt;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select Kartu Kredit type
      await tester.tap(find.byKey(const Key('debt_type_chip_kartuKredit')));
      await tester.pumpAndSettle();

      // Fill in details
      await tester.enterText(
          find.byKey(const Key('input_debt_name')), 'Tagihan CC BCA');
      await tester.enterText(
          find.byKey(const Key('input_debt_total_amount')), '1500000');

      // Enable partial paid: 500.000
      await tester.tap(find.byKey(const Key('switch_partial_paid')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('input_debt_paid_amount')), '500000');

      // Add notes
      await tester.enterText(
          find.byKey(const Key('input_debt_notes')), 'Promo cicilan 0% 3 bln');

      final submitBtn = find.byKey(const Key('btn_submit_debt'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(submittedDebt, isNotNull);
      expect(submittedDebt!.name, 'Tagihan CC BCA');
      expect(submittedDebt!.type, DebtType.kartuKredit);
      expect(submittedDebt!.totalAmount, 1500000);
      expect(submittedDebt!.remainingAmount, 1000000);
      expect(submittedDebt!.notes, 'Promo cicilan 0% 3 bln');
      expect(submittedDebt!.isPaid, isFalse);
    });
  });

  group('HutangScreen Add Debt Flow Integration', () {
    testWidgets('tapping FAB opens TambahHutangBottomSheet and adds debt to list',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          const HutangScreen(initialDebts: []),
        ),
      );
      await tester.pumpAndSettle();

      // Tap FAB
      final fab = find.byKey(const Key('btn_add_debt_fab'));
      expect(fab, findsOneWidget);
      await tester.tap(fab);
      await tester.pumpAndSettle();

      expect(find.text('Tambah Hutang / Paylater'), findsOneWidget);

      // Fill in debt
      await tester.enterText(
          find.byKey(const Key('input_debt_name')), 'GoPay Paylater Makanan');
      await tester.enterText(
          find.byKey(const Key('input_debt_total_amount')), '350000');

      final submitBtn = find.byKey(const Key('btn_submit_debt'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Bottom sheet closed, SnackBar shown
      expect(find.byKey(const Key('snackbar_debt_added')), findsOneWidget);
      expect(find.textContaining('GoPay Paylater Makanan'), findsWidgets);
      expect(find.text('1 Tagihan Aktif'), findsOneWidget);
    });

    testWidgets('tapping AppBar add button also opens TambahHutangBottomSheet',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          const HutangScreen(initialDebts: []),
        ),
      );
      await tester.pumpAndSettle();

      final appbarBtn = find.byKey(const Key('btn_add_debt_appbar'));
      expect(appbarBtn, findsOneWidget);
      await tester.tap(appbarBtn);
      await tester.pumpAndSettle();

      expect(find.text('Tambah Hutang / Paylater'), findsOneWidget);

      // Close via close button
      await tester.tap(find.byKey(const Key('btn_close_debt_sheet')));
      await tester.pumpAndSettle();

      expect(find.text('Tambah Hutang / Paylater'), findsNothing);
    });
  });
}
