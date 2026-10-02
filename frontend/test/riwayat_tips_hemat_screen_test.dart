import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/models/saving_tip_item.dart';
import 'package:moneta/screens/beranda/beranda_screen.dart';
import 'package:moneta/screens/beranda/riwayat_tips_hemat_screen.dart';
import 'package:moneta/screens/beranda/widgets/daily_saving_tips_card.dart';
import 'package:moneta/state/app_state.dart';
import 'package:moneta/theme/app_theme.dart';

void main() {
  setUp(() {
    AppState.instance.resetToDefault();
  });

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: AppStateScope(
        notifier: AppState.instance,
        child: child,
      ),
      routes: {
        '/riwayat-tips': (_) => const RiwayatTipsHematScreen(),
      },
    );
  }

  group('RiwayatTipsHematScreen Widget Tests', () {
    testWidgets('renders AppBar and summary banner with accurate initial stats',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const RiwayatTipsHematScreen()),
      );
      await tester.pumpAndSettle();

      // Check AppBar
      expect(find.text('Riwayat Tips Hemat'), findsOneWidget);

      // Check Summary Card
      expect(find.byKey(const Key('riwayat_tips_summary_card')), findsOneWidget);
      expect(find.byKey(const Key('riwayat_success_badge')), findsOneWidget);
      expect(find.byKey(const Key('total_applied_savings_amount')), findsOneWidget);
      expect(find.text('Akumulasi Hemat Terlaksana'), findsOneWidget);

      // Check initial tips rendered
      final tips = SavingTipItem.getHistoryTips();
      expect(find.byKey(Key('riwayat_tip_item_${tips.first.id}')), findsOneWidget);
    });

    testWidgets('filters tips based on status tabs (Semua, Diterapkan, Belum Diterapkan)',
        (tester) async {
      final customTips = [
        const SavingTipItem(
          id: 'tip_a',
          title: 'Tip Diterapkan A',
          category: 'Makan & Minuman',
          description: 'Deskripsi A',
          potentialSaving: 50000,
          isApplied: true,
          date: 'Hari Ini',
        ),
        const SavingTipItem(
          id: 'tip_b',
          title: 'Tip Belum B',
          category: 'Belanja',
          description: 'Deskripsi B',
          potentialSaving: 75000,
          isApplied: false,
          date: 'Kemarin',
        ),
      ];

      await tester.pumpWidget(
        buildTestableWidget(RiwayatTipsHematScreen(initialTips: customTips)),
      );
      await tester.pumpAndSettle();

      // All tips visible initially
      expect(find.text('Tip Diterapkan A'), findsOneWidget);
      expect(find.text('Tip Belum B'), findsOneWidget);

      // Filter Diterapkan
      await tester.tap(find.byKey(const Key('filter_status_diterapkan')));
      await tester.pumpAndSettle();
      expect(find.text('Tip Diterapkan A'), findsOneWidget);
      expect(find.text('Tip Belum B'), findsNothing);

      // Filter Belum Diterapkan
      await tester.tap(find.byKey(const Key('filter_status_belum')));
      await tester.pumpAndSettle();
      expect(find.text('Tip Diterapkan A'), findsNothing);
      expect(find.text('Tip Belum B'), findsOneWidget);

      // Filter Semua
      await tester.tap(find.byKey(const Key('filter_status_semua')));
      await tester.pumpAndSettle();
      expect(find.text('Tip Diterapkan A'), findsOneWidget);
      expect(find.text('Tip Belum B'), findsOneWidget);
    });

    testWidgets('filters tips by category chips', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const RiwayatTipsHematScreen()),
      );
      await tester.pumpAndSettle();

      // Tap Transportasi chip
      await tester.tap(find.byKey(const Key('filter_category_Transportasi')));
      await tester.pumpAndSettle();

      expect(find.text('Pilih Berjalan Kaki untuk Jarak < 1 KM'), findsOneWidget);
      expect(find.text('Bawa Bekal Makan Siang 2x Sepekan'), findsNothing);

      // Tap Semua chip
      await tester.tap(find.byKey(const Key('filter_category_Semua')));
      await tester.pumpAndSettle();

      expect(find.text('Bawa Bekal Makan Siang 2x Sepekan'), findsOneWidget);
    });

    testWidgets('searches tips by title and description', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const RiwayatTipsHematScreen()),
      );
      await tester.pumpAndSettle();

      // Enter search query "kopi"
      await tester.enterText(
        find.byKey(const Key('riwayat_tips_search_input')),
        'kopi',
      );
      await tester.pumpAndSettle();

      expect(find.text('Seduh Kopi Sendiri di Pagi Hari'), findsOneWidget);
      expect(find.text('Bawa Bekal Makan Siang 2x Sepekan'), findsNothing);

      // Clear search
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Bawa Bekal Makan Siang 2x Sepekan'), findsOneWidget);
    });

    testWidgets('toggles tip applied status and shows feedback SnackBar',
        (tester) async {
      SavingTipItem? toggledTip;
      bool? newStatus;

      final testTips = [
        const SavingTipItem(
          id: 'tip_t1',
          title: 'Tip Toggle Test',
          category: 'Belanja',
          description: 'Desc',
          potentialSaving: 100000,
          isApplied: false,
        ),
      ];

      await tester.pumpWidget(
        buildTestableWidget(
          RiwayatTipsHematScreen(
            initialTips: testTips,
            onToggleTip: (tip, status) {
              toggledTip = tip;
              newStatus = status;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially not applied
      expect(find.text('Terapkan Tip'), findsOneWidget);

      // Tap toggle button
      await tester.tap(find.byKey(const Key('btn_toggle_riwayat_tip_tip_t1')));
      await tester.pumpAndSettle();

      expect(toggledTip?.id, equals('tip_t1'));
      expect(newStatus, isTrue);
      expect(find.text('Diterapkan'), findsWidgets);
      expect(
        find.textContaining('ditandai sebagai diterapkan'),
        findsOneWidget,
      );

      // Tap again to unapply
      await tester.tap(find.byKey(const Key('btn_toggle_riwayat_tip_tip_t1')));
      await tester.pumpAndSettle();

      expect(newStatus, isFalse);
      expect(
        find.textContaining('dibatalkan dari daftar penerapan'),
        findsOneWidget,
      );
    });

    testWidgets('renders empty state when filter has no results and allows reset',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const RiwayatTipsHematScreen()),
      );
      await tester.pumpAndSettle();

      // Enter search query matching nothing
      await tester.enterText(
        find.byKey(const Key('riwayat_tips_search_input')),
        'keyword-tidak-mungkin-ada-12345',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('riwayat_tips_empty_state')), findsOneWidget);
      expect(find.text('Tidak ada riwayat tips ditemukan'), findsOneWidget);

      // Scroll to reset button and tap
      await tester.ensureVisible(find.byKey(const Key('btn_reset_filters')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_reset_filters')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('riwayat_tips_empty_state')), findsNothing);
      expect(find.text('Bawa Bekal Makan Siang 2x Sepekan'), findsOneWidget);
    });

    testWidgets('DailySavingTipsCard header Riwayat button navigates to RiwayatTipsHematScreen',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const Scaffold(
            body: SingleChildScrollView(
              child: DailySavingTipsCard(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('btn_lihat_riwayat_tips')), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_lihat_riwayat_tips')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('riwayat_tips_hemat_screen')), findsOneWidget);
    });

    testWidgets('BerandaScreen AppBar action navigates to RiwayatTipsHematScreen',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const BerandaScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('beranda_riwayat_tips_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('beranda_riwayat_tips_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('riwayat_tips_hemat_screen')), findsOneWidget);
    });
  });
}
