import 'package:flutter/material.dart';
import '../../../models/monthly_rekap_data.dart';
import '../../../theme/app_theme.dart';

class RekapSummaryCard extends StatefulWidget {
  final MonthlyRekapData data;
  final VoidCallback? onIncomeTap;
  final VoidCallback? onExpenseTap;
  final bool initialExpanded;

  const RekapSummaryCard({
    super.key,
    required this.data,
    this.onIncomeTap,
    this.onExpenseTap,
    this.initialExpanded = false,
  });

  @override
  State<RekapSummaryCard> createState() => _RekapSummaryCardState();
}

class _RekapSummaryCardState extends State<RekapSummaryCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final isSurplus = data.isSurplus;
    final statusColor = isSurplus ? AppTheme.incomeColor : AppTheme.expenseColor;
    final statusText = isSurplus ? 'Surplus' : 'Defisit';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Net Savings & Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tabungan Bersih (Net Savings)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data.formattedNetSavings,
                          key: const Key('net_savings_amount_text'),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: isSurplus ? AppTheme.primaryColor : AppTheme.expenseColor,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      key: const Key('rekap_status_badge'),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSurplus ? Icons.check_circle_rounded : Icons.warning_rounded,
                            size: 14,
                            color: statusColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(height: 1, color: AppTheme.borderSubtle),
                const SizedBox(height: 16),

                // Two interactive column cards: Pemasukan & Pengeluaran
                Row(
                  children: [
                    // Total Income Card
                    Expanded(
                      child: InkWell(
                        key: const Key('income_summary_card_tap'),
                        onTap: widget.onIncomeTap,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.incomeColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppTheme.incomeColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: AppTheme.incomeColor.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.arrow_downward_rounded,
                                      size: 15,
                                      color: AppTheme.incomeColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Pemasukan',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                data.formattedTotalIncome,
                                key: const Key('total_income_text'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.incomeColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.incomeColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${data.incomeTransactionsCount} trx',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.incomeColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '${data.formattedIncomeDiffPct} vs lalu',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w500,
                                        color: data.incomeDiffPct >= 0
                                            ? AppTheme.incomeColor
                                            : AppTheme.textSecondary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Total Expense Card
                    Expanded(
                      child: InkWell(
                        key: const Key('expense_summary_card_tap'),
                        onTap: widget.onExpenseTap,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.expenseColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppTheme.expenseColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: AppTheme.expenseColor.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.arrow_upward_rounded,
                                      size: 15,
                                      color: AppTheme.expenseColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Pengeluaran',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                data.formattedTotalExpense,
                                key: const Key('total_expense_text'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.expenseColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.expenseColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${data.expenseTransactionsCount} trx',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.expenseColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '${data.formattedExpenseDiffPct} vs lalu',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w500,
                                        color: data.expenseDiffPct <= 0
                                            ? AppTheme.incomeColor
                                            : AppTheme.expenseColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Savings Rate Progress Bar & Health Status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.savings_outlined,
                              size: 15,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Rasio Tabungan: ${data.formattedSavingsRate}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          isSurplus ? 'Kondisi Sehat 🎉' : 'Perlu Evaluasi ⚠️',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSurplus ? AppTheme.primaryColor : Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (data.savingsRate.clamp(0.0, 100.0)) / 100,
                        backgroundColor: AppTheme.borderSubtle,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isSurplus ? AppTheme.primaryColor : AppTheme.expenseColor,
                        ),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Detail insights accordion / expandable bar
          InkWell(
            key: const Key('toggle_summary_details_button'),
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: const Border(
                  top: BorderSide(color: AppTheme.borderSubtle),
                ),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isExpanded ? 'Sembunyikan Rincian' : 'Lihat Rincian Analisa',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),

          if (_isExpanded)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Rata-rata Pengeluaran / Hari',
                    value: data.formattedAverageDailyExpense,
                  ),
                  const SizedBox(height: 10),
                  _buildDetailRow(
                    icon: Icons.pie_chart_outline_rounded,
                    label: 'Porsi Pengeluaran vs Masuk',
                    value: data.formattedExpenseRatio,
                  ),
                  if (data.largestExpense != null) ...[
                    const SizedBox(height: 10),
                    _buildDetailRow(
                      icon: Icons.arrow_upward_rounded,
                      label: 'Pengeluaran Terbesar',
                      value: '${data.largestExpense!.formattedAmount} (${data.largestExpense!.category})',
                      valueColor: AppTheme.expenseColor,
                    ),
                  ],
                  if (data.largestIncome != null) ...[
                    const SizedBox(height: 10),
                    _buildDetailRow(
                      icon: Icons.arrow_downward_rounded,
                      label: 'Pemasukan Terbesar',
                      value: '${data.largestIncome!.formattedAmount} (${data.largestIncome!.category})',
                      valueColor: AppTheme.incomeColor,
                    ),
                  ],
                  const SizedBox(height: 10),
                  _buildDetailRow(
                    icon: Icons.verified_outlined,
                    label: 'Status Verifikasi',
                    value: '${data.confirmedTransactionsCount} terkonfirmasi, ${data.pendingTransactionsCount} pending',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: valueColor ?? AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

// Convenient alias for code referencing the task title directly
typedef IncomeExpenseSummaryCard = RekapSummaryCard;
