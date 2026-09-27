import 'package:flutter/material.dart';
import '../../../models/ai_insight_item.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_theme.dart';

class EarlyWarningIndicatorCard extends StatelessWidget {
  final AiInsightItem insight;
  final ValueChanged<AiWarnLevel>? onLevelChanged;

  const EarlyWarningIndicatorCard({
    super.key,
    required this.insight,
    this.onLevelChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentLevel = insight.warnLevel;

    return Container(
      key: const Key('early_warning_indicator_card'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: currentLevel.color.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: currentLevel.color.withValues(alpha: 0.08),
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
                    color: currentLevel.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    currentLevel.icon,
                    color: currentLevel.color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Peringatan Dini Finansial',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Deteksi dini risiko belanja boros (3 Tingkat)',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Current level tag
                Container(
                  key: const Key('active_warning_badge'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: currentLevel.color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    currentLevel.label,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 3-Tingkat Visual Gauge / Level Bar
            Row(
              children: [
                Expanded(
                  child: _LevelSegment(
                    key: const Key('segment_normal'),
                    level: AiWarnLevel.normal,
                    isActive: currentLevel == AiWarnLevel.normal,
                    title: '1. Aman',
                    subtitle: 'Pengeluaran stabil',
                    onTap: () {
                      _switchLevel(AiWarnLevel.normal);
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _LevelSegment(
                    key: const Key('segment_warning'),
                    level: AiWarnLevel.warning,
                    isActive: currentLevel == AiWarnLevel.warning,
                    title: '2. Waspada',
                    subtitle: 'Mulai meningkat',
                    onTap: () {
                      _switchLevel(AiWarnLevel.warning);
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _LevelSegment(
                    key: const Key('segment_critical'),
                    level: AiWarnLevel.critical,
                    isActive: currentLevel == AiWarnLevel.critical,
                    title: '3. Kritis',
                    subtitle: 'Saldo terancam',
                    onTap: () {
                      _switchLevel(AiWarnLevel.critical);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Detailed Level Diagnostics Box
            Container(
              key: const Key('warning_diagnostics_box'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: currentLevel.color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: currentLevel.color.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        currentLevel.icon,
                        size: 15,
                        color: currentLevel.color,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _getDiagnosticTitle(currentLevel),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: currentLevel.color,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _getDiagnosticDescription(currentLevel),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textPrimary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: AppTheme.borderSubtle),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tindakan: ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _getActionRecommendation(currentLevel),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
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
    );
  }

  void _switchLevel(AiWarnLevel level) {
    if (onLevelChanged != null) {
      onLevelChanged!(level);
      return;
    }
    // Update global state
    AiInsightItem updated;
    switch (level) {
      case AiWarnLevel.normal:
        updated = insight.copyWith(
          warnLevel: AiWarnLevel.normal,
          estimatedDaysLeft: 18,
          avgDailySpend: 78500,
          recommendedDailyBudget: 65000,
          dailyAdvice:
              'Pertahankan ritme belanja Anda. Saldo aman sampai akhir bulan.',
        );
        break;
      case AiWarnLevel.warning:
        updated = insight.copyWith(
          warnLevel: AiWarnLevel.warning,
          estimatedDaysLeft: 9,
          avgDailySpend: 135000,
          recommendedDailyBudget: 42000,
          dailyAdvice:
              'Perhatian: Pengeluaran meningkat 40%! Batasi jajan maksimal Rp 42.000 hari ini.',
        );
        break;
      case AiWarnLevel.critical:
        updated = insight.copyWith(
          warnLevel: AiWarnLevel.critical,
          estimatedDaysLeft: 3,
          avgDailySpend: 215000,
          recommendedDailyBudget: 15000,
          dailyAdvice:
              'Kritis: Sisa saldo menipis! Stop pengeluaran sekunder dan fokus kebutuhan pokok.',
        );
        break;
    }
    AppState.instance.setAiInsight(updated);
  }

  String _getDiagnosticTitle(AiWarnLevel level) {
    switch (level) {
      case AiWarnLevel.normal:
        return 'Tingkat 1: Finansial Terkendali';
      case AiWarnLevel.warning:
        return 'Tingkat 2: Peringatan Belanja Meningkat';
      case AiWarnLevel.critical:
        return 'Tingkat 3: Kondisi Kritis / Darurat';
    }
  }

  String _getDiagnosticDescription(AiWarnLevel level) {
    switch (level) {
      case AiWarnLevel.normal:
        return 'Rasio pengeluaran harian berada di bawah ambang batas aman. Proyeksi saldo bertahan melampaui tanggal gajian.';
      case AiWarnLevel.warning:
        return 'Terdeteksi lonjakan belanja dalam beberapa hari terakhir. Jika tidak dikurangi, uang berpotensi habis sebelum akhir bulan.';
      case AiWarnLevel.critical:
        return 'Sisa saldo menipis drastis dengan laju belanja tinggi. Proyeksi ketahanan uang kurang dari 5 hari ke depan.';
    }
  }

  String _getActionRecommendation(AiWarnLevel level) {
    switch (level) {
      case AiWarnLevel.normal:
        return 'Pertahankan kebiasaan mencatat transaksi dan kontrol budget.';
      case AiWarnLevel.warning:
        return 'Pangkas pos hiburan dan tunda belanja barang non-esensial.';
      case AiWarnLevel.critical:
        return 'Kunci pengeluaran gaya hidup, fokus 100% pada kebutuhan primer.';
    }
  }
}

class _LevelSegment extends StatelessWidget {
  final AiWarnLevel level;
  final bool isActive;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LevelSegment({
    super.key,
    required this.level,
    required this.isActive,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? level.color.withValues(alpha: 0.15)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? level.color : AppTheme.borderSubtle,
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: level.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.w600,
                      color: isActive ? level.color : AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 8.5,
                color: isActive
                    ? level.color.withValues(alpha: 0.9)
                    : AppTheme.textSecondary.withValues(alpha: 0.8),
                fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
