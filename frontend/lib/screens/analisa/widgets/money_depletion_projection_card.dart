import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/ai_insight_item.dart';
import '../../../theme/app_theme.dart';

class MoneyDepletionProjectionCard extends StatefulWidget {
  final AiInsightItem insight;
  final ValueChanged<int>? onDaysChanged;

  const MoneyDepletionProjectionCard({
    super.key,
    required this.insight,
    this.onDaysChanged,
  });

  @override
  State<MoneyDepletionProjectionCard> createState() =>
      _MoneyDepletionProjectionCardState();
}

class _MoneyDepletionProjectionCardState
    extends State<MoneyDepletionProjectionCard> {
  late double _simulatedDailySpend;
  late int _simulatedDaysLeft;

  @override
  void initState() {
    super.initState();
    _simulatedDailySpend = widget.insight.avgDailySpend;
    _simulatedDaysLeft = widget.insight.estimatedDaysLeft;
  }

  @override
  void didUpdateWidget(covariant MoneyDepletionProjectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.insight != widget.insight) {
      _simulatedDailySpend = widget.insight.avgDailySpend;
      _simulatedDaysLeft = widget.insight.estimatedDaysLeft;
    }
  }

  void _recalculateSimulation(double dailySpend) {
    setState(() {
      _simulatedDailySpend = dailySpend;
      if (dailySpend > 0 && widget.insight.remainingBalance > 0) {
        _simulatedDaysLeft =
            (widget.insight.remainingBalance / dailySpend).floor();
      } else {
        _simulatedDaysLeft = widget.insight.estimatedDaysLeft;
      }
    });
    widget.onDaysChanged?.call(_simulatedDaysLeft);
  }

  static const _monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];
  static const _shortMonthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];

  DateTime get _simulatedDate =>
      widget.insight.date.add(Duration(days: _simulatedDaysLeft));

  String get _simulatedDateFormatted {
    final d = _simulatedDate;
    return '${d.day} ${_monthNames[d.month - 1]} ${d.year}';
  }

  String get _simulatedShortDateFormatted {
    final d = _simulatedDate;
    return '${d.day} ${_shortMonthNames[d.month - 1]} ${d.year}';
  }

  bool get _runsOutEarly =>
      _simulatedDaysLeft < widget.insight.daysUntilEndOfMonth;

  @override
  Widget build(BuildContext context) {
    final warnLevel = widget.insight.warnLevel;
    final statusColor = _runsOutEarly ? Colors.red.shade600 : const Color(0xFF10B981);

    return Container(
      key: const Key('money_depletion_card'),
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
                    Icons.hourglass_bottom_rounded,
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
                        'Perkiraan Uang Bertahan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Proyeksi sisa saldo & estimasi tanggal habis',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Days badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: warnLevel.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: warnLevel.color.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    '~$_simulatedDaysLeft Hari Lagi',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: warnLevel.color,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Two Key Metric Panels
            Row(
              children: [
                // Panel 1: Sisa Hari Bertahan
                Expanded(
                  child: Container(
                    key: const Key('depletion_days_metric'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: warnLevel.color.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: warnLevel.color.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 14,
                              color: warnLevel.color,
                            ),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Uang Bertahan',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '~$_simulatedDaysLeft Hari',
                          key: const Key('depletion_days_value'),
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: warnLevel.color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _runsOutEarly ? 'Perlu Penghematan' : 'Kondisi Cukup',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Panel 2: Tanggal Habis
                Expanded(
                  child: Container(
                    key: const Key('depletion_date_metric'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.event_busy_rounded,
                              size: 14,
                              color: AppTheme.primaryColor,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Tanggal Habis',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _simulatedShortDateFormatted,
                          key: const Key('depletion_date_value'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Proyeksi Saldo Habis',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary.withValues(alpha: 0.8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Depletion Assessment Banner
            Container(
              key: const Key('depletion_status_banner'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _runsOutEarly
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 16,
                    color: statusColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _runsOutEarly
                          ? 'Saldo diperkirakan habis sebelum akhir bulan ($_simulatedDateFormatted)'
                          : 'Saldo bertahan aman melampaui akhir bulan (s/d $_simulatedDateFormatted)',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Interactive What-If Simulator (Ubah Belanja Harian)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Simulasi Laju Belanja Harian',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        NumberFormat.currency(
                          locale: 'id_ID',
                          symbol: 'Rp ',
                          decimalDigits: 0,
                        ).format(_simulatedDailySpend),
                        key: const Key('simulated_spend_label'),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    key: const Key('simulated_spend_slider'),
                    value: _simulatedDailySpend.clamp(20000.0, 200000.0),
                    min: 20000.0,
                    max: 200000.0,
                    divisions: 18,
                    activeColor: AppTheme.primaryColor,
                    inactiveColor: AppTheme.borderSubtle,
                    onChanged: (val) => _recalculateSimulation(val),
                  ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text('Rp 20rb (Hemat)',
                            style: TextStyle(
                                fontSize: 9.5, color: AppTheme.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      Flexible(
                        child: Text('Rp 200rb (Boros)',
                            style: TextStyle(
                                fontSize: 9.5, color: AppTheme.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
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
}
