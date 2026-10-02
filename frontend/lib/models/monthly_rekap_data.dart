import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/category_icon_mapper.dart';
import 'transaction_item.dart';

class CategoryBreakdownItem {
  final String category;
  final String type; // 'expense' or 'income'
  final double total;
  final double percentage; // 0.0 - 100.0
  final int transactionCount;
  final IconData? icon;
  final Color? color;
  final bool isCustom;

  const CategoryBreakdownItem({
    required this.category,
    required this.type,
    required this.total,
    required this.percentage,
    required this.transactionCount,
    this.icon,
    this.color,
    this.isCustom = false,
  });

  bool get isExpense => type == 'expense';
  bool get isIncome => type == 'income';

  String get formattedTotal {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(total);
  }

  String get formattedPercentage {
    return '${percentage.toStringAsFixed(1)}%';
  }

  factory CategoryBreakdownItem.fromJson(Map<String, dynamic> json) {
    final catName = (json['category'] ?? json['categoryName'] ?? json['name'] ?? 'Lainnya').toString();
    final typeVal = (json['type'] ?? 'expense').toString().toLowerCase() == 'income'
        ? 'income'
        : 'expense';
    final rawTotal = json['total'] ?? json['amount'] ?? 0;
    final rawPct = json['percentage'] ?? json['sharePct'] ?? 0;
    final rawCount = json['transactionCount'] ?? json['transaction_count'] ?? json['count'] ?? 0;
    final rawCustom = json['isCustom'] ?? json['is_custom'];
    final isCustomVal = rawCustom == true || rawCustom == 1 || rawCustom == '1';

    return CategoryBreakdownItem(
      category: catName,
      type: typeVal,
      total: rawTotal is num ? rawTotal.toDouble() : (double.tryParse(rawTotal.toString()) ?? 0.0),
      percentage: rawPct is num ? rawPct.toDouble() : (double.tryParse(rawPct.toString()) ?? 0.0),
      transactionCount: rawCount is num ? rawCount.toInt() : (int.tryParse(rawCount.toString()) ?? 0),
      icon: CategoryIconMapper.getCategoryIcon(
        catName,
        iconKey: json['icon']?.toString(),
        type: typeVal,
      ),
      color: CategoryIconMapper.getCategoryColor(
        catName,
        colorHex: json['color']?.toString(),
        type: typeVal,
      ),
      isCustom: isCustomVal,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'type': type,
      'total': total,
      'percentage': percentage,
      'transactionCount': transactionCount,
      'isCustom': isCustom,
    };
  }
}

class MonthlyRekapData {
  final String month; // e.g. "2026-09"
  final String monthLabel; // e.g. "September 2026"
  final double totalIncome;
  final double totalExpense;
  final double netSavings;
  final double savingsRate; // 0.0 - 100.0
  final int confirmedTransactionsCount;
  final int pendingTransactionsCount;
  final double lastMonthTotalExpense;
  final double lastMonthTotalIncome;
  final double expenseDiffPct; // difference vs last month (-10.5 means 10.5% lower)
  final double incomeDiffPct;
  final List<CategoryBreakdownItem> categoryBreakdown;
  final List<TransactionItem> transactions;

  const MonthlyRekapData({
    required this.month,
    required this.monthLabel,
    required this.totalIncome,
    required this.totalExpense,
    required this.netSavings,
    required this.savingsRate,
    required this.confirmedTransactionsCount,
    required this.pendingTransactionsCount,
    required this.lastMonthTotalExpense,
    required this.lastMonthTotalIncome,
    required this.expenseDiffPct,
    required this.incomeDiffPct,
    required this.categoryBreakdown,
    required this.transactions,
  });

  factory MonthlyRekapData.empty({
    String month = '2026-10',
    String? monthLabel,
  }) {
    return MonthlyRekapData(
      month: month,
      monthLabel: monthLabel ?? CategoryIconMapper.getMonthLabel(month),
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

  factory MonthlyRekapData.fromJson(Map<String, dynamic> json) {
    final monthStr = (json['month'] ?? '2026-09').toString();
    final labelStr = (json['monthLabel'] ??
            json['month_label'] ??
            CategoryIconMapper.getMonthLabel(monthStr))
        .toString();

    double toDoubleVal(dynamic v) =>
        v is num ? v.toDouble() : (v != null ? (double.tryParse(v.toString()) ?? 0.0) : 0.0);
    int toIntVal(dynamic v) =>
        v is num ? v.toInt() : (v != null ? (int.tryParse(v.toString()) ?? 0) : 0);

    final rawBreakdown = json['categoryBreakdown'] ?? json['category_breakdown'] ?? [];
    final breakdownList = <CategoryBreakdownItem>[];
    if (rawBreakdown is List) {
      for (final item in rawBreakdown) {
        if (item is Map<String, dynamic>) {
          breakdownList.add(CategoryBreakdownItem.fromJson(item));
        }
      }
    }

    final rawTx = json['transactions'] ?? [];
    final txList = <TransactionItem>[];
    if (rawTx is List) {
      for (final item in rawTx) {
        if (item is Map<String, dynamic>) {
          txList.add(TransactionItem.fromJson(item));
        }
      }
    }

    final totalInc = toDoubleVal(json['totalIncome'] ?? json['total_income']);
    final totalExp = toDoubleVal(json['totalExpense'] ?? json['total_expense']);
    final netSav = json['netSavings'] != null || json['net_savings'] != null
        ? toDoubleVal(json['netSavings'] ?? json['net_savings'])
        : (totalInc - totalExp);
    final savRate = json['savingsRate'] != null || json['savings_rate'] != null
        ? toDoubleVal(json['savingsRate'] ?? json['savings_rate'])
        : (totalInc > 0 ? ((totalInc - totalExp) / totalInc) * 100 : 0.0);

    return MonthlyRekapData(
      month: monthStr,
      monthLabel: labelStr,
      totalIncome: totalInc,
      totalExpense: totalExp,
      netSavings: netSav,
      savingsRate: savRate,
      confirmedTransactionsCount: toIntVal(
        json['confirmedTransactionsCount'] ??
            json['confirmed_transactions_count'] ??
            json['confirmedCount'] ??
            txList.where((t) => t.isConfirmed).length,
      ),
      pendingTransactionsCount: toIntVal(
        json['pendingTransactionsCount'] ??
            json['pending_transactions_count'] ??
            json['pendingCount'] ??
            txList.where((t) => !t.isConfirmed).length,
      ),
      lastMonthTotalExpense: toDoubleVal(
        json['lastMonthTotalExpense'] ?? json['last_month_total_expense'],
      ),
      lastMonthTotalIncome: toDoubleVal(
        json['lastMonthTotalIncome'] ?? json['last_month_total_income'],
      ),
      expenseDiffPct: toDoubleVal(
        json['expenseDiffPct'] ?? json['expense_diff_pct'],
      ),
      incomeDiffPct: toDoubleVal(
        json['incomeDiffPct'] ?? json['income_diff_pct'],
      ),
      categoryBreakdown: breakdownList,
      transactions: txList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'month': month,
      'monthLabel': monthLabel,
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
      'netSavings': netSavings,
      'savingsRate': savingsRate,
      'confirmedTransactionsCount': confirmedTransactionsCount,
      'pendingTransactionsCount': pendingTransactionsCount,
      'lastMonthTotalExpense': lastMonthTotalExpense,
      'lastMonthTotalIncome': lastMonthTotalIncome,
      'expenseDiffPct': expenseDiffPct,
      'incomeDiffPct': incomeDiffPct,
      'categoryBreakdown': categoryBreakdown.map((e) => e.toJson()).toList(),
      'transactions': transactions.map((e) => e.toJson()).toList(),
    };
  }

  bool get isSurplus => netSavings >= 0;

  int get daysInMonth {
    try {
      final parts = month.split('-');
      if (parts.length == 2) {
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        return DateTime(y, m + 1, 0).day;
      }
    } catch (_) {}
    return 30;
  }

  int get incomeTransactionsCount =>
      transactions.where((t) => t.isIncome).length;

  int get expenseTransactionsCount =>
      transactions.where((t) => t.isExpense).length;

  double get averageDailyExpense =>
      daysInMonth > 0 ? totalExpense / daysInMonth : 0.0;

  String get formattedAverageDailyExpense {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(averageDailyExpense);
  }

  double get expenseRatio =>
      totalIncome > 0 ? (totalExpense / totalIncome) * 100 : 0.0;

  String get formattedExpenseRatio => '${expenseRatio.toStringAsFixed(1)}%';

  String get formattedIncomeDiffPct {
    final prefix = incomeDiffPct >= 0 ? '+' : '';
    return '$prefix${incomeDiffPct.toStringAsFixed(1)}%';
  }

  String get formattedExpenseDiffPct {
    final prefix = expenseDiffPct >= 0 ? '+' : '';
    return '$prefix${expenseDiffPct.toStringAsFixed(1)}%';
  }

  TransactionItem? get largestExpense {
    final expenses = transactions.where((t) => t.isExpense).toList();
    if (expenses.isEmpty) return null;
    expenses.sort((a, b) => b.amount.compareTo(a.amount));
    return expenses.first;
  }

  TransactionItem? get largestIncome {
    final incomes = transactions.where((t) => t.isIncome).toList();
    if (incomes.isEmpty) return null;
    incomes.sort((a, b) => b.amount.compareTo(a.amount));
    return incomes.first;
  }

  String get formattedTotalIncome {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(totalIncome);
  }

  String get formattedTotalExpense {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(totalExpense);
  }

  String get formattedNetSavings {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final prefix = netSavings >= 0 ? '+ ' : '- ';
    return '$prefix${formatter.format(netSavings.abs())}';
  }

  String get formattedSavingsRate {
    return '${savingsRate.toStringAsFixed(1)}%';
  }

  List<CategoryBreakdownItem> get expenseBreakdown =>
      categoryBreakdown.where((c) => c.isExpense).toList();

  List<CategoryBreakdownItem> get incomeBreakdown =>
      categoryBreakdown.where((c) => c.isIncome).toList();

  static const List<String> availableMonths = CategoryIconMapper.availableMonths;

  static String getMonthLabel(String monthKey) =>
      CategoryIconMapper.getMonthLabel(monthKey);

  static IconData getCategoryIcon(String categoryName) =>
      CategoryIconMapper.getCategoryIcon(categoryName);

  static Color getCategoryColor(String categoryName) =>
      CategoryIconMapper.getCategoryColor(categoryName);

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

  static MonthlyRekapData getMonthlyRekap({
    required String month,
    List<TransactionItem>? activeTransactions,
    bool includeBaseline = false,
  }) {
    List<TransactionItem> allTx = [];
    double lastMonthExpense = 0;
    double lastMonthIncome = 0;

    if (includeBaseline) {
      if (month == '2026-09') {
        allTx = getBaselineSeptemberTransactions();
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
      }
    }

    if (activeTransactions != null && activeTransactions.isNotEmpty) {
      final matching = activeTransactions.where((t) {
        final ym =
            '${t.occurredAt.year}-${t.occurredAt.month.toString().padLeft(2, '0')}';
        return ym == month;
      }).toList();
      if (!includeBaseline) {
        allTx = matching;
      } else {
        allTx.addAll(matching);
      }
    }

    allTx.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

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
      categoryMap[key]!['total'] =
          (categoryMap[key]!['total'] as double) + tx.amount;
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

  static MonthlyRekapData getEmptyMonthlyRekap({
    String month = '2026-10',
    String monthLabel = 'Oktober 2026',
  }) {
    return MonthlyRekapData.empty(month: month, monthLabel: monthLabel);
  }
}
