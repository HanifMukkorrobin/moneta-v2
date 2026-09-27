import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/monthly_rekap_data.dart';
import '../../../theme/app_theme.dart';

class RekapComparisonCard extends StatelessWidget {
  final MonthlyRekapData data;
  final bool showEmptyPlaceholder;

  const RekapComparisonCard({
    super.key,
    required this.data,
    this.showEmptyPlaceholder = false,
  });

  @override
  Widget build(BuildContext context) {
    if (data.lastMonthTotalExpense <= 0 && data.lastMonthTotalIncome <= 0) {
      if (!showEmptyPlaceholder) {
        return const SizedBox.shrink();
      }
      return Container(
        key: const Key('rekap_comparison_empty_card'),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderSubtle),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.compare_arrows_rounded,
                size: 20,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Perbandingan Bulan Lalu',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Belum ada data transaksi di bulan sebelumnya untuk dibandingkan.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final isExpenseLower = data.expenseDiffPct <= 0;
    final expenseDiffAbs = data.expenseDiffPct.abs();
    final expenseNominalDiff = (data.totalExpense - data.lastMonthTotalExpense).abs();

    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final thisMonthAmountFormatted = currencyFormatter.format(data.totalExpense);
    final lastMonthAmountFormatted = currencyFormatter.format(data.lastMonthTotalExpense);
    final nominalDiffFormatted = currencyFormatter.format(expenseNominalDiff);

    // Proportions for visual bar comparison
    final maxExpense = data.totalExpense > data.lastMonthTotalExpense
        ? data.totalExpense
        : data.lastMonthTotalExpense;
    final thisMonthFraction = maxExpense > 0 ? (data.totalExpense / maxExpense).clamp(0.05, 1.0) : 0.5;
    final lastMonthFraction = maxExpense > 0 ? (data.lastMonthTotalExpense / maxExpense).clamp(0.05, 1.0) : 0.5;

    final statusColor = isExpenseLower ? AppTheme.incomeColor : Colors.amber.shade900;
    final statusBgColor = isExpenseLower
        ? AppTheme.incomeColor.withValues(alpha: 0.08)
        : Colors.amber.shade50;
    final statusBorderColor = isExpenseLower
        ? AppTheme.incomeColor.withValues(alpha: 0.25)
        : Colors.amber.shade200;

    return Container(
      key: const Key('rekap_comparison_card'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + Title + Delta Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isExpenseLower ? Icons.trending_down_rounded : Icons.trending_up_rounded,
                        size: 18,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'Perbandingan Bulan Lalu',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                key: const Key('comparison_badge'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusBorderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isExpenseLower ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                      size: 12,
                      color: statusColor,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${isExpenseLower ? 'Hemat' : 'Naik'} ${expenseDiffAbs.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Two comparative metric cards: Bulan Lalu vs Bulan Ini
          Row(
            children: [
              // Bulan Lalu
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bulan Lalu',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lastMonthAmountFormatted,
                        key: const Key('last_month_expense_text'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: lastMonthFraction,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade400),
                          minHeight: 5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Bulan Ini
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: statusBorderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bulan Ini',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        thisMonthAmountFormatted,
                        key: const Key('this_month_expense_text'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isExpenseLower ? AppTheme.primaryColor : Colors.amber.shade900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: thisMonthFraction,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                          minHeight: 5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Insight & summary explanation text
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: statusBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  isExpenseLower ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                  size: 16,
                  color: statusColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isExpenseLower
                        ? 'Pengeluaran bulan ini lebih hemat $nominalDiffFormatted dibandingkan bulan lalu.'
                        : 'Pengeluaran bulan ini meningkat $nominalDiffFormatted dibandingkan bulan lalu.',
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Convenient export aliases
typedef ExpenseComparisonCard = RekapComparisonCard;
typedef KartuPerbandinganPengeluaran = RekapComparisonCard;
