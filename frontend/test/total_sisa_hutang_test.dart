import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/models/debt_item.dart';
import 'package:moneta/screens/hutang/hutang_screen.dart';
import 'package:moneta/screens/hutang/widgets/total_sisa_hutang_card.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  group('TotalSisaHutangCard Unit & Formatting Tests', () {
    final now = DateTime.now();

    final testDebts = [
      DebtItem(
        id: 'debt_calc_1',
        name: 'Paylater Spay',
        totalAmount: 1000000,
        remainingAmount: 450000,
        dueDate: now.add(const Duration(days: 2)),
        status: 'active',
        type: DebtType.paylater,
      ),
      DebtItem(
        id: 'debt_calc_2',
        name: 'Cicilan Laptop',
        totalAmount: 5000000,
        remainingAmount: 2500000,
        dueDate: now.add(const Duration(days: 15)),
        status: 'active',
        type: DebtType.cicilan,
      ),
      DebtItem(
        id: 'debt_calc_3',
        name: 'Kartu Kredit Mandiri',
        totalAmount: 750000,
        remainingAmount: 750000,
        dueDate: now.add(const Duration(days: 1)),
        status: 'active',
        type: DebtType.kartuKredit,
      ),
      DebtItem(
        id: 'debt_calc_4',
        name: 'Pinjaman Sudah Lunas',
        totalAmount: 300000,
        remainingAmount: 0,
        dueDate: now.subtract(const Duration(days: 4)),
        status: 'paid',
        type: DebtType.pinjamanPribadi,
      ),
    ];

    testWidgets('formats total remaining debt accurately in Rupiah',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Total remaining = 450.000 + 2.500.000 + 750.000 = 3.700.000
      await tester.pumpWidget(
        buildTestableWidget(
          TotalSisaHutangCard(debts: testDebts),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('total_sisa_hutang_card')), findsOneWidget);
      expect(find.byKey(const Key('total_sisa_hutang_rupiah_text')), findsOneWidget);
      expect(find.text('Rp 3.700.000'), findsOneWidget);
      expect(find.text('3 Tagihan Aktif'), findsOneWidget);
    });

    testWidgets('renders progress bar and total original amount correctly',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Total original = 1.000.000 + 5.000.000 + 750.000 + 300.000 = 7.050.000
      // Total remaining = 3.700.000
      // Total paid = 3.350.000 (47%)
      await tester.pumpWidget(
        buildTestableWidget(
          TotalSisaHutangCard(debts: testDebts),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('total_sisa_hutang_progress_bar')), findsOneWidget);
      expect(find.textContaining('Total: Rp 7.050.000'), findsOneWidget);
      expect(find.textContaining('Terbayar: Rp 3.350.000 (47%)'), findsOneWidget);
    });

    testWidgets('renders breakdown section with type chips and Rupiah amounts',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          TotalSisaHutangCard(debts: testDebts),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sisa_hutang_breakdown_section')), findsOneWidget);
      expect(find.byKey(const Key('sisa_hutang_type_paylater')), findsOneWidget);
      expect(find.byKey(const Key('sisa_hutang_amount_paylater')), findsOneWidget);
      expect(find.text('Rp 450.000'), findsOneWidget);

      expect(find.byKey(const Key('sisa_hutang_type_cicilan')), findsOneWidget);
      expect(find.byKey(const Key('sisa_hutang_amount_cicilan')), findsOneWidget);
      expect(find.text('Rp 2.500.000'), findsOneWidget);

      expect(find.byKey(const Key('sisa_hutang_type_kartuKredit')), findsOneWidget);
      expect(find.byKey(const Key('sisa_hutang_amount_kartuKredit')), findsOneWidget);
      expect(find.text('Rp 750.000'), findsOneWidget);
    });

    testWidgets('renders due soon alert banner when active debt has due date in <= 3 days',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool filterTapped = false;
      await tester.pumpWidget(
        buildTestableWidget(
          TotalSisaHutangCard(
            debts: testDebts,
            onFilterDueSoon: () => filterTapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('due_soon_alert_box')), findsOneWidget);
      expect(find.textContaining('Perhatian: 2 tagihan jatuh tempo'), findsOneWidget);

      await tester.tap(find.byKey(const Key('due_soon_alert_box')));
      await tester.pumpAndSettle();

      expect(filterTapped, isTrue);
    });

    testWidgets('handles zero debts without errors and renders Rp 0',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          const TotalSisaHutangCard(debts: []),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('total_sisa_hutang_rupiah_text')), findsOneWidget);
      expect(find.text('Rp 0'), findsWidgets);
      expect(find.text('0 Tagihan Aktif'), findsOneWidget);
      expect(find.byKey(const Key('due_soon_alert_box')), findsNothing);
    });
  });

  group('HutangScreen Total Sisa Hutang Card Integration', () {
    testWidgets('HutangScreen displays total sisa hutang in Rupiah and updates on payment',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final debts = [
        DebtItem(
          id: 'test_integration_debt',
          name: 'Hutang Spay',
          totalAmount: 1000000,
          remainingAmount: 1000000,
          dueDate: now.add(const Duration(days: 2)),
          status: 'active',
          type: DebtType.paylater,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(home: HutangScreen(initialDebts: debts)),
      );
      await tester.pumpAndSettle();

      // Verify formatted Rupiah total remaining text
      expect(find.byKey(const Key('total_sisa_hutang_rupiah_text')), findsOneWidget);
      final totalText = tester.widget<Text>(find.byKey(const Key('total_sisa_hutang_rupiah_text')));
      expect(totalText.data, 'Rp 1.000.000');
      expect(find.text('1 Tagihan Aktif'), findsOneWidget);

      // Mark debt paid
      final markPaidBtn =
          find.byKey(const Key('btn_mark_paid_test_integration_debt'));
      await tester.tap(markPaidBtn);
      await tester.pumpAndSettle();

      // Total remaining updates dynamically to Rp 0
      final updatedTotalText = tester.widget<Text>(find.byKey(const Key('total_sisa_hutang_rupiah_text')));
      expect(updatedTotalText.data, 'Rp 0');
      expect(find.text('0 Tagihan Aktif'), findsOneWidget);
    });
  });
}
