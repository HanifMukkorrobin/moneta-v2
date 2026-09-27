import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/models/monthly_rekap_data.dart';
import 'package:moneta/screens/rekap/widgets/category_proportion_chart.dart';

void main() {
  group('CategoryProportionChart (Grafik Proporsi Pengeluaran per Kategori)', () {
    late List<CategoryBreakdownItem> expenseItems;

    setUp(() {
      expenseItems = const [
        CategoryBreakdownItem(
          category: 'Kebutuhan Rumah',
          type: 'expense',
          total: 1750000,
          percentage: 37.2,
          transactionCount: 1,
          color: Colors.blue,
        ),
        CategoryBreakdownItem(
          category: 'Belanja',
          type: 'expense',
          total: 780000,
          percentage: 16.6,
          transactionCount: 2,
          color: Colors.purple,
        ),
        CategoryBreakdownItem(
          category: 'Tagihan & Utilitas',
          type: 'expense',
          total: 620000,
          percentage: 13.2,
          transactionCount: 1,
          color: Colors.orange,
        ),
      ];
    });

    testWidgets('renders donut chart painter, center summary, and category items', (WidgetTester tester) async {
      String? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: CategoryProportionChart(
                    items: expenseItems,
                    totalAmount: 3150000,
                    selectedCategory: selected,
                    onCategorySelected: (cat) {
                      setState(() => selected = cat);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Verify custom painter is present
      expect(find.byType(CustomPaint), findsWidgets);

      // Verify category items in list
      expect(find.text('Kebutuhan Rumah'), findsWidgets);
      expect(find.text('Belanja'), findsWidgets);
      expect(find.text('Tagihan & Utilitas'), findsWidgets);

      // Verify percentages
      expect(find.text('37.2%'), findsWidgets);
      expect(find.text('16.6%'), findsOneWidget);
      expect(find.text('13.2%'), findsOneWidget);

      // Verify counts
      expect(find.text('3 Kategori Tercatat'), findsOneWidget);
    });

    testWidgets('toggles view mode between Donut and Bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CategoryProportionChart(
                items: expenseItems,
                totalAmount: 3150000,
                onCategorySelected: (_) {},
              ),
            ),
          ),
        ),
      );

      // Initially donut view
      expect(find.byKey(const Key('chart_mode_bar')), findsOneWidget);

      // Switch to bar mode
      await tester.tap(find.byKey(const Key('chart_mode_bar')));
      await tester.pumpAndSettle();

      expect(find.text('Terbesar: Kebutuhan Rumah (37.2%)'), findsOneWidget);

      // Switch back to donut mode
      await tester.tap(find.byKey(const Key('chart_mode_donut')));
      await tester.pumpAndSettle();

      expect(find.text('Top Kategori'), findsOneWidget);
    });

    testWidgets('selects and deselects category to filter', (WidgetTester tester) async {
      String? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: CategoryProportionChart(
                    items: expenseItems,
                    totalAmount: 3150000,
                    selectedCategory: selected,
                    onCategorySelected: (cat) {
                      setState(() => selected = cat);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Tap on Belanja
      await tester.tap(find.byKey(const Key('category_chart_item_Belanja')));
      await tester.pumpAndSettle();

      expect(selected, 'Belanja');

      // Tap on Belanja again to deselect
      await tester.tap(find.byKey(const Key('category_chart_item_Belanja')));
      await tester.pumpAndSettle();

      expect(selected, isNull);
    });

    testWidgets('renders empty placeholder when items list is empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryProportionChart(
              items: const [],
              totalAmount: 0,
              type: 'expense',
              onCategorySelected: (_) {},
            ),
          ),
        ),
      );

      expect(
        find.text('Belum ada transaksi pengeluaran untuk ditampilkan.'),
        findsOneWidget,
      );
    });
  });
}
