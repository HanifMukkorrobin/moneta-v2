import 'package:flutter/material.dart';
import '../../../models/monthly_rekap_data.dart';
import '../../../theme/app_theme.dart';
import 'category_proportion_chart.dart';

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
    final totalAmount = isExpense ? widget.data.totalExpense : widget.data.totalIncome;

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

          // Category Proportion Chart (Donut + Bar Modes + Proportional Breakdown List)
          CategoryProportionChart(
            items: items,
            totalAmount: totalAmount,
            type: _activeType,
            selectedCategory: widget.selectedCategory,
            onCategorySelected: widget.onCategoryFilter,
          ),
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
      key: Key('breakdown_type_button_$type'),
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
}
