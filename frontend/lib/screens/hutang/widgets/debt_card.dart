import 'package:flutter/material.dart';
import '../../../models/debt_item.dart';
import '../../../theme/app_theme.dart';

class DebtCard extends StatelessWidget {
  final DebtItem debt;
  final VoidCallback? onMarkPaid;
  final VoidCallback? onTap;

  const DebtCard({
    super.key,
    required this.debt,
    this.onMarkPaid,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPaid = debt.isPaid;
    final isDueSoon = debt.isDueSoon;
    final isOverdue = debt.isOverdue;

    final borderColor = isPaid
        ? const Color(0xFF10B981).withValues(alpha: 0.3)
        : (isOverdue
            ? const Color(0xFFEF4444).withValues(alpha: 0.4)
            : (isDueSoon
                ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                : AppTheme.borderSubtle));

    return Container(
      key: Key('debt_card_${debt.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isDueSoon || isOverdue ? 1.5 : 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Type badge & Due Status Tag
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: debt.type.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              debt.type.icon,
                              size: 15,
                              color: debt.type.color,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              debt.type.label,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: debt.type.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      key: Key('debt_status_badge_${debt.id}'),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: debt.statusBadgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isPaid)
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 11,
                              color: Color(0xFF10B981),
                            )
                          else if (isOverdue || isDueSoon)
                            Icon(
                              Icons.warning_rounded,
                              size: 11,
                              color: debt.statusBadgeColor,
                            ),
                          if (isPaid || isOverdue || isDueSoon)
                            const SizedBox(width: 4),
                          Text(
                            debt.dueStatusLabel,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: debt.statusBadgeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Title name & Penanda Segera badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        debt.name,
                        key: Key('debt_name_${debt.id}'),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: isPaid ? AppTheme.textSecondary : AppTheme.textPrimary,
                          decoration: isPaid ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    if (isDueSoon) ...[
                      const SizedBox(width: 6),
                      Container(
                        key: Key('penanda_segera_${debt.id}'),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              size: 11,
                              color: Colors.white,
                            ),
                            SizedBox(width: 2),
                            Text(
                              'SEGERA',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),

                if (debt.notes != null && debt.notes!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    debt.notes!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 12),

                // Amount row: Remaining & Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPaid ? 'Total Terlunasi' : 'Sisa Tagihan',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isPaid
                                ? debt.formattedTotalAmount
                                : debt.formattedRemainingAmount,
                            key: Key('debt_remaining_amount_${debt.id}'),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isPaid
                                  ? const Color(0xFF047857)
                                  : AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Jatuh Tempo',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 12,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              debt.formattedDueDate,
                              key: Key('debt_due_date_${debt.id}'),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    key: Key('debt_progress_bar_${debt.id}'),
                    value: debt.progressRatio,
                    minHeight: 5,
                    backgroundColor: AppTheme.surfaceColor,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isPaid
                          ? const Color(0xFF10B981)
                          : AppTheme.primaryColor,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Action Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Terbayar: ${debt.progressPercent}% dari ${debt.formattedTotalAmount}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!isPaid)
                      InkWell(
                        key: Key('btn_mark_paid_${debt.id}'),
                        onTap: onMarkPaid,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: 13,
                                color: Color(0xFF047857),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Tandai Lunas',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        key: Key('paid_indicator_${debt.id}'),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.done_all_rounded,
                              size: 13,
                              color: Color(0xFF047857),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Lunas',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF047857),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (isDueSoon) ...[
                  const SizedBox(height: 10),
                  Container(
                    key: Key('due_soon_alert_strip_${debt.id}'),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFFCD34D),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time_filled_rounded,
                          size: 13,
                          color: Color(0xFFD97706),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            debt.daysUntilDue == 0
                                ? 'Tagihan jatuh tempo HARI INI! Segera lunasi.'
                                : 'Jatuh tempo SEGERA dalam ${debt.daysUntilDue} hari (${debt.formattedDueDate})',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
