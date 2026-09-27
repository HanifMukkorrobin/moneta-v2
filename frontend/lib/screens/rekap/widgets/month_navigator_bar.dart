import 'package:flutter/material.dart';
import '../../../mock/rekap_mock_data.dart';
import '../../../theme/app_theme.dart';

class MonthNavigatorBar extends StatelessWidget {
  final String selectedMonth;
  final List<String> availableMonths;
  final ValueChanged<String> onMonthChanged;
  final bool showQuickChips;

  const MonthNavigatorBar({
    super.key,
    required this.selectedMonth,
    required this.availableMonths,
    required this.onMonthChanged,
    this.showQuickChips = true,
  });

  bool get _canGoPrevious {
    final idx = availableMonths.indexOf(selectedMonth);
    return idx != -1 && idx < availableMonths.length - 1;
  }

  bool get _canGoNext {
    final idx = availableMonths.indexOf(selectedMonth);
    return idx > 0;
  }

  void _previousMonth() {
    final idx = availableMonths.indexOf(selectedMonth);
    if (idx != -1 && idx < availableMonths.length - 1) {
      onMonthChanged(availableMonths[idx + 1]);
    }
  }

  void _nextMonth() {
    final idx = availableMonths.indexOf(selectedMonth);
    if (idx > 0) {
      onMonthChanged(availableMonths[idx - 1]);
    }
  }

  bool get _isLatestMonth =>
      availableMonths.isNotEmpty && selectedMonth == availableMonths.first;

  void _showMonthPickerModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Pilih Periode Bulan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Pindah rekapitulasi data keuangan tanpa memuat ulang halaman.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: availableMonths.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final monthKey = availableMonths[index];
                    final label = RekapMockData.getMonthLabel(monthKey);
                    final isSelected = monthKey == selectedMonth;
                    final isLatest = index == 0;

                    return ListTile(
                      key: Key('month_picker_item_$monthKey'),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryColor.withValues(alpha: 0.12)
                              : Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.calendar_today_rounded,
                          size: 18,
                          color: isSelected ? AppTheme.primaryColor : Colors.grey.shade600,
                        ),
                      ),
                      title: Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isLatest)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Bulan Ini',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                        ],
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        if (!isSelected) {
                          onMonthChanged(monthKey);
                        }
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = RekapMockData.getMonthLabel(selectedMonth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Primary Navigator Row
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderSubtle),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Previous month button
              IconButton(
                key: const Key('month_navigator_prev_button'),
                icon: const Icon(Icons.chevron_left_rounded),
                color: _canGoPrevious ? AppTheme.primaryColor : Colors.grey.shade300,
                onPressed: _canGoPrevious ? _previousMonth : null,
                tooltip: 'Bulan Sebelumnya',
              ),

              // Center clickable Month Label with bottom sheet trigger
              InkWell(
                key: const Key('month_navigator_picker_button'),
                onTap: () => _showMonthPickerModal(context),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        size: 18,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (_isLatestMonth) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Kini',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 20,
                        color: Colors.grey.shade600,
                      ),
                    ],
                  ),
                ),
              ),

              // Next month button
              IconButton(
                key: const Key('month_navigator_next_button'),
                icon: const Icon(Icons.chevron_right_rounded),
                color: _canGoNext ? AppTheme.primaryColor : Colors.grey.shade300,
                onPressed: _canGoNext ? _nextMonth : null,
                tooltip: 'Bulan Berikutnya',
              ),
            ],
          ),
        ),

        // Quick Month Chips
        if (showQuickChips)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: availableMonths.map((m) {
                final isSelected = m == selectedMonth;
                final chipLabel = RekapMockData.getMonthLabel(m);

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: Key('month_chip_$m'),
                    label: Text(chipLabel),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                    ),
                    side: BorderSide(
                      color: isSelected ? AppTheme.primaryColor : AppTheme.borderSubtle,
                      width: isSelected ? 1.4 : 1.0,
                    ),
                    onSelected: (val) {
                      if (val && !isSelected) {
                        onMonthChanged(m);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
