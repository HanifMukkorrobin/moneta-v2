import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/models/debt_item.dart';
import 'package:moneta/screens/hutang/hutang_screen.dart';
import 'package:moneta/screens/hutang/widgets/debt_card.dart';
import 'package:moneta/screens/hutang/widgets/jadwal_jatuh_tempo_section.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  group('JadwalJatuhTempoSection Widget Tests', () {
    final now = DateTime.now();

    final testDebts = [
      DebtItem(
        id: 'debt_soon_1',
        name: 'Spaylater Belanja',
        totalAmount: 1000000,
        remainingAmount: 400000,
        dueDate: now.add(const Duration(days: 2)), // Due in 2 days (Segera)
        status: 'active',
        type: DebtType.paylater,
      ),
      DebtItem(
        id: 'debt_later_2',
        name: 'Kredit Mobil',
        totalAmount: 50000000,
        remainingAmount: 25000000,
        dueDate: now.add(const Duration(days: 20)), // Due in 20 days (Not Segera)
        status: 'active',
        type: DebtType.cicilan,
      ),
      DebtItem(
        id: 'debt_soon_3',
        name: 'Kartu Kredit Mandiri',
        totalAmount: 800000,
        remainingAmount: 800000,
        dueDate: now.add(const Duration(days: 1)), // Due tomorrow (Segera)
        status: 'active',
        type: DebtType.kartuKredit,
      ),
      DebtItem(
        id: 'debt_paid_4',
        name: 'Pinjaman Kantor Lunas',
        totalAmount: 500000,
        remainingAmount: 0,
        dueDate: now.subtract(const Duration(days: 5)),
        status: 'paid',
        type: DebtType.pinjamanPribadi,
      ),
    ];

    testWidgets('renders section header, chronological schedule, and penanda segera',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          JadwalJatuhTempoSection(debts: testDebts),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Jadwal Jatuh Tempo'), findsOneWidget);
      expect(find.byKey(const Key('btn_toggle_schedule_filter')), findsOneWidget);

      // Verify chronological order: debt_soon_3 (1 day) should appear before debt_soon_1 (2 days)
      expect(find.byKey(const Key('schedule_card_debt_soon_3')), findsOneWidget);
      expect(find.byKey(const Key('schedule_card_debt_soon_1')), findsOneWidget);
      expect(find.byKey(const Key('schedule_card_debt_later_2')), findsOneWidget);
      // Paid debt should not appear in active timeline
      expect(find.byKey(const Key('schedule_card_debt_paid_4')), findsNothing);

      // Verify Penanda Segera badge on due soon debts
      expect(
          find.byKey(const Key('schedule_badge_segera_debt_soon_3')), findsOneWidget);
      expect(
          find.byKey(const Key('schedule_badge_segera_debt_soon_1')), findsOneWidget);
      // Debt due in 20 days should not have Segera badge
      expect(
          find.byKey(const Key('schedule_badge_segera_debt_later_2')), findsNothing);
    });

    testWidgets('toggling Segera Saja filters timeline to only due soon items',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          JadwalJatuhTempoSection(debts: testDebts),
        ),
      );
      await tester.pumpAndSettle();

      // Initially shows debt_later_2
      expect(find.byKey(const Key('schedule_card_debt_later_2')), findsOneWidget);

      // Tap toggle filter to 'Segera Saja'
      await tester.tap(find.byKey(const Key('btn_toggle_schedule_filter')));
      await tester.pumpAndSettle();

      expect(find.text('Segera Saja (2)'), findsOneWidget);
      expect(find.byKey(const Key('schedule_card_debt_soon_3')), findsOneWidget);
      expect(find.byKey(const Key('schedule_card_debt_soon_1')), findsOneWidget);
      // Not due soon item is hidden
      expect(find.byKey(const Key('schedule_card_debt_later_2')), findsNothing);
    });

    testWidgets('shows empty state container when no active debts exist',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          const JadwalJatuhTempoSection(debts: []),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('empty_schedule_container')), findsOneWidget);
      expect(find.textContaining('Tidak ada jadwal tagihan aktif'), findsOneWidget);
    });

    testWidgets('tapping schedule card triggers onSelectDebt callback',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      DebtItem? selected;
      await tester.pumpWidget(
        buildTestableWidget(
          JadwalJatuhTempoSection(
            debts: testDebts,
            onSelectDebt: (d) => selected = d,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('schedule_card_debt_soon_3')));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!.id, 'debt_soon_3');
    });
  });

  group('DebtCard Penanda Segera Tests', () {
    final now = DateTime.now();

    testWidgets('renders Penanda Segera badge and alert strip when isDueSoon',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dueSoonDebt = DebtItem(
        id: 'segera_debt_1',
        name: 'Shopee Paylater Tagihan Listrik',
        totalAmount: 350000,
        remainingAmount: 350000,
        dueDate: now.add(const Duration(days: 2)), // 2 days left
        status: 'active',
        type: DebtType.paylater,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          DebtCard(debt: dueSoonDebt),
        ),
      );
      await tester.pumpAndSettle();

      // Penanda Segera badge in title row
      expect(find.byKey(const Key('penanda_segera_segera_debt_1')), findsOneWidget);
      expect(find.text('SEGERA'), findsOneWidget);

      // Due soon alert strip at bottom of card
      expect(find.byKey(const Key('due_soon_alert_strip_segera_debt_1')),
          findsOneWidget);
      expect(find.textContaining('Jatuh tempo SEGERA dalam 2 hari'),
          findsOneWidget);
    });

    testWidgets('does not render Penanda Segera badge for debts due far in the future or paid',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final farDebt = DebtItem(
        id: 'far_debt_1',
        name: 'Cicilan Gadget Kantor',
        totalAmount: 5000000,
        remainingAmount: 4000000,
        dueDate: now.add(const Duration(days: 25)),
        status: 'active',
        type: DebtType.cicilan,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          DebtCard(debt: farDebt),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('penanda_segera_far_debt_1')), findsNothing);
      expect(find.byKey(const Key('due_soon_alert_strip_far_debt_1')), findsNothing);
    });
  });

  group('HutangScreen Jadwal Jatuh Tempo Integration', () {
    testWidgets('HutangScreen integrates JadwalJatuhTempoSection and selecting item searches list',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(home: const HutangScreen()),
      );
      await tester.pumpAndSettle();

      // Verify JadwalJatuhTempoSection is rendered in screen
      expect(find.byKey(const Key('jadwal_jatuh_tempo_section')), findsOneWidget);
      expect(find.text('Jadwal Jatuh Tempo'), findsOneWidget);

      // Tap on first schedule card (debt_3: Tagihan Kartu Kredit Bank BCA)
      final scheduleCard = find.byKey(const Key('schedule_card_debt_3'));
      await tester.ensureVisible(scheduleCard);
      await tester.tap(scheduleCard);
      await tester.pumpAndSettle();

      // Search input should be populated and list filtered to that debt
      expect(find.widgetWithText(TextField, 'Tagihan Kartu Kredit Bank BCA'),
          findsOneWidget);
      expect(find.byKey(const Key('debt_card_debt_3')), findsOneWidget);
    });
  });
}
