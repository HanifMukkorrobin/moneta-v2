import 'package:flutter/material.dart';
import '../models/monthly_rekap_data.dart';
import '../models/transaction_item.dart';

class RekapMockData {
  static const List<String> availableMonths = [
    '2026-09',
    '2026-08',
    '2026-07',
  ];

  static String getMonthLabel(String monthKey) {
    const months = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final parts = monthKey.split('-');
    if (parts.length == 2) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      if (year != null && month != null && month >= 1 && month <= 12) {
        return '${months[month]} $year';
      }
    }
    return monthKey;
  }

  static List<TransactionItem> getBaselineSeptemberTransactions() {
    return [
      TransactionItem(
        id: 'tx_sep_01',
        note: 'Gaji Bulanan PT Teknologi Maju',
        amount: 8500000,
        type: 'income',
        category: 'Gaji',
        occurredAt: DateTime(2026, 9, 25, 9, 0),
        isConfirmed: true,
        confidenceScore: 0.99,
      ),
      TransactionItem(
        id: 'tx_sep_02',
        note: 'Proyek UI/UX Desain Landing Page',
        amount: 2500000,
        type: 'income',
        category: 'Freelance',
        occurredAt: DateTime(2026, 9, 20, 14, 30),
        isConfirmed: true,
        confidenceScore: 0.96,
      ),
      TransactionItem(
        id: 'tx_sep_03',
        note: 'Dividen Saham BBCA Masuk Rekening',
        amount: 450000,
        type: 'income',
        category: 'Investasi',
        occurredAt: DateTime(2026, 9, 15, 11, 0),
        isConfirmed: true,
        confidenceScore: 0.95,
      ),
      TransactionItem(
        id: 'tx_sep_04',
        note: 'Sewa Kamar Kos Bulanan',
        amount: 1750000,
        type: 'expense',
        category: 'Kebutuhan Rumah',
        occurredAt: DateTime(2026, 9, 1, 10, 0),
        isConfirmed: true,
        confidenceScore: 0.98,
      ),
      TransactionItem(
        id: 'tx_sep_05',
        note: 'Makan Malam Sushi Tei bareng Teman',
        amount: 285000,
        type: 'expense',
        category: 'Makan & Minuman',
        occurredAt: DateTime(2026, 9, 26, 19, 45),
        isConfirmed: true,
        confidenceScore: 0.98,
      ),
      TransactionItem(
        id: 'tx_sep_06',
        note: 'Belanja Bulanan Superindo & Buah Segar',
        amount: 780000,
        type: 'expense',
        category: 'Belanja',
        occurredAt: DateTime(2026, 9, 22, 16, 20),
        isConfirmed: true,
        confidenceScore: 0.94,
      ),
      TransactionItem(
        id: 'tx_sep_07',
        note: 'Tagihan Listrik PLN & Indihome WiFi',
        amount: 620000,
        type: 'expense',
        category: 'Tagihan & Utilitas',
        occurredAt: DateTime(2026, 9, 5, 13, 0),
        isConfirmed: true,
        confidenceScore: 0.97,
      ),
      TransactionItem(
        id: 'tx_sep_08',
        note: 'Makan Siang Nasi Padang Sederhana',
        amount: 45000,
        type: 'expense',
        category: 'Makan & Minuman',
        occurredAt: DateTime(2026, 9, 27, 12, 15),
        isConfirmed: true,
        confidenceScore: 0.98,
      ),
      TransactionItem(
        id: 'tx_sep_09',
        note: 'Bensin Motor Pertamax & Tol Dalam Kota',
        amount: 185000,
        type: 'expense',
        category: 'Transportasi',
        occurredAt: DateTime(2026, 9, 18, 8, 30),
        isConfirmed: true,
        confidenceScore: 0.96,
      ),
      TransactionItem(
        id: 'tx_sep_10',
        note: 'Langganan Membership Gym & Fitness',
        amount: 350000,
        type: 'expense',
        category: 'Gym & Fitness',
        occurredAt: DateTime(2026, 9, 2, 17, 0),
        isConfirmed: true,
        isCustomCategory: true,
        confidenceScore: 0.95,
      ),
      TransactionItem(
        id: 'tx_sep_11',
        note: 'Skincare Toner & Sunscreen Somethinc',
        amount: 280000,
        type: 'expense',
        category: 'Skincare & Perawatan',
        occurredAt: DateTime(2026, 9, 14, 15, 10),
        isConfirmed: true,
        isCustomCategory: true,
        confidenceScore: 0.96,
      ),
      TransactionItem(
        id: 'tx_sep_12',
        note: 'Tiket Bioskop XXI & Popcorn',
        amount: 145000,
        type: 'expense',
        category: 'Hiburan',
        occurredAt: DateTime(2026, 9, 12, 20, 0),
        isConfirmed: true,
        confidenceScore: 0.93,
      ),
      TransactionItem(
        id: 'tx_sep_13',
        note: 'Vitamin C & Suplemen Apotek K-24',
        amount: 120000,
        type: 'expense',
        category: 'Kesehatan',
        occurredAt: DateTime(2026, 9, 8, 14, 0),
        isConfirmed: true,
        confidenceScore: 0.95,
      ),
      TransactionItem(
        id: 'tx_sep_14',
        note: 'Kopi Kenangan Mantan & Toast',
        amount: 48000,
        type: 'expense',
        category: 'Makan & Minuman',
        occurredAt: DateTime(2026, 9, 24, 15, 30),
        isConfirmed: true,
        confidenceScore: 0.98,
      ),
      TransactionItem(
        id: 'tx_sep_15',
        note: 'Ojol GrabBike ke Kantor PP',
        amount: 55000,
        type: 'expense',
        category: 'Transportasi',
        occurredAt: DateTime(2026, 9, 19, 7, 45),
        isConfirmed: true,
        confidenceScore: 0.96,
      ),
    ];
  }

  static List<TransactionItem> getBaselineAugustTransactions() {
    return [
      TransactionItem(
        id: 'tx_aug_01',
        note: 'Gaji Bulanan Agustus',
        amount: 8500000,
        type: 'income',
        category: 'Gaji',
        occurredAt: DateTime(2026, 8, 25, 9, 0),
        isConfirmed: true,
      ),
      TransactionItem(
        id: 'tx_aug_02',
        note: 'Bonus Kinerja Kuartal 3',
        amount: 2000000,
        type: 'income',
        category: 'Bonus',
        occurredAt: DateTime(2026, 8, 20, 11, 0),
        isConfirmed: true,
      ),
      TransactionItem(
        id: 'tx_aug_03',
        note: 'Sewa Kos Agustus',
        amount: 1750000,
        type: 'expense',
        category: 'Kebutuhan Rumah',
        occurredAt: DateTime(2026, 8, 1, 10, 0),
        isConfirmed: true,
      ),
      TransactionItem(
        id: 'tx_aug_04',
        note: 'Belanja Baju & Sepatu Mall',
        amount: 1450000,
        type: 'expense',
        category: 'Belanja',
        occurredAt: DateTime(2026, 8, 17, 16, 0),
        isConfirmed: true,
      ),
      TransactionItem(
        id: 'tx_aug_05',
        note: 'Kuliner & Kafe Weekend',
        amount: 1250000,
        type: 'expense',
        category: 'Makan & Minuman',
        occurredAt: DateTime(2026, 8, 15, 20, 0),
        isConfirmed: true,
      ),
      TransactionItem(
        id: 'tx_aug_06',
        note: 'Tagihan Listrik & Internet',
        amount: 650000,
        type: 'expense',
        category: 'Tagihan & Utilitas',
        occurredAt: DateTime(2026, 8, 5, 12, 0),
        isConfirmed: true,
      ),
      TransactionItem(
        id: 'tx_aug_07',
        note: 'Bensin & Servis Motor Rutin',
        amount: 450000,
        type: 'expense',
        category: 'Transportasi',
        occurredAt: DateTime(2026, 8, 10, 14, 0),
        isConfirmed: true,
      ),
      TransactionItem(
        id: 'tx_aug_08',
        note: 'Membership Gym Agustus',
        amount: 350000,
        type: 'expense',
        category: 'Gym & Fitness',
        occurredAt: DateTime(2026, 8, 2, 17, 0),
        isConfirmed: true,
      ),
      TransactionItem(
        id: 'tx_aug_09',
        note: 'Konser Musik Kemerdekaan',
        amount: 350000,
        type: 'expense',
        category: 'Hiburan',
        occurredAt: DateTime(2026, 8, 16, 19, 0),
        isConfirmed: true,
      ),
    ];
  }

  static List<TransactionItem> getBaselineJulyTransactions() {
    return [
      TransactionItem(
        id: 'tx_jul_01',
        note: 'Gaji Bulanan Juli',
        amount: 8500000,
        type: 'income',
        category: 'Gaji',
        occurredAt: DateTime(2026, 7, 25, 9, 0),
        isConfirmed: true,
      ),
      TransactionItem(
        id: 'tx_jul_02',
        note: 'Sewa Kos Juli',
        amount: 1750000,
        type: 'expense',
        category: 'Kebutuhan Rumah',
        occurredAt: DateTime(2026, 7, 1, 10, 0),
        isConfirmed: true,
      ),
      TransactionItem(
        id: 'tx_jul_03',
        note: 'Belanja Bulanan & Kebutuhan',
        amount: 1100000,
        type: 'expense',
        category: 'Belanja',
        occurredAt: DateTime(2026, 7, 10, 15, 0),
        isConfirmed: true,
      ),
      TransactionItem(
        id: 'tx_jul_04',
        note: 'Makan & Minum Harian',
        amount: 1400000,
        type: 'expense',
        category: 'Makan & Minuman',
        occurredAt: DateTime(2026, 7, 20, 18, 0),
        isConfirmed: true,
      ),
      TransactionItem(
        id: 'tx_jul_05',
        note: 'Tagihan Listrik & Air',
        amount: 580000,
        type: 'expense',
        category: 'Tagihan & Utilitas',
        occurredAt: DateTime(2026, 7, 5, 11, 0),
        isConfirmed: true,
      ),
      TransactionItem(
        id: 'tx_jul_06',
        note: 'Bensin & Transportasi',
        amount: 320000,
        type: 'expense',
        category: 'Transportasi',
        occurredAt: DateTime(2026, 7, 14, 8, 0),
        isConfirmed: true,
      ),
    ];
  }

  static IconData getCategoryIcon(String categoryName) {
    final lower = categoryName.toLowerCase();
    if (lower.contains('makan') || lower.contains('minum') || lower.contains('kopi')) {
      return Icons.restaurant_rounded;
    }
    if (lower.contains('trans') || lower.contains('bensin') || lower.contains('ojol')) {
      return Icons.directions_car_rounded;
    }
    if (lower.contains('belanja') || lower.contains('baju')) {
      return Icons.shopping_bag_rounded;
    }
    if (lower.contains('hiburan') || lower.contains('bioskop') || lower.contains('game')) {
      return Icons.sports_esports_rounded;
    }
    if (lower.contains('tagihan') || lower.contains('listrik') || lower.contains('wifi')) {
      return Icons.receipt_long_rounded;
    }
    if (lower.contains('hutang') || lower.contains('paylater')) {
      return Icons.credit_card_rounded;
    }
    if (lower.contains('rumah') || lower.contains('kos')) {
      return Icons.home_rounded;
    }
    if (lower.contains('sehat') || lower.contains('obat')) {
      return Icons.local_hospital_rounded;
    }
    if (lower.contains('gym') || lower.contains('fit')) {
      return Icons.fitness_center_rounded;
    }
    if (lower.contains('skin') || lower.contains('rawat')) {
      return Icons.face_retouching_natural_rounded;
    }
    if (lower.contains('gaji')) {
      return Icons.account_balance_wallet_rounded;
    }
    if (lower.contains('freelance') || lower.contains('proyek')) {
      return Icons.laptop_mac_rounded;
    }
    if (lower.contains('bonus')) {
      return Icons.card_giftcard_rounded;
    }
    if (lower.contains('invest')) {
      return Icons.trending_up_rounded;
    }
    if (lower.contains('masuk') || lower.contains('kirim')) {
      return Icons.move_to_inbox_rounded;
    }
    return Icons.bookmark_border_rounded;
  }

  static Color getCategoryColor(String categoryName) {
    final lower = categoryName.toLowerCase();
    if (lower.contains('makan') || lower.contains('minum')) return Colors.orange;
    if (lower.contains('trans') || lower.contains('bensin')) return Colors.blue;
    if (lower.contains('belanja')) return Colors.pink;
    if (lower.contains('hiburan')) return Colors.purple;
    if (lower.contains('tagihan')) return Colors.indigo;
    if (lower.contains('hutang') || lower.contains('paylater')) return Colors.red;
    if (lower.contains('rumah')) return Colors.teal;
    if (lower.contains('sehat')) return Colors.green;
    if (lower.contains('gym')) return Colors.amber.shade800;
    if (lower.contains('skin')) return Colors.deepPurple;
    if (lower.contains('gaji')) return Colors.green.shade700;
    if (lower.contains('freelance')) return Colors.cyan.shade700;
    if (lower.contains('bonus')) return Colors.amber.shade700;
    if (lower.contains('invest')) return Colors.teal.shade700;
    return Colors.blueGrey;
  }

  /// Calculates or compiles complete MonthlyRekapData for a given month.
  static MonthlyRekapData getMonthlyRekap({
    required String month,
    List<TransactionItem>? activeTransactions,
  }) {
    List<TransactionItem> allTx;
    double lastMonthExpense = 0;
    double lastMonthIncome = 0;

    if (month == '2026-09') {
      final base = getBaselineSeptemberTransactions();
      final Map<String, TransactionItem> map = {
        for (var t in base) t.id: t,
      };

      // Merge active user transactions if provided
      if (activeTransactions != null) {
        for (var t in activeTransactions) {
          if (t.occurredAt.year == 2026 && t.occurredAt.month == 9) {
            map[t.id] = t;
          }
        }
      }

      allTx = map.values.toList();
      lastMonthExpense = 6250000;
      lastMonthIncome = 10500000;
    } else if (month == '2026-08') {
      allTx = getBaselineAugustTransactions();
      lastMonthExpense = 5150000;
      lastMonthIncome = 8500000;
    } else if (month == '2026-07') {
      allTx = getBaselineJulyTransactions();
      lastMonthExpense = 4800000;
      lastMonthIncome = 8500000;
    } else {
      allTx = [];
      lastMonthExpense = 0;
      lastMonthIncome = 0;
    }

    allTx.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    // Calculate totals
    double totalIncome = 0;
    double totalExpense = 0;
    int confirmedCount = 0;
    int pendingCount = 0;

    final Map<String, Map<String, dynamic>> categoryMap = {};

    for (var tx in allTx) {
      if (tx.isConfirmed) {
        confirmedCount++;
      } else {
        pendingCount++;
      }

      if (tx.isIncome) {
        totalIncome += tx.amount;
      } else {
        totalExpense += tx.amount;
      }

      final key = '${tx.type}_${tx.category}';
      if (!categoryMap.containsKey(key)) {
        categoryMap[key] = {
          'category': tx.category,
          'type': tx.type,
          'total': 0.0,
          'count': 0,
          'isCustom': tx.isCustomCategory,
        };
      }
      categoryMap[key]!['total'] = (categoryMap[key]!['total'] as double) + tx.amount;
      categoryMap[key]!['count'] = (categoryMap[key]!['count'] as int) + 1;
    }

    final netSavings = totalIncome - totalExpense;
    final savingsRate = totalIncome > 0
        ? ((totalIncome - totalExpense) / totalIncome) * 100
        : 0.0;

    final expenseDiffPct = lastMonthExpense > 0
        ? ((totalExpense - lastMonthExpense) / lastMonthExpense) * 100
        : 0.0;
    final incomeDiffPct = lastMonthIncome > 0
        ? ((totalIncome - lastMonthIncome) / lastMonthIncome) * 100
        : 0.0;

    // Create Category Breakdown list
    final List<CategoryBreakdownItem> breakdown = [];
    for (var entry in categoryMap.values) {
      final type = entry['type'] as String;
      final amount = entry['total'] as double;
      final denominator = type == 'expense' ? totalExpense : totalIncome;
      final pct = denominator > 0 ? (amount / denominator) * 100 : 0.0;
      final catName = entry['category'] as String;

      breakdown.add(CategoryBreakdownItem(
        category: catName,
        type: type,
        total: amount,
        percentage: pct,
        transactionCount: entry['count'] as int,
        icon: getCategoryIcon(catName),
        color: getCategoryColor(catName),
        isCustom: entry['isCustom'] as bool,
      ));
    }

    breakdown.sort((a, b) => b.total.compareTo(a.total));

    return MonthlyRekapData(
      month: month,
      monthLabel: getMonthLabel(month),
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netSavings: netSavings,
      savingsRate: savingsRate,
      confirmedTransactionsCount: confirmedCount,
      pendingTransactionsCount: pendingCount,
      lastMonthTotalExpense: lastMonthExpense,
      lastMonthTotalIncome: lastMonthIncome,
      expenseDiffPct: expenseDiffPct,
      incomeDiffPct: incomeDiffPct,
      categoryBreakdown: breakdown,
      transactions: allTx,
    );
  }

  /// Returns an empty MonthlyRekapData with zero totals and empty lists.
  static MonthlyRekapData getEmptyMonthlyRekap({
    String month = '2026-10',
    String monthLabel = 'Oktober 2026',
  }) {
    return MonthlyRekapData(
      month: month,
      monthLabel: monthLabel,
      totalIncome: 0,
      totalExpense: 0,
      netSavings: 0,
      savingsRate: 0,
      confirmedTransactionsCount: 0,
      pendingTransactionsCount: 0,
      lastMonthTotalExpense: 0,
      lastMonthTotalIncome: 0,
      expenseDiffPct: 0,
      incomeDiffPct: 0,
      categoryBreakdown: const [],
      transactions: const [],
    );
  }
}
