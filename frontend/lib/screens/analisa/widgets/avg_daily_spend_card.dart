import 'package:flutter/material.dart';
import '../../../models/daily_spending_item.dart';
import '../../../theme/app_theme.dart';

class AvgDailySpendCard extends StatelessWidget {
  final DailySpendingAnalysis analysis;
  final VoidCallback? onTapDetails;

  const AvgDailySpendCard({
    super.key,
    required this.analysis,
    this.onTapDetails,
  });

  @override
  Widget build(BuildContext context) {
    final maxAmount = analysis.maxBarAmount;
    final isIncrease = analysis.isSpendingIncreasing;

    return Container(
      key: const Key('avg_daily_spend_card'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.borderSubtle,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.analytics_rounded,
                    color: AppTheme.primaryColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rata-rata Pengeluaran Harian',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Tren belanja 7 hari terakhir (Data Tiruan)',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Comparison Badge
                Container(
                  key: const Key('avg_spend_comparison_badge'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isIncrease
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                        : const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isIncrease
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
                          : const Color(0xFF10B981).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isIncrease
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 12,
                        color: isIncrease
                            ? const Color(0xFFD97706)
                            : const Color(0xFF059669),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        analysis.comparisonBadgeLabel,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isIncrease
                              ? const Color(0xFFD97706)
                              : const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Big Number Display
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          analysis.formattedAvgDailySpend,
                          key: const Key('avg_daily_spend_nominal'),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '/ hari',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Target: ${analysis.formattedTargetDailySpend}',
                    style: TextStyle(
                      fontSize: 11,
                      color: analysis.isAboveTarget
                          ? AppTheme.expenseColor
                          : AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 7-day Bar Chart
            Container(
              key: const Key('daily_spending_bar_chart'),
              height: 110,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: analysis.dailyPoints.map((point) {
                  final ratio = maxAmount > 0
                      ? (point.amount / maxAmount).clamp(0.08, 1.0)
                      : 0.1;
                  final isAboveAvg = point.amount > analysis.avgDailySpend;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Top amount label
                          Text(
                            point.formattedShortAmount,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: isAboveAvg
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isAboveAvg
                                  ? AppTheme.expenseColor
                                  : AppTheme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // Vertical Bar
                          Container(
                            height: 52 * ratio,
                            decoration: BoxDecoration(
                              color: isAboveAvg
                                  ? AppTheme.expenseColor
                                  : AppTheme.primaryColor
                                      .withValues(alpha: 0.65),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Day label
                          Text(
                            point.dayLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isAboveAvg
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isAboveAvg
                                  ? AppTheme.textPrimary
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 14),

            // Summary Highlights Grid
            Row(
              children: [
                Expanded(
                  child: _StatPill(
                    icon: Icons.arrow_upward_rounded,
                    iconColor: AppTheme.expenseColor,
                    label: 'Tertinggi',
                    value:
                        '${analysis.highestSpendDay} (${analysis.formattedHighestSpend})',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatPill(
                    icon: Icons.arrow_downward_rounded,
                    iconColor: AppTheme.incomeColor,
                    label: 'Terhemat',
                    value:
                        '${analysis.lowestSpendDay} (${analysis.formattedLowestSpend})',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _StatPill(
              icon: Icons.pie_chart_outline_rounded,
              iconColor: AppTheme.primaryColor,
              label: 'Kontribusi Terbesar',
              value:
                  '${analysis.topCategoryName} (${analysis.topCategoryPercentage.toStringAsFixed(0)}% dari total)',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatPill({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: AppTheme.textSecondary.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
