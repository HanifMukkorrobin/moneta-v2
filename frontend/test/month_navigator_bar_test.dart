import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/screens/rekap/rekap_bulanan_screen.dart';
import 'package:moneta/screens/rekap/widgets/month_navigator_bar.dart';

void main() {
  group('MonthNavigatorBar (Navigasi Pindah Bulan Tanpa Ganti Halaman)', () {
    final availableMonths = ['2026-09', '2026-08', '2026-07'];

    testWidgets('renders month label, Kini badge, and navigation chevrons', (WidgetTester tester) async {
      String selected = '2026-09';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return MonthNavigatorBar(
                  selectedMonth: selected,
                  availableMonths: availableMonths,
                  onMonthChanged: (m) {
                    setState(() => selected = m);
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('September 2026'), findsNWidgets(2)); // Label + Chip
      expect(find.text('Kini'), findsOneWidget);
      expect(find.byKey(const Key('month_navigator_prev_button')), findsOneWidget);
      expect(find.byKey(const Key('month_navigator_next_button')), findsOneWidget);
    });

    testWidgets('switches month backwards and forwards without page route change', (WidgetTester tester) async {
      String selected = '2026-09';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return MonthNavigatorBar(
                  selectedMonth: selected,
                  availableMonths: availableMonths,
                  onMonthChanged: (m) {
                    setState(() => selected = m);
                  },
                );
              },
            ),
          ),
        ),
      );

      // Tap previous month
      await tester.tap(find.byKey(const Key('month_navigator_prev_button')));
      await tester.pumpAndSettle();

      expect(selected, '2026-08');
      expect(find.text('Agustus 2026'), findsNWidgets(2)); // center label and chip

      // Tap next month to return to September
      await tester.tap(find.byKey(const Key('month_navigator_next_button')));
      await tester.pumpAndSettle();

      expect(selected, '2026-09');
      expect(find.text('September 2026'), findsNWidgets(2));
    });

    testWidgets('switches month directly via quick choice chips', (WidgetTester tester) async {
      String selected = '2026-09';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return MonthNavigatorBar(
                  selectedMonth: selected,
                  availableMonths: availableMonths,
                  onMonthChanged: (m) {
                    setState(() => selected = m);
                  },
                );
              },
            ),
          ),
        ),
      );

      // Tap Juli 2026 chip
      await tester.tap(find.byKey(const Key('month_chip_2026-07')));
      await tester.pumpAndSettle();

      expect(selected, '2026-07');
      expect(find.text('Juli 2026'), findsNWidgets(2));
    });

    testWidgets('opens month picker bottom sheet and selects month', (WidgetTester tester) async {
      String selected = '2026-09';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return MonthNavigatorBar(
                  selectedMonth: selected,
                  availableMonths: availableMonths,
                  onMonthChanged: (m) {
                    setState(() => selected = m);
                  },
                );
              },
            ),
          ),
        ),
      );

      // Tap center picker button
      await tester.tap(find.byKey(const Key('month_navigator_picker_button')));
      await tester.pumpAndSettle();

      // Verify bottom sheet title and content
      expect(find.text('Pilih Periode Bulan'), findsOneWidget);
      expect(find.text('Bulan Ini'), findsOneWidget);
      expect(find.byKey(const Key('month_picker_item_2026-08')), findsOneWidget);

      // Select Agustus 2026 from bottom sheet
      await tester.tap(find.byKey(const Key('month_picker_item_2026-08')));
      await tester.pumpAndSettle();

      // Bottom sheet should close and selected month should update
      expect(find.text('Pilih Periode Bulan'), findsNothing);
      expect(selected, '2026-08');
      expect(find.text('Agustus 2026'), findsNWidgets(2));
    });

    testWidgets('swipes horizontally in RekapBulananScreen to change month in-page', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RekapBulananScreen(initialMonth: '2026-09'),
        ),
      );

      expect(find.text('September 2026'), findsWidgets);

      // Drag / Swipe right on the screen to switch to previous month (Agustus 2026)
      await tester.drag(find.byKey(const Key('rekap_body_scroll_view')), const Offset(400, 0));
      await tester.pumpAndSettle();

      expect(find.text('Agustus 2026'), findsWidgets);

      // Drag / Swipe left to switch back to next month (September 2026)
      await tester.drag(find.byKey(const Key('rekap_body_scroll_view')), const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(find.text('September 2026'), findsWidgets);
    });
  });
}
