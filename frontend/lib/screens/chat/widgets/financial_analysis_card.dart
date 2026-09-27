import 'package:flutter/material.dart';
import '../../../models/ai_insight_item.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_theme.dart';

class FinancialAnalysisCard extends StatefulWidget {
  final AiInsightItem? insight;
  final bool initialExpanded;
  final VoidCallback? onTapDetail;

  const FinancialAnalysisCard({
    super.key,
    this.insight,
    this.initialExpanded = true,
    this.onTapDetail,
  });

  @override
  State<FinancialAnalysisCard> createState() => _FinancialAnalysisCardState();
}

class _FinancialAnalysisCardState extends State<FinancialAnalysisCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded;
  }

  void _showDetailSheet(BuildContext context, AiInsightItem insight) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FinancialAnalysisDetailModal(insight: insight),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentInsight = widget.insight ?? AppState.instance.aiInsight;
    final warnLevel = currentInsight.warnLevel;

    return Container(
      key: const Key('financial_analysis_card'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: warnLevel.color.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: warnLevel.color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          InkWell(
            key: const Key('financial_analysis_header_tap'),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(15),
              bottom: Radius.circular(_isExpanded ? 0 : 15),
            ),
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: AppTheme.primaryColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Analisa Keuangan AI',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Estimasi ketahanan & rata-rata belanja',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary.withValues(alpha: 0.9),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Warn Level Badge
                  Container(
                    key: const Key('financial_analysis_status_badge'),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: warnLevel.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: warnLevel.color.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          warnLevel.icon,
                          size: 13,
                          color: warnLevel.color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          warnLevel.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: warnLevel.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Collapse / Expand Icon
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    key: const Key('financial_analysis_collapse_toggle'),
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Collapsed summary preview
          if (!_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Row(
                children: [
                  Icon(
                    Icons.hourglass_bottom_rounded,
                    size: 13,
                    color: warnLevel.color,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Uang bertahan ~${currentInsight.estimatedDaysLeft} hari',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Saran: ${currentInsight.formattedRecommendedDailyBudget}/hari',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          // Expanded Content
          if (_isExpanded) ...[
            const Divider(height: 1, color: AppTheme.borderSubtle),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 3 Metrics Columns
                  Row(
                    children: [
                      // Metric 1: Ketahanan Uang
                      Expanded(
                        child: _MetricTile(
                          key: const Key('metric_estimated_days'),
                          title: 'Uang Bertahan',
                          value: '~${currentInsight.estimatedDaysLeft} Hari',
                          subtitle:
                              'Habis: ${currentInsight.formattedShortDepletionDate}',
                          icon: Icons.hourglass_top_rounded,
                          accentColor: warnLevel.color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Metric 2: Rata-rata Pengeluaran
                      Expanded(
                        child: _MetricTile(
                          key: const Key('metric_avg_daily_spend'),
                          title: 'Rata-rata/Hari',
                          value: currentInsight.formattedAvgDailySpend,
                          subtitle: 'Pengeluaran',
                          icon: Icons.trending_up_rounded,
                          accentColor: AppTheme.expenseColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Metric 3: Saran Belanja Harian
                      Expanded(
                        child: _MetricTile(
                          key: const Key('metric_recommended_budget'),
                          title: 'Saran Batas',
                          value:
                              currentInsight.formattedRecommendedDailyBudget,
                          subtitle: 'Batas Hari Ini',
                          icon: Icons.savings_rounded,
                          accentColor: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Daily Advice Callout Box
                  Container(
                    key: const Key('financial_analysis_advice_box'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lightbulb_rounded,
                            size: 16,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Saran Belanja Hari Ini',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                currentInsight.dailyAdvice,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textPrimary,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Action strip: Detail button & Timestamp
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Timestamp / Status label
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 12,
                              color:
                                  AppTheme.textSecondary.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Diperbarui hari ini • 9Router AI',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: AppTheme.textSecondary
                                      .withValues(alpha: 0.8),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Detail Button
                      InkWell(
                        key: const Key('financial_analysis_view_detail_button'),
                        borderRadius: BorderRadius.circular(8),
                        onTap: widget.onTapDetail ??
                            () => _showDetailSheet(context, currentInsight),
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Lihat Detail',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 10,
                                color: AppTheme.primaryColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const _MetricTile({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: accentColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary.withValues(alpha: 0.9),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9.5,
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _FinancialAnalysisDetailModal extends StatelessWidget {
  final AiInsightItem insight;

  const _FinancialAnalysisDetailModal({required this.insight});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.insights_rounded,
                            color: AppTheme.primaryColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Detail Analisa Keuangan AI',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                'Kalkulasi cerdas pola pengeluaran Anda',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Status alert banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: insight.warnLevel.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: insight.warnLevel.color.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(insight.warnLevel.icon,
                              color: insight.warnLevel.color, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  insight.warnLevel.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: insight.warnLevel.color,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  insight.dailyAdvice,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Ringkasan Finansial',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),

                    _DetailRow(
                      label: 'Perkiraan Ketahanan Saldo',
                      value: '~${insight.estimatedDaysLeft} Hari lagi',
                      icon: Icons.hourglass_top_rounded,
                      highlightColor: insight.warnLevel.color,
                    ),
                    _DetailRow(
                      label: 'Tanggal Proyeksi Habis',
                      value: insight.formattedDepletionDate,
                      icon: Icons.event_busy_rounded,
                      highlightColor: insight.warnLevel.color,
                    ),
                    _DetailRow(
                      label: 'Status Akhir Bulan',
                      value: insight.depletionStatusMessage,
                      icon: Icons.calendar_month_rounded,
                    ),
                    _DetailRow(
                      label: 'Rata-rata Pengeluaran Harian',
                      value: insight.formattedAvgDailySpend,
                      icon: Icons.trending_up_rounded,
                    ),
                    _DetailRow(
                      label: 'Batas Belanja Direkomendasikan',
                      value: insight.formattedRecommendedDailyBudget,
                      icon: Icons.savings_rounded,
                    ),
                    if (insight.totalMonthlyBudget > 0)
                      _DetailRow(
                        label: 'Total Budget Bulanan',
                        value: insight.formattedTotalMonthlyBudget,
                        icon: Icons.account_balance_wallet_rounded,
                      ),
                    if (insight.remainingBalance > 0)
                      _DetailRow(
                        label: 'Sisa Saldo Tersedia',
                        value: insight.formattedRemainingBalance,
                        icon: Icons.account_balance_rounded,
                      ),

                    const SizedBox(height: 20),

                    // Preset simulator for previewing AI states
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Simulasi Skenario AI',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  key: const Key('btn_simulate_normal'),
                                  style: OutlinedButton.styleFrom(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    side: BorderSide(
                                      color: insight.isNormal
                                          ? AppTheme.primaryColor
                                          : AppTheme.borderSubtle,
                                    ),
                                  ),
                                  onPressed: () {
                                    AppState.instance.setAiInsight(
                                      insight.copyWith(
                                        warnLevel: AiWarnLevel.normal,
                                        estimatedDaysLeft: 18,
                                        avgDailySpend: 78500,
                                        recommendedDailyBudget: 65000,
                                        dailyAdvice:
                                            'Pertahankan ritme belanja Anda. Saldo aman sampai akhir bulan.',
                                      ),
                                    );
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text('Aman',
                                      style: TextStyle(fontSize: 11)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  key: const Key('btn_simulate_warning'),
                                  style: OutlinedButton.styleFrom(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    side: BorderSide(
                                      color: insight.isWarning
                                          ? Colors.amber
                                          : AppTheme.borderSubtle,
                                    ),
                                  ),
                                  onPressed: () {
                                    AppState.instance.setAiInsight(
                                      insight.copyWith(
                                        warnLevel: AiWarnLevel.warning,
                                        estimatedDaysLeft: 9,
                                        avgDailySpend: 135000,
                                        recommendedDailyBudget: 42000,
                                        dailyAdvice:
                                            'Perhatian: Pengeluaran meningkat 40%! Batasi jajan maksimal Rp 42.000 hari ini.',
                                      ),
                                    );
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text('Waspada',
                                      style: TextStyle(fontSize: 11)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  key: const Key('btn_simulate_critical'),
                                  style: OutlinedButton.styleFrom(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    side: BorderSide(
                                      color: insight.isCritical
                                          ? Colors.red
                                          : AppTheme.borderSubtle,
                                    ),
                                  ),
                                  onPressed: () {
                                    AppState.instance.setAiInsight(
                                      insight.copyWith(
                                        warnLevel: AiWarnLevel.critical,
                                        estimatedDaysLeft: 3,
                                        avgDailySpend: 215000,
                                        recommendedDailyBudget: 15000,
                                        dailyAdvice:
                                            'Kritis: Sisa saldo menipis! Stop pengeluaran sekunder dan fokus kebutuhan pokok.',
                                      ),
                                    );
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text('Kritis',
                                      style: TextStyle(fontSize: 11)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? highlightColor;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 16, color: highlightColor ?? AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: highlightColor ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
