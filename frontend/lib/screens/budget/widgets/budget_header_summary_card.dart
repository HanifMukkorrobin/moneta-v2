import 'package:flutter/material.dart';
import '../../../models/budget_item.dart';
import '../../../theme/app_theme.dart';
import 'sisa_batas_bulan_berjalan_card.dart';

class BudgetHeaderSummaryCard extends StatelessWidget {
  final MonthlyBudgetSummary summary;
  final VoidCallback? onEditBudget;

  const BudgetHeaderSummaryCard({
    super.key,
    required this.summary,
    this.onEditBudget,
  });

  @override
  Widget build(BuildContext context) {
    final pctUsed = summary.percentageUsed;
    final isOver = summary.isOverBudget;

    Color progressColor;
    if (isOver) {
      progressColor = AppTheme.expenseColor;
    } else if (pctUsed >= 85) {
      progressColor = Colors.amber.shade700;
    } else {
      progressColor = AppTheme.primaryColor;
    }

    return Container(
      key: const Key('budget_header_summary_card'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Title & Month / Edit Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 18,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Anggaran Bulanan',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        summary.monthLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              InkWell(
                key: const Key('edit_budget_button'),
                onTap: onEditBudget,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, size: 13, color: AppTheme.primaryColor),
                      SizedBox(width: 4),
                      Text(
                        'Ubah',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Total Budget Limit vs Spent
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Plafon Budget',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    summary.formattedTotalBudget,
                    key: const Key('total_budget_limit_text'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                key: const Key('budget_status_badge'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: progressColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  isOver ? 'Melebihi Budget!' : '${pctUsed.toStringAsFixed(1)}% Terpakai',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: progressColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              key: const Key('budget_total_progress_bar'),
              value: summary.totalBudget > 0 ? (summary.totalSpent / summary.totalBudget).clamp(0.0, 1.0) : 0.0,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 10,
            ),
          ),

          const SizedBox(height: 14),

          // Metrics Footer: Terpakai vs Sisa
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sudah Digunakan',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summary.formattedTotalSpent,
                      key: const Key('total_budget_spent_text'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isOver ? AppTheme.expenseColor : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 28, color: AppTheme.borderSubtle),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOver ? 'Kelebihan (Over)' : 'Sisa Batas Bulan Berjalan',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summary.formattedTotalRemaining,
                      key: const Key('total_budget_remaining_text'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isOver ? AppTheme.expenseColor : AppTheme.incomeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Sisa Batas Bulan Berjalan Spotlight Card
          SisaBatasBulanBerjalanCard(summary: summary),
        ],
      ),
    );
  }
}
