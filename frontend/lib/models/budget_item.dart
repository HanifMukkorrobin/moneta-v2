import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/app_env.dart';
import '../utils/category_icon_mapper.dart';

enum BudgetBucketType {
  needs, // Kebutuhan (50%)
  savings, // Tabungan / Investasi (30%)
  fun; // Hiburan / Keinginan (20%)

  static BudgetBucketType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'savings':
      case 'tabungan':
        return BudgetBucketType.savings;
      case 'fun':
      case 'hiburan':
      case 'wants':
        return BudgetBucketType.fun;
      case 'needs':
      case 'kebutuhan':
      default:
        return BudgetBucketType.needs;
    }
  }
}

class BudgetBucketItem {
  final BudgetBucketType type;
  final String title;
  final double percentage; // e.g. 50.0
  final double amountLimit;
  final double amountSpent;
  final Color color;
  final IconData icon;

  const BudgetBucketItem({
    required this.type,
    required this.title,
    required this.percentage,
    required this.amountLimit,
    required this.amountSpent,
    required this.color,
    required this.icon,
  });

  double get amountRemaining => (amountLimit - amountSpent).clamp(0, double.infinity);
  double get percentageUsed => amountLimit > 0 ? (amountSpent / amountLimit) * 100 : 0.0;
  bool get isOverBudget => amountSpent > amountLimit;

  String get formattedLimit => NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(amountLimit);

  String get formattedSpent => NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(amountSpent);

  String get formattedRemaining => NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(amountRemaining);

  static Color defaultColorForType(BudgetBucketType type) {
    switch (type) {
      case BudgetBucketType.needs:
        return const Color(0xFF2563EB);
      case BudgetBucketType.savings:
        return const Color(0xFF10B981);
      case BudgetBucketType.fun:
        return const Color(0xFF8B5CF6);
    }
  }

  static IconData defaultIconForType(BudgetBucketType type) {
    switch (type) {
      case BudgetBucketType.needs:
        return Icons.home_work_rounded;
      case BudgetBucketType.savings:
        return Icons.savings_rounded;
      case BudgetBucketType.fun:
        return Icons.celebration_rounded;
    }
  }

  static String defaultTitleForType(BudgetBucketType type) {
    switch (type) {
      case BudgetBucketType.needs:
        return 'Kebutuhan Pokok';
      case BudgetBucketType.savings:
        return 'Tabungan & Investasi';
      case BudgetBucketType.fun:
        return 'Hiburan & Keinginan';
    }
  }

  factory BudgetBucketItem.fromJson(Map<String, dynamic> json) {
    final bucketType = BudgetBucketType.fromString(
      (json['type'] ?? json['key'] ?? 'needs').toString(),
    );
    double toD(dynamic v) =>
        v is num ? v.toDouble() : (v != null ? (double.tryParse(v.toString()) ?? 0.0) : 0.0);

    return BudgetBucketItem(
      type: bucketType,
      title: (json['title'] ?? json['label'] ?? defaultTitleForType(bucketType)).toString(),
      percentage: toD(json['percentage'] ?? json['allocationPct']),
      amountLimit: toD(json['amountLimit'] ?? json['limit'] ?? json['allocatedAmount']),
      amountSpent: toD(json['amountSpent'] ?? json['spent'] ?? json['spentAmount']),
      color: defaultColorForType(bucketType),
      icon: defaultIconForType(bucketType),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'title': title,
      'percentage': percentage,
      'amountLimit': amountLimit,
      'amountSpent': amountSpent,
    };
  }
}

class CategoryBudgetItem {
  final String id;
  final String categoryName;
  final BudgetBucketType bucketType;
  final double amountLimit;
  final double amountSpent;
  final IconData icon;
  final Color color;

  const CategoryBudgetItem({
    required this.id,
    required this.categoryName,
    required this.bucketType,
    required this.amountLimit,
    required this.amountSpent,
    required this.icon,
    required this.color,
  });

  double get amountRemaining => (amountLimit - amountSpent);
  double get percentageUsed => amountLimit > 0 ? (amountSpent / amountLimit) * 100 : 0.0;
  bool get isOverBudget => amountSpent > amountLimit;

  String get formattedLimit => NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(amountLimit);

  String get formattedSpent => NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(amountSpent);

  String get formattedRemaining => NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(amountRemaining.abs());

  String get bucketLabel {
    switch (bucketType) {
      case BudgetBucketType.needs:
        return 'Kebutuhan';
      case BudgetBucketType.savings:
        return 'Tabungan';
      case BudgetBucketType.fun:
        return 'Hiburan';
    }
  }

  factory CategoryBudgetItem.fromJson(Map<String, dynamic> json) {
    final catName = (json['categoryName'] ?? json['category_name'] ?? json['category'] ?? 'Lainnya').toString();
    final bType = BudgetBucketType.fromString(
      (json['bucketType'] ?? json['bucket_type'] ?? json['bucket'] ?? 'needs').toString(),
    );
    double toD(dynamic v) =>
        v is num ? v.toDouble() : (v != null ? (double.tryParse(v.toString()) ?? 0.0) : 0.0);

    return CategoryBudgetItem(
      id: (json['id'] ?? 'b_cat_${catName.hashCode}').toString(),
      categoryName: catName,
      bucketType: bType,
      amountLimit: toD(json['amountLimit'] ?? json['amount_limit'] ?? json['limit']),
      amountSpent: toD(json['amountSpent'] ?? json['amount_spent'] ?? json['spent']),
      icon: CategoryIconMapper.getCategoryIcon(catName, iconKey: json['icon']?.toString()),
      color: CategoryIconMapper.getCategoryColor(catName, colorHex: json['color']?.toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'categoryName': categoryName,
      'bucketType': bucketType.name,
      'amountLimit': amountLimit,
      'amountSpent': amountSpent,
    };
  }
}

class MonthlyBudgetSummary {
  final String month;
  final String monthLabel;
  final double totalBudget;
  final double totalSpent;
  final double needsPercentage;
  final double savingsPercentage;
  final double funPercentage;
  final List<BudgetBucketItem> buckets;
  final List<CategoryBudgetItem> categoryBudgets;

  const MonthlyBudgetSummary({
    required this.month,
    required this.monthLabel,
    required this.totalBudget,
    required this.totalSpent,
    required this.needsPercentage,
    required this.savingsPercentage,
    required this.funPercentage,
    required this.buckets,
    required this.categoryBudgets,
  });

  static List<BudgetBucketItem> buildBuckets({
    double? totalBudget,
    double? needsPct,
    double? savingsPct,
    double? funPct,
    double needsSpent = 1600000,
    double savingsSpent = 800000,
    double funSpent = 450000,
  }) {
    final total = totalBudget ?? AppEnv.defaultMonthlyBudget;
    final nPct = needsPct ?? AppEnv.defaultNeedsPct;
    final sPct = savingsPct ?? AppEnv.defaultSavingsPct;
    final fPct = funPct ?? AppEnv.defaultFunPct;

    return [
      BudgetBucketItem(
        type: BudgetBucketType.needs,
        title: 'Kebutuhan Pokok',
        percentage: nPct,
        amountLimit: total * (nPct / 100),
        amountSpent: needsSpent,
        color: const Color(0xFF2563EB),
        icon: Icons.home_work_rounded,
      ),
      BudgetBucketItem(
        type: BudgetBucketType.savings,
        title: 'Tabungan & Investasi',
        percentage: sPct,
        amountLimit: total * (sPct / 100),
        amountSpent: savingsSpent,
        color: const Color(0xFF10B981),
        icon: Icons.savings_rounded,
      ),
      BudgetBucketItem(
        type: BudgetBucketType.fun,
        title: 'Hiburan & Keinginan',
        percentage: fPct,
        amountLimit: total * (fPct / 100),
        amountSpent: funSpent,
        color: const Color(0xFF8B5CF6),
        icon: Icons.celebration_rounded,
      ),
    ];
  }

  factory MonthlyBudgetSummary.empty({
    String month = '2026-10',
    String? monthLabel,
  }) {
    return MonthlyBudgetSummary(
      month: month,
      monthLabel: monthLabel ?? CategoryIconMapper.getMonthLabel(month),
      totalBudget: 0,
      totalSpent: 0,
      needsPercentage: AppEnv.defaultNeedsPct,
      savingsPercentage: AppEnv.defaultSavingsPct,
      funPercentage: AppEnv.defaultFunPct,
      buckets: const [],
      categoryBudgets: const [],
    );
  }

  factory MonthlyBudgetSummary.fromJson(Map<String, dynamic> json) {
    final monthStr = (json['month'] ?? '2026-09').toString();
    final labelStr = (json['monthLabel'] ??
            json['month_label'] ??
            CategoryIconMapper.getMonthLabel(monthStr))
        .toString();

    double toD(dynamic v, [double fallback = 0.0]) =>
        v is num ? v.toDouble() : (v != null ? (double.tryParse(v.toString()) ?? fallback) : fallback);

    final totalBudgetVal = toD(
      json['totalBudget'] ?? json['total_budget'] ?? json['amountLimit'],
      AppEnv.defaultMonthlyBudget,
    );
    final needsPctVal = toD(
      json['needsPercentage'] ?? json['needs_pct'] ?? json['needsPct'],
      AppEnv.defaultNeedsPct,
    );
    final savingsPctVal = toD(
      json['savingsPercentage'] ?? json['savings_pct'] ?? json['savingsPct'],
      AppEnv.defaultSavingsPct,
    );
    final funPctVal = toD(
      json['funPercentage'] ?? json['fun_pct'] ?? json['funPct'],
      AppEnv.defaultFunPct,
    );

    final rawBuckets = json['buckets'] ?? [];
    final bucketList = <BudgetBucketItem>[];
    if (rawBuckets is List) {
      for (final item in rawBuckets) {
        if (item is Map<String, dynamic>) {
          bucketList.add(BudgetBucketItem.fromJson(item));
        }
      }
    }

    final rawCatBudgets = json['categoryBudgets'] ?? json['category_budgets'] ?? [];
    final catBudgetList = <CategoryBudgetItem>[];
    if (rawCatBudgets is List) {
      for (final item in rawCatBudgets) {
        if (item is Map<String, dynamic>) {
          catBudgetList.add(CategoryBudgetItem.fromJson(item));
        }
      }
    }

    double totalSpentVal = toD(json['totalSpent'] ?? json['total_spent'] ?? json['amountSpent']);
    if (totalSpentVal == 0 && bucketList.isNotEmpty) {
      totalSpentVal = bucketList.fold(0.0, (sum, b) => sum + b.amountSpent);
    }

    return MonthlyBudgetSummary(
      month: monthStr,
      monthLabel: labelStr,
      totalBudget: totalBudgetVal,
      totalSpent: totalSpentVal,
      needsPercentage: needsPctVal,
      savingsPercentage: savingsPctVal,
      funPercentage: funPctVal,
      buckets: bucketList,
      categoryBudgets: catBudgetList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'month': month,
      'monthLabel': monthLabel,
      'totalBudget': totalBudget,
      'totalSpent': totalSpent,
      'needsPercentage': needsPercentage,
      'savingsPercentage': savingsPercentage,
      'funPercentage': funPercentage,
      'buckets': buckets.map((b) => b.toJson()).toList(),
      'categoryBudgets': categoryBudgets.map((c) => c.toJson()).toList(),
    };
  }

  double get totalRemaining => totalBudget - totalSpent;
  double get percentageUsed => totalBudget > 0 ? (totalSpent / totalBudget) * 100 : 0.0;
  double get remainingPercentage => totalBudget > 0
      ? ((totalRemaining / totalBudget) * 100).clamp(0.0, 100.0)
      : 0.0;
  bool get isOverBudget => totalSpent > totalBudget;

  String get formattedTotalBudget => NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(totalBudget);

  String get formattedTotalSpent => NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(totalSpent);

  String get formattedTotalRemaining => NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(totalRemaining.abs());

  String get formattedRemainingWithSign {
    final formatted = formattedTotalRemaining;
    if (totalRemaining < 0) {
      return '- $formatted';
    }
    return formatted;
  }

  int get daysInMonth {
    try {
      final parts = month.split('-');
      if (parts.length >= 2) {
        final year = int.parse(parts[0]);
        final monthNum = int.parse(parts[1]);
        return DateTime(year, monthNum + 1, 0).day;
      }
    } catch (_) {}
    return 30;
  }

  double get dailyRemainingAverage {
    if (totalRemaining <= 0 || daysInMonth <= 0) return 0.0;
    return totalRemaining / daysInMonth;
  }

  String get formattedDailyRemainingAverage {
    final formatted = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(dailyRemainingAverage);
    return '$formatted / hari';
  }

  String get remainingStatusLabel {
    if (isOverBudget) {
      return 'Batas Terlampaui';
    } else if (remainingPercentage <= 15.0) {
      return 'Batas Menipis';
    } else if (remainingPercentage <= 30.0) {
      return 'Perlu Hemat';
    } else {
      return 'Batas Aman';
    }
  }

  static const double defaultTotalBudget = 6000000;
  static const double defaultNeedsPct = 50.0;
  static const double defaultSavingsPct = 30.0;
  static const double defaultFunPct = 20.0;

  static List<BudgetBucketItem> getDefaultBuckets({
    double totalBudget = defaultTotalBudget,
    double needsSpent = 1600000,
    double savingsSpent = 800000,
    double funSpent = 450000,
  }) {
    return buildBuckets(
      totalBudget: totalBudget,
      needsPct: defaultNeedsPct,
      savingsPct: defaultSavingsPct,
      funPct: defaultFunPct,
      needsSpent: needsSpent,
      savingsSpent: savingsSpent,
      funSpent: funSpent,
    );
  }

  static List<CategoryBudgetItem> getDefaultCategoryBudgets() {
    return const [
      CategoryBudgetItem(
        id: 'b_cat_1',
        categoryName: 'Sewa Kos & Tagihan Rumah',
        bucketType: BudgetBucketType.needs,
        amountLimit: 1750000,
        amountSpent: 1750000,
        icon: Icons.home_rounded,
        color: Colors.blue,
      ),
      CategoryBudgetItem(
        id: 'b_cat_2',
        categoryName: 'Makan & Minuman',
        bucketType: BudgetBucketType.needs,
        amountLimit: 1250000,
        amountSpent: 980000,
        icon: Icons.fastfood_rounded,
        color: Colors.orange,
      ),
      CategoryBudgetItem(
        id: 'b_cat_3',
        categoryName: 'Transportasi Harian',
        bucketType: BudgetBucketType.needs,
        amountLimit: 400000,
        amountSpent: 320000,
        icon: Icons.directions_bike_rounded,
        color: Colors.cyan,
      ),
      CategoryBudgetItem(
        id: 'b_cat_4',
        categoryName: 'Reksadana & Tabungan Darurat',
        bucketType: BudgetBucketType.savings,
        amountLimit: 1800000,
        amountSpent: 1500000,
        icon: Icons.account_balance_rounded,
        color: Colors.green,
      ),
      CategoryBudgetItem(
        id: 'b_cat_5',
        categoryName: 'Nongkrong & Bioskop',
        bucketType: BudgetBucketType.fun,
        amountLimit: 750000,
        amountSpent: 650000,
        icon: Icons.movie_rounded,
        color: Colors.purple,
      ),
      CategoryBudgetItem(
        id: 'b_cat_6',
        categoryName: 'Belanja & Skincare',
        bucketType: BudgetBucketType.fun,
        amountLimit: 450000,
        amountSpent: 450000,
        icon: Icons.shopping_bag_rounded,
        color: Colors.pink,
      ),
    ];
  }

  static MonthlyBudgetSummary getMonthlyBudget({String month = '2026-09'}) {
    if (month == '2026-10' || month == 'empty_month') {
      return getEmptyBudget(month: month, monthLabel: 'Oktober 2026');
    }

    String monthLabel = 'September 2026';
    List<BudgetBucketItem> buckets;

    if (month == '2026-08') {
      monthLabel = 'Agustus 2026';
      buckets = getDefaultBuckets(
        totalBudget: defaultTotalBudget,
        needsSpent: 2800000,
        savingsSpent: 1600000,
        funSpent: 1000000,
      );
    } else if (month == '2026-07') {
      monthLabel = 'Juli 2026';
      buckets = getDefaultBuckets(
        totalBudget: defaultTotalBudget,
        needsSpent: 3200000,
        savingsSpent: 1800000,
        funSpent: 1250000,
      );
    } else {
      monthLabel = CategoryIconMapper.getMonthLabel(month);
      buckets = getDefaultBuckets(
        totalBudget: defaultTotalBudget,
        needsSpent: 1600000,
        savingsSpent: 800000,
        funSpent: 450000,
      );
    }

    final categoryBudgets = getDefaultCategoryBudgets();
    double totalSpent = 0;
    for (var b in buckets) {
      totalSpent += b.amountSpent;
    }

    return MonthlyBudgetSummary(
      month: month,
      monthLabel: monthLabel,
      totalBudget: defaultTotalBudget,
      totalSpent: totalSpent,
      needsPercentage: defaultNeedsPct,
      savingsPercentage: defaultSavingsPct,
      funPercentage: defaultFunPct,
      buckets: buckets,
      categoryBudgets: categoryBudgets,
    );
  }

  static MonthlyBudgetSummary getEmptyBudget({
    String month = '2026-10',
    String monthLabel = 'Oktober 2026',
  }) {
    return MonthlyBudgetSummary(
      month: month,
      monthLabel: monthLabel,
      totalBudget: 0,
      totalSpent: 0,
      needsPercentage: defaultNeedsPct,
      savingsPercentage: defaultSavingsPct,
      funPercentage: defaultFunPct,
      buckets: const [],
      categoryBudgets: const [],
    );
  }
}
