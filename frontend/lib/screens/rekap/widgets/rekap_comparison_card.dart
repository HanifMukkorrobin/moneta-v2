import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/monthly_rekap_data.dart';
import '../../../theme/app_theme.dart';

class RekapComparisonCard extends StatelessWidget {
  final MonthlyRekapData data;

  const RekapComparisonCard({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    if (data.lastMonthTotalExpense <= 0 && data.lastMonthTotalIncome <= 0) {
      return const SizedBox.shrink();
    }

    final isExpenseLower = data.expenseDiffPct <= 0;
    final expenseDiffAbs = data.expenseDiffPct.abs();
    final expenseNominalDiff = (data.totalExpense - data.lastMonthTotalExpense).abs();

    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isExpenseLower
            ? AppTheme.incomeColor.withValues(alpha: 0.05)
            : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpenseLower
              ? AppTheme.incomeColor.withValues(alpha: 0.25)
              : Colors.amber.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isExpenseLower
                  ? AppTheme.incomeColor.withValues(alpha: 0.15)
                  : Colors.amber.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isExpenseLower
                  ? Icons.trending_down_rounded
                  : Icons.trending_up_rounded,
              size: 20,
              color: isExpenseLower ? AppTheme.incomeColor : Colors.amber.shade900,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isExpenseLower ? 'Kabar Baik! ' : 'Perhatian Pengeluaran! ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isExpenseLower
                            ? AppTheme.incomeColor
                            : Colors.amber.shade900,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isExpenseLower ? AppTheme.incomeColor : Colors.amber.shade800)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${isExpenseLower ? 'Hemat' : 'Naik'} ${expenseDiffAbs.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isExpenseLower
                              ? AppTheme.incomeColor
                              : Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isExpenseLower
                      ? 'Pengeluaran bulan ini lebih hemat ${currencyFormatter.format(expenseNominalDiff)} dibandingkan bulan lalu.'
                      : 'Pengeluaran bulan ini meningkat ${currencyFormatter.format(expenseNominalDiff)} dibandingkan bulan lalu.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.35,
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
