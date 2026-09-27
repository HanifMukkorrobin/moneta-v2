import 'package:flutter/material.dart';
import '../../../models/monthly_rekap_data.dart';
import '../../../theme/app_theme.dart';

class CategoryBreakdownSection extends StatefulWidget {
  final MonthlyRekapData data;
  final String? selectedCategory;
  final ValueChanged<String?> onCategoryFilter;

  const CategoryBreakdownSection({
    super.key,
    required this.data,
    this.selectedCategory,
    required this.onCategoryFilter,
  });

  @override
  State<CategoryBreakdownSection> createState() => _CategoryBreakdownSectionState();
}

class _CategoryBreakdownSectionState extends State<CategoryBreakdownSection> {
  String _activeType = 'expense'; // 'expense' or 'income'

  @override
  Widget build(BuildContext context) {
    final items = _activeType == 'expense'
        ? widget.data.expenseBreakdown
        : widget.data.incomeBreakdown;

    final isExpense = _activeType == 'expense';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title & Type Switcher
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.pie_chart_rounded,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Grafik per Kategori',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              // Segmented type switcher
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTypeButton(
                      label: 'Pengeluaran',
                      type: 'expense',
                      isSelected: _activeType == 'expense',
                      color: AppTheme.expenseColor,
                    ),
                    _buildTypeButton(
                      label: 'Pemasukan',
                      type: 'income',
                      isSelected: _activeType == 'income',
                      color: AppTheme.incomeColor,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Belum ada transaksi ${isExpense ? 'pengeluaran' : 'pemasukan'} pada periode ini.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            )
          else ...[
            // Multi-segment Proportional Distribution Bar
            _buildDistributionBar(items),

            const SizedBox(height: 16),

            // Category Rank List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: AppTheme.borderSubtle),
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = widget.selectedCategory?.toLowerCase() ==
                    item.category.toLowerCase();

                return InkWell(
                  onTap: () {
                    // Toggle category filter
                    if (isSelected) {
                      widget.onCategoryFilter(null);
                    } else {
                      widget.onCategoryFilter(item.category);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (item.color ?? AppTheme.primaryColor)
                              .withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        // Category Icon with Circle
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: (item.color ?? Colors.grey)
                                .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            item.icon ?? Icons.bookmark_border_rounded,
                            size: 18,
                            color: item.color ?? AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Name, Custom tag, and Transaction Count
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      item.category,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (item.isCustom) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: Colors.purple.shade200),
                                      ),
                                      child: const Text(
                                        'Kustom',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.purple,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item.transactionCount} transaksi',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Amount and Percentage Badge
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              item.formattedTotal,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isExpense
                                    ? AppTheme.textPrimary
                                    : AppTheme.incomeColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: (item.color ?? Colors.grey)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                item.formattedPercentage,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: item.color ?? AppTheme.textSecondary,
                                ),
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
          ],
        ],
      ),
    );
  }

  Widget _buildTypeButton({
    required String label,
    required String type,
    required bool isSelected,
    required Color color,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _activeType = type;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildDistributionBar(List<CategoryBreakdownItem> items) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Row(
              children: items.map((item) {
                final flex = (item.percentage * 10).round();
                if (flex <= 0) return const SizedBox.shrink();
                return Expanded(
                  flex: flex,
                  child: Tooltip(
                    message: '${item.category}: ${item.formattedPercentage}',
                    child: Container(
                      color: item.color ?? Colors.blueGrey,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Top: ${items.first.category} (${items.first.formattedPercentage})',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${items.length} Kategori',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
