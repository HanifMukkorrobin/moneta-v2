import 'package:flutter/material.dart';
import '../models/budget_item.dart';

class BudgetMockData {
  static const double defaultTotalBudget = 6000000;
  static const double defaultNeedsPct = 50.0;
  static const double defaultSavingsPct = 30.0;
  static const double defaultFunPct = 20.0;

  static List<BudgetBucketItem> getDefaultBuckets({double totalBudget = defaultTotalBudget}) {
    final needsLimit = totalBudget * (defaultNeedsPct / 100);
    final savingsLimit = totalBudget * (defaultSavingsPct / 100);
    final funLimit = totalBudget * (defaultFunPct / 100);

    return [
      BudgetBucketItem(
        type: BudgetBucketType.needs,
        title: 'Kebutuhan Pokok',
        percentage: defaultNeedsPct,
        amountLimit: needsLimit,
        amountSpent: 3050000,
        color: const Color(0xFF2563EB), // Blue
        icon: Icons.home_work_rounded,
      ),
      BudgetBucketItem(
        type: BudgetBucketType.savings,
        title: 'Tabungan & Investasi',
        percentage: defaultSavingsPct,
        amountLimit: savingsLimit,
        amountSpent: 1500000,
        color: const Color(0xFF10B981), // Emerald Green
        icon: Icons.savings_rounded,
      ),
      BudgetBucketItem(
        type: BudgetBucketType.fun,
        title: 'Hiburan & Keinginan',
        percentage: defaultFunPct,
        amountLimit: funLimit,
        amountSpent: 1100000,
        color: const Color(0xFF8B5CF6), // Purple
        icon: Icons.celebration_rounded,
      ),
    ];
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

    final buckets = getDefaultBuckets();
    final categoryBudgets = getDefaultCategoryBudgets();

    double totalSpent = 0;
    for (var b in buckets) {
      totalSpent += b.amountSpent;
    }

    return MonthlyBudgetSummary(
      month: month,
      monthLabel: 'September 2026',
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
