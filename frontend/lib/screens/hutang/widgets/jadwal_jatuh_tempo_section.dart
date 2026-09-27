import 'package:flutter/material.dart';
import '../../../models/debt_item.dart';
import '../../../theme/app_theme.dart';

class JadwalJatuhTempoSection extends StatefulWidget {
  final List<DebtItem> debts;
  final Function(DebtItem)? onSelectDebt;
  final VoidCallback? onFilterDueSoon;

  const JadwalJatuhTempoSection({
    super.key,
    required this.debts,
    this.onSelectDebt,
    this.onFilterDueSoon,
  });

  @override
  State<JadwalJatuhTempoSection> createState() =>
      _JadwalJatuhTempoSectionState();
}

class _JadwalJatuhTempoSectionState extends State<JadwalJatuhTempoSection> {
  bool _onlyShowDueSoon = false;

  List<DebtItem> get _sortedActiveDebts {
    // Only active (unpaid) debts, sorted ascending by due date
    final active = widget.debts.where((d) => !d.isPaid).toList();
    active.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    if (_onlyShowDueSoon) {
      return active.where((d) => d.isDueSoon || d.isOverdue).toList();
    }
    return active;
  }

  int get _dueSoonCount =>
      widget.debts.where((d) => !d.isPaid && d.isDueSoon).length;

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];

  @override
  Widget build(BuildContext context) {
    final scheduleDebts = _sortedActiveDebts;

    return Container(
      key: const Key('jadwal_jatuh_tempo_section'),
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
          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.calendar_month_rounded,
                        size: 18,
                        color: Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Jadwal Jatuh Tempo',
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

              // Filter toggle chip (Semua vs Segera)
              InkWell(
                key: const Key('btn_toggle_schedule_filter'),
                onTap: () {
                  setState(() {
                    _onlyShowDueSoon = !_onlyShowDueSoon;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _onlyShowDueSoon
                        ? const Color(0xFFF59E0B)
                        : AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _onlyShowDueSoon
                          ? const Color(0xFFD97706)
                          : AppTheme.borderSubtle,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        size: 13,
                        color: _onlyShowDueSoon
                            ? Colors.white
                            : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _onlyShowDueSoon
                            ? 'Segera Saja ($_dueSoonCount)'
                            : 'Semua Jadwal',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _onlyShowDueSoon
                              ? Colors.white
                              : AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Schedule Timeline Content
          if (scheduleDebts.isEmpty) ...[
            Container(
              key: const Key('empty_schedule_container'),
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 22,
                    color: Color(0xFF047857),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _onlyShowDueSoon
                          ? 'Tidak ada tagihan yang jatuh tempo dalam waktu dekat. Keuangan aman!'
                          : 'Tidak ada jadwal tagihan aktif yang perlu dibayar.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF047857),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Horizontal scrollable schedule items
            SizedBox(
              height: 112,
              child: ListView.separated(
                key: const Key('debt_schedule_list_view'),
                scrollDirection: Axis.horizontal,
                itemCount: scheduleDebts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final debt = scheduleDebts[index];
                  final isDueSoon = debt.isDueSoon;
                  final isOverdue = debt.isOverdue;
                  final monthStr = _monthNames[debt.dueDate.month - 1];

                  return InkWell(
                    key: Key('schedule_card_${debt.id}'),
                    onTap: () => widget.onSelectDebt?.call(debt),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 195,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDueSoon
                            ? const Color(0xFFFFFBEB)
                            : (isOverdue
                                ? const Color(0xFFFEF2F2)
                                : AppTheme.surfaceColor),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDueSoon
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.6)
                              : (isOverdue
                                  ? const Color(0xFFEF4444)
                                      .withValues(alpha: 0.6)
                                  : AppTheme.borderSubtle),
                          width: isDueSoon || isOverdue ? 1.4 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top: Date Badge & Penanda Segera Tag
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Date calendar icon & text
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border:
                                      Border.all(color: AppTheme.borderSubtle),
                                ),
                                child: Text(
                                  '${debt.dueDate.day} $monthStr',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),

                              // Penanda Segera badge
                              if (isDueSoon)
                                Container(
                                  key: Key('schedule_badge_segera_${debt.id}'),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.bolt_rounded,
                                        size: 10,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 1),
                                      Text(
                                        'Segera',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (isOverdue)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: const Text(
                                    'Lewat',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          // Middle: Debt name with icon
                          Row(
                            children: [
                              Icon(
                                debt.type.icon,
                                size: 13,
                                color: debt.type.color,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  debt.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Bottom: Sisa Tagihan & Countdown
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  debt.formattedRemainingAmount,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: isDueSoon
                                        ? const Color(0xFFB45309)
                                        : AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                debt.daysUntilDue == 0
                                    ? 'Hari ini'
                                    : (debt.daysUntilDue == 1
                                        ? 'Besok'
                                        : '${debt.daysUntilDue}h lagi'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDueSoon
                                      ? const Color(0xFFD97706)
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
