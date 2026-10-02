import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/models/debt_item.dart';
import 'package:moneta/screens/hutang/hutang_screen.dart';
import 'package:moneta/screens/hutang/widgets/pelunasan_dialog.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  group('Aksi Tandai Lunas dan Undo Action Tests', () {
    final now = DateTime.now();

    testWidgets('marking debt as paid updates card state and allows Undo',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final initial = [
        DebtItem(
          id: 'test_debt_undo',
          name: 'Tagihan Paylater Kopi',
          totalAmount: 150000,
          remainingAmount: 150000,
          dueDate: now.add(const Duration(days: 4)),
          status: 'active',
          type: DebtType.paylater,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(home: HutangScreen(initialDebts: initial)),
      );
      await tester.pumpAndSettle();

      final markPaidBtn =
          find.byKey(const Key('btn_mark_paid_test_debt_undo'));
      expect(markPaidBtn, findsOneWidget);

      await tester.tap(markPaidBtn);
      await tester.pumpAndSettle();

      // Debt is now paid
      expect(find.byKey(const Key('paid_indicator_test_debt_undo')),
          findsOneWidget);
      expect(find.byKey(const Key('btn_undo_mark_paid')), findsOneWidget);
      expect(find.text('0 Tagihan Aktif'), findsOneWidget);

      // Tap Undo
      await tester.tap(find.byKey(const Key('btn_undo_mark_paid')));
      await tester.pumpAndSettle();

      // Debt reverted to active
      expect(find.byKey(const Key('btn_mark_paid_test_debt_undo')),
          findsOneWidget);
      expect(find.text('1 Tagihan Aktif'), findsOneWidget);
    });

    testWidgets('reopening a paid debt reactivates it cleanly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final initial = [
        DebtItem(
          id: 'test_debt_reopen',
          name: 'Tagihan Sudah Lunas',
          totalAmount: 250000,
          remainingAmount: 0,
          dueDate: now.subtract(const Duration(days: 2)),
          status: 'paid',
          type: DebtType.cicilan,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(home: HutangScreen(initialDebts: initial)),
      );
      await tester.pumpAndSettle();

      // Switch to Lunas tab
      await tester.tap(find.byKey(const Key('filter_debt_paid')));
      await tester.pumpAndSettle();

      // Find Aktifkan Lagi button
      final reopenBtn =
          find.byKey(const Key('btn_reopen_debt_test_debt_reopen'));
      expect(reopenBtn, findsOneWidget);

      await tester.tap(reopenBtn);
      await tester.pumpAndSettle();

      // SnackBar shown and item moved back to active
      expect(find.byKey(const Key('snackbar_debt_reopened_test_debt_reopen')),
          findsOneWidget);
      expect(find.text('1 Tagihan Aktif'), findsOneWidget);
    });
  });

  group('PelunasanDialog Settlement Modal Tests', () {
    final now = DateTime.now();
    final testDebt = DebtItem(
      id: 'dialog_debt_1',
      name: 'Cicilan HP',
      totalAmount: 3000000,
      remainingAmount: 1500000,
      dueDate: now.add(const Duration(days: 5)),
      status: 'active',
      type: DebtType.cicilan,
    );

    testWidgets('full payment mode submits full remaining amount',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      double? submittedAmount;
      bool? isFullSubmitted;

      await tester.pumpWidget(
        buildTestableWidget(
          PelunasanDialog(
            debt: testDebt,
            onConfirm: (amt, full, _) {
              submittedAmount = amt;
              isFullSubmitted = full;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pelunasan Tagihan'), findsOneWidget);
      expect(find.text('Lunasi Penuh (Rp 1.500.000)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_confirm_pelunasan')));
      await tester.pumpAndSettle();

      expect(submittedAmount, 1500000);
      expect(isFullSubmitted, isTrue);
    });

    testWidgets('partial payment mode allows custom amount with validation',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      double? submittedAmount;
      bool? isFullSubmitted;

      await tester.pumpWidget(
        buildTestableWidget(
          PelunasanDialog(
            debt: testDebt,
            onConfirm: (amt, full, _) {
              submittedAmount = amt;
              isFullSubmitted = full;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to partial payment
      await tester.tap(find.byKey(const Key('radio_partial_payment')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('input_partial_paid_amount')), findsOneWidget);

      // Enter amount exceeding remaining (e.g. 2.000.000 > 1.500.000)
      await tester.enterText(
          find.byKey(const Key('input_partial_paid_amount')), '2000000');
      await tester.tap(find.byKey(const Key('btn_confirm_pelunasan')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('error_pelunasan_text')), findsOneWidget);
      expect(submittedAmount, isNull);

      // Enter valid partial amount (e.g. 500.000)
      await tester.enterText(
          find.byKey(const Key('input_partial_paid_amount')), '500000');
      await tester.tap(find.byKey(const Key('btn_confirm_pelunasan')));
      await tester.pumpAndSettle();

      expect(submittedAmount, 500000);
      expect(isFullSubmitted, isFalse);
    });
  });

  group('Daftar Lunas Tab & Banner Tests', () {
    final now = DateTime.now();

    testWidgets('Daftar Lunas tab displays summary banner and paid cards',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final debts = [
        DebtItem(
          id: 'paid_1',
          name: 'Talangan Pulsa',
          totalAmount: 100000,
          remainingAmount: 0,
          dueDate: now.subtract(const Duration(days: 3)),
          status: 'paid',
          type: DebtType.pinjamanPribadi,
        ),
        DebtItem(
          id: 'paid_2',
          name: 'Kredivo Beli Sepatu',
          totalAmount: 400000,
          remainingAmount: 0,
          dueDate: now.subtract(const Duration(days: 10)),
          status: 'paid',
          type: DebtType.paylater,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(home: HutangScreen(initialDebts: debts)),
      );
      await tester.pumpAndSettle();

      // Tap Lunas filter tab
      await tester.tap(find.byKey(const Key('filter_debt_paid')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('daftar_lunas_summary_banner')),
          findsOneWidget);
      expect(find.text('Daftar Lunas: 2 Tagihan Selesai'), findsOneWidget);
      expect(find.byKey(const Key('debt_card_paid_1')), findsOneWidget);
      expect(find.byKey(const Key('debt_card_paid_2')), findsOneWidget);
    });

    testWidgets('shows empty_paid_debts when Lunas tab has no paid records',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final onlyActive = [
        DebtItem(
          id: 'active_only_1',
          name: 'Belum Lunas',
          totalAmount: 500000,
          remainingAmount: 500000,
          dueDate: now.add(const Duration(days: 5)),
          status: 'active',
          type: DebtType.paylater,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(home: HutangScreen(initialDebts: onlyActive)),
      );
      await tester.pumpAndSettle();

      // Tap Lunas tab
      await tester.tap(find.byKey(const Key('filter_debt_paid')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('empty_paid_debts')), findsOneWidget);
      expect(find.text('Belum Ada Catatan Hutang Lunas'), findsOneWidget);
    });
  });
}
