import 'package:flutter/material.dart';
import '../../../models/ai_insight_item.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/currency_format.dart';

class SafeSpendingLimitCard extends StatelessWidget {
  final AiInsightItem insight;
  final double? todaySpent;
  final VoidCallback? onAdjustBudget;
  final VoidCallback? onAddExpense;

  const SafeSpendingLimitCard({
    super.key,
    required this.insight,
    this.todaySpent,
    this.onAdjustBudget,
    this.onAddExpense,
  });

  @override
  Widget build(BuildContext context) {
    final safeLimit = insight.recommendedDailyBudget > 0
        ? insight.recommendedDailyBudget
        : 65000.0;
    final spent = todaySpent ?? AppState.instance.todayTotalExpense;
    final remaining = (safeLimit - spent).clamp(0.0, double.infinity);
    final usagePercent = safeLimit > 0
        ? ((spent / safeLimit) * 100).clamp(0.0, 999.0)
        : 100.0;
    final usageRatio = (usagePercent / 100.0).clamp(0.0, 1.0);

    // Penanda rendah aktif jika batas harian kecil (<= 30rb), level kritis, atau kuota hari ini tinggal < 25%
    final bool isLowLimit = safeLimit <= 30000 ||
        insight.warnLevel == AiWarnLevel.critical ||
        remaining < (safeLimit * 0.25) ||
        spent >= safeLimit;

    final Color statusColor = spent >= safeLimit
        ? const Color(0xFFEF4444) // Red: Over limit
        : (isLowLimit
            ? const Color(0xFFF59E0B) // Amber: Low threshold
            : const Color(0xFF10B981)); // Emerald Green: Safe

    final String statusLabel = spent >= safeLimit
        ? 'Melebihi Batas'
        : (isLowLimit ? 'Batas Rendah' : 'Batas Aman');

    final IconData statusIcon = spent >= safeLimit
        ? Icons.error_outline_rounded
        : (isLowLimit
            ? Icons.warning_amber_rounded
            : Icons.check_circle_outline_rounded);

    return Container(
      key: const Key('safe_spending_limit_card'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isLowLimit
              ? statusColor.withValues(alpha: 0.4)
              : AppTheme.borderSubtle,
          width: isLowLimit ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: isLowLimit ? 0.08 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title & Penanda Rendah Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Batas Aman Belanja',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),

              // Penanda Rendah / Penanda Aman Badge
              Container(
                key: isLowLimit
                    ? const Key('penanda_rendah_badge')
                    : const Key('penanda_aman_badge'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12.5, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
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

          // Main Metric Row: Limit vs Remaining
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Batas Rekomendasi AI',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormat.formatRupiah(safeLimit),
                    key: const Key('safe_limit_amount_text'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Sisa Kuota Hari Ini',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormat.formatRupiah(remaining),
                    key: const Key('remaining_safe_limit_text'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Usage Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              key: const Key('safe_limit_progress_bar'),
              value: usageRatio,
              minHeight: 7,
              backgroundColor: AppTheme.borderSubtle,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),

          const SizedBox(height: 8),

          // Progress detail text
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Terpakai: ${CurrencyFormat.formatRupiah(spent)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${usagePercent.toStringAsFixed(0)}% dari batas',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Guidance Message Box with Penanda Rendah Context
          Container(
            key: const Key('safe_limit_guidance_box'),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: statusColor.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isLowLimit
                      ? Icons.priority_high_rounded
                      : Icons.info_outline_rounded,
                  size: 16,
                  color: statusColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    spent >= safeLimit
                        ? 'Pengeluaran hari ini telah melampaui batas aman! Tahan semua pos belanja non-esensial.'
                        : (isLowLimit
                            ? 'Penanda Rendah: Batas belanja harian Anda minim (${CurrencyFormat.formatRupiah(safeLimit)}). Tahan pos hiburan agar saldo bertahan sampai awal bulan.'
                            : 'Batas aman belanja Anda dalam kondisi sehat. Anda masih bisa belanja hingga ${CurrencyFormat.formatRupiah(remaining)} hari ini.'),
                    key: const Key('safe_limit_guidance_text'),
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      color: AppTheme.textPrimary.withValues(alpha: 0.9),
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
