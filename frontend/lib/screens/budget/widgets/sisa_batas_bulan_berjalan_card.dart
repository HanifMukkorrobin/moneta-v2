import 'package:flutter/material.dart';
import '../../../models/budget_item.dart';
import '../../../theme/app_theme.dart';

class SisaBatasBulanBerjalanCard extends StatelessWidget {
  final MonthlyBudgetSummary summary;
  final VoidCallback? onAdjustBudget;

  const SisaBatasBulanBerjalanCard({
    super.key,
    required this.summary,
    this.onAdjustBudget,
  });

  @override
  Widget build(BuildContext context) {
    final isOver = summary.isOverBudget;
    final remainingPct = summary.remainingPercentage;

    Color statusColor;
    Color statusBg;
    IconData statusIcon;

    if (isOver) {
      statusColor = AppTheme.expenseColor;
      statusBg = AppTheme.expenseColor.withValues(alpha: 0.1);
      statusIcon = Icons.warning_amber_rounded;
    } else if (remainingPct <= 15.0) {
      statusColor = Colors.amber.shade800;
      statusBg = Colors.amber.withValues(alpha: 0.15);
      statusIcon = Icons.info_outline_rounded;
    } else {
      statusColor = AppTheme.incomeColor;
      statusBg = AppTheme.incomeColor.withValues(alpha: 0.12);
      statusIcon = Icons.savings_outlined;
    }

    return Container(
      key: const Key('sisa_batas_bulan_berjalan_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Label & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: statusBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusIcon, size: 16, color: statusColor),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sisa Batas Bulan Berjalan',
                        key: Key('sisa_batas_bulan_berjalan_label'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        summary.monthLabel,
                        key: const Key('sisa_batas_month_label'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                key: const Key('sisa_batas_status_badge'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  summary.remainingStatusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Hero Remaining Amount
          Text(
            summary.formattedRemainingWithSign,
            key: const Key('sisa_batas_bulan_berjalan_amount'),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: statusColor,
            ),
          ),

          const SizedBox(height: 4),

          // Contextual Plafon & Percentage
          Text(
            isOver
                ? 'Pengeluaran ${summary.formattedTotalSpent} telah melebihi plafon ${summary.formattedTotalBudget}'
                : 'Tersisa ${remainingPct.toStringAsFixed(1)}% dari total plafon ${summary.formattedTotalBudget}',
            key: const Key('sisa_batas_persentase_text'),
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),

          const SizedBox(height: 12),

          // Remaining Ratio Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              key: const Key('sisa_batas_progress_bar'),
              value: summary.totalBudget > 0
                  ? (summary.totalRemaining / summary.totalBudget).clamp(0.0, 1.0)
                  : 0.0,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              minHeight: 6,
            ),
          ),

          const SizedBox(height: 12),

          // Daily Safe Spend Advice Info
          Container(
            key: const Key('sisa_batas_harian_info'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Row(
              children: [
                Icon(
                  isOver ? Icons.error_outline_rounded : Icons.lightbulb_outline_rounded,
                  size: 15,
                  color: statusColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isOver
                        ? 'Batas terlampaui sebesar ${summary.formattedTotalRemaining}. Batasi pengeluaran untuk menyeimbangkan keuangan.'
                        : (summary.totalRemaining <= 0
                            ? 'Batas budget bulan berjalan telah habis digunakan.'
                            : 'Estimasi aman belanja: ${summary.formattedDailyRemainingAverage} (tersisa ${summary.daysInMonth} hari).'),
                    key: const Key('sisa_batas_keterangan_text'),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textPrimary,
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
