import 'package:flutter/material.dart';
import '../../../models/budget_item.dart';
import '../../../theme/app_theme.dart';

enum BudgetWarningLevel {
  none,
  nearLimit, // >= 80% spent
  overLimit, // > 100% spent (over budget)
}

class BudgetWarningBanner extends StatelessWidget {
  final MonthlyBudgetSummary summary;
  final VoidCallback? onAdjustBudget;
  final VoidCallback? onDismiss;

  const BudgetWarningBanner({
    super.key,
    required this.summary,
    this.onAdjustBudget,
    this.onDismiss,
  });

  BudgetWarningLevel get warningLevel {
    if (summary.totalBudget <= 0) return BudgetWarningLevel.none;
    if (summary.isOverBudget) return BudgetWarningLevel.overLimit;
    if (summary.percentageUsed >= 80.0) return BudgetWarningLevel.nearLimit;
    return BudgetWarningLevel.none;
  }

  @override
  Widget build(BuildContext context) {
    final level = warningLevel;
    if (level == BudgetWarningLevel.none) {
      return const SizedBox.shrink();
    }

    final isOver = level == BudgetWarningLevel.overLimit;
    final bannerColor = isOver ? AppTheme.expenseColor : Colors.amber.shade800;
    final bgColor = isOver ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB);
    final borderColor = isOver
        ? AppTheme.expenseColor.withValues(alpha: 0.3)
        : Colors.amber.shade400;

    final overBuckets = summary.buckets.where((b) => b.isOverBudget).toList();

    return Container(
      key: Key(isOver ? 'budget_over_limit_banner' : 'budget_near_limit_banner'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: bannerColor.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + Title + Dismiss
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bannerColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOver ? Icons.warning_rounded : Icons.notification_important_rounded,
                  color: bannerColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOver
                          ? 'Perhatian: Budget Melewati Batas!'
                          : 'Peringatan: Budget Mendekati Batas!',
                      key: const Key('budget_warning_title'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: bannerColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isOver
                          ? 'Total pengeluaran (${summary.formattedTotalSpent}) telah melewati plafon ${summary.formattedTotalBudget} sebesar ${summary.formattedTotalRemaining}.'
                          : 'Pengeluaran telah mencapai ${summary.percentageUsed.toStringAsFixed(1)}% dari plafon ${summary.formattedTotalBudget}. Sisa batas: ${summary.formattedTotalRemaining}.',
                      key: const Key('budget_warning_message'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade800,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDismiss != null)
                InkWell(
                  key: const Key('dismiss_warning_banner_button'),
                  onTap: onDismiss,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
            ],
          ),

          // Pos terdampak jika ada bucket yang over budget
          if (overBuckets.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              key: const Key('over_budget_buckets_chip'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: bannerColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pie_chart_rounded, size: 12, color: bannerColor),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Pos melebihi limit: ${overBuckets.map((b) => b.title).join(', ')}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: bannerColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Advice & Quick Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isOver
                      ? 'Tunda pengeluaran non-prioritas.'
                      : 'Aman belanja: ${summary.formattedDailyRemainingAverage}.',
                  key: const Key('budget_warning_advice_text'),
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              if (onAdjustBudget != null)
                InkWell(
                  key: const Key('adjust_budget_from_banner_button'),
                  onTap: onAdjustBudget,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: bannerColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tune_rounded, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Ubah Budget',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
