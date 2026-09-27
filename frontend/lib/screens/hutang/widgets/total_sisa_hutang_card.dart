import 'package:flutter/material.dart';
import '../../../models/debt_item.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/currency_format.dart';

class TotalSisaHutangCard extends StatelessWidget {
  final List<DebtItem> debts;
  final bool showBreakdown;
  final VoidCallback? onFilterDueSoon;
  final VoidCallback? onTap;

  const TotalSisaHutangCard({
    super.key,
    required this.debts,
    this.showBreakdown = true,
    this.onFilterDueSoon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    double totalOriginal = 0;
    double totalRemaining = 0;
    int activeCount = 0;
    int dueSoonCount = 0;

    final breakdown = <DebtType, double>{};

    for (var d in debts) {
      totalOriginal += d.totalAmount;
      if (!d.isPaid) {
        totalRemaining += d.remainingAmount;
        activeCount++;
        if (d.isDueSoon) {
          dueSoonCount++;
        }

        breakdown[d.type] = (breakdown[d.type] ?? 0) + d.remainingAmount;
      }
    }

    final totalPaid = (totalOriginal - totalRemaining).clamp(0.0, totalOriginal);
    final ratio = totalOriginal > 0 ? (totalPaid / totalOriginal).clamp(0.0, 1.0) : 1.0;
    final percent = (ratio * 100).toInt();

    return Container(
      key: const Key('total_sisa_hutang_card'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          // Header: Icon, Title & Active Count Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.account_balance_rounded,
                        size: 18,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Ringkasan Hutang',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                key: const Key('active_debts_count_badge'),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  '$activeCount Tagihan Aktif',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Total Sisa Hutang Header & Nominal Rupiah
          const Text(
            'Total Sisa Hutang & Paylater',
            style: TextStyle(
              fontSize: 11.5,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            CurrencyFormat.formatRupiah(totalRemaining),
            key: const Key('total_sisa_hutang_rupiah_text'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 12),

          // Progress Bar Pelunasan
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              key: const Key('total_sisa_hutang_progress_bar'),
              value: ratio,
              minHeight: 7,
              backgroundColor: AppTheme.surfaceColor,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
            ),
          ),

          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Terbayar: ${CurrencyFormat.formatRupiah(totalPaid)} ($percent%)',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF047857),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Total: ${CurrencyFormat.formatRupiah(totalOriginal)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),

          // Breakdown per Tipe Tagihan (jika ada tagihan aktif)
          if (showBreakdown && breakdown.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              key: const Key('sisa_hutang_breakdown_section'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rincian Sisa Berdasarkan Tipe:',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: breakdown.entries.map((entry) {
                        final type = entry.key;
                        final amount = entry.value;

                        return Container(
                          key: Key('sisa_hutang_type_${type.name}'),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: type.color.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                type.icon,
                                size: 12,
                                color: type.color,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${type.label}: ',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: type.color,
                                ),
                              ),
                              Text(
                                CurrencyFormat.formatRupiah(amount),
                                key: Key('sisa_hutang_amount_${type.name}'),
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Due Soon Alert Box (if any active debt is due soon)
          if (dueSoonCount > 0) ...[
            const SizedBox(height: 14),
            InkWell(
              key: const Key('due_soon_alert_box'),
              onTap: onFilterDueSoon,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: Color(0xFFD97706),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Perhatian: $dueSoonCount tagihan jatuh tempo dalam 3 hari ke depan!',
                        key: const Key('due_soon_alert_text'),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: Color(0xFFD97706),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
