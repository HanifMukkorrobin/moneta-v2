import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/models/monthly_rekap_data.dart';
import 'package:moneta/screens/rekap/widgets/category_nominal_persentase_list.dart';

void main() {
  group('CategoryNominalPersentaseList (Daftar Kategori dengan Nominal dan Persentase)', () {
    late List<CategoryBreakdownItem> sampleItems;

    setUp(() {
      sampleItems = const [
        CategoryBreakdownItem(
          category: 'Kebutuhan Rumah',
          type: 'expense',
          total: 1750000,
          percentage: 45.0,
          transactionCount: 2,
          color: Colors.blue,
        ),
        CategoryBreakdownItem(
          category: 'Makan & Minuman',
          type: 'expense',
          total: 1200000,
          percentage: 30.0,
          transactionCount: 8,
          color: Colors.orange,
        ),
        CategoryBreakdownItem(
          category: 'Belanja Kebutuhan',
          type: 'expense',
          total: 600000,
          percentage: 15.0,
          transactionCount: 3,
          color: Colors.green,
          isCustom: true,
        ),
        CategoryBreakdownItem(
          category: 'Hiburan',
          type: 'expense',
          total: 400000,
          percentage: 10.0,
          transactionCount: 1,
          color: Colors.purple,
        ),
      ];
    });

    testWidgets('renders all categories with ranks, nominal, and percentages', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CategoryNominalPersentaseList(
                items: sampleItems,
                onCategorySelected: (_) {},
              ),
            ),
          ),
        ),
      );

      // Verify ranks
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      expect(find.text('#3'), findsOneWidget);
      expect(find.text('#4'), findsOneWidget);

      // Verify Category Names
      expect(find.text('Kebutuhan Rumah'), findsOneWidget);
      expect(find.text('Makan & Minuman'), findsOneWidget);
      expect(find.text('Belanja Kebutuhan'), findsOneWidget);
      expect(find.text('Hiburan'), findsOneWidget);

      // Verify Custom Badge
      expect(find.text('Kustom'), findsOneWidget);

      // Verify Nominals
      expect(find.text('Rp 1.750.000'), findsOneWidget);
      expect(find.text('Rp 1.200.000'), findsOneWidget);
      expect(find.text('Rp 600.000'), findsOneWidget);
      expect(find.text('Rp 400.000'), findsOneWidget);

      // Verify Percentages
      expect(find.text('45.0%'), findsOneWidget);
      expect(find.text('30.0%'), findsOneWidget);
      expect(find.text('15.0%'), findsOneWidget);
      expect(find.text('10.0%'), findsOneWidget);
    });

    testWidgets('filters category list via search input', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CategoryNominalPersentaseList(
                items: sampleItems,
                onCategorySelected: (_) {},
              ),
            ),
          ),
        ),
      );

      // Enter search text
      await tester.enterText(find.byKey(const Key('category_list_search_input')), 'Makan');
      await tester.pumpAndSettle();

      expect(find.text('Makan & Minuman'), findsOneWidget);
      expect(find.text('Kebutuhan Rumah'), findsNothing);
      expect(find.text('Hiburan'), findsNothing);

      // Clear search
      await tester.enterText(find.byKey(const Key('category_list_search_input')), 'ZzzNotFound');
      await tester.pumpAndSettle();

      expect(find.text('Tidak ditemukan kategori untuk "ZzzNotFound"'), findsOneWidget);
    });

    testWidgets('sorts categories by different criteria', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CategoryNominalPersentaseList(
                items: sampleItems,
                onCategorySelected: (_) {},
              ),
            ),
          ),
        ),
      );

      // Open sorting menu
      await tester.tap(find.byKey(const Key('category_sort_button')));
      await tester.pumpAndSettle();

      // Select 'Transaksi Terbanyak' (most_trx)
      await tester.tap(find.text('Transaksi Terbanyak'));
      await tester.pumpAndSettle();

      // Makan & Minuman (8 trx) should now be #1
      final rank1Text = find.text('#1');
      expect(rank1Text, findsOneWidget);

      // Verify Makan & Minuman is displayed first
      expect(find.text('Makan & Minuman'), findsOneWidget);
    });

    testWidgets('selects and deselects category item', (WidgetTester tester) async {
      String? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: CategoryNominalPersentaseList(
                    items: sampleItems,
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

      // Tap on Makan & Minuman
      await tester.tap(find.byKey(const Key('category_chart_item_Makan & Minuman')));
      await tester.pumpAndSettle();
      expect(selected, 'Makan & Minuman');

      // Tap again to deselect
      await tester.tap(find.byKey(const Key('category_chart_item_Makan & Minuman')));
      await tester.pumpAndSettle();
      expect(selected, isNull);
    });
  });
}
