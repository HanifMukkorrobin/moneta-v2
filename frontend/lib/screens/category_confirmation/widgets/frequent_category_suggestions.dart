import 'package:flutter/material.dart';
import '../../../models/category_usage.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_theme.dart';
import '../../chat/widgets/transaction_card.dart';

class FrequentCategorySuggestions extends StatelessWidget {
  final String type; // 'expense' or 'income'
  final String? selectedCategory;
  final ValueChanged<String> onCategorySelected;
  final bool isCompact;
  final String? customTitle;

  const FrequentCategorySuggestions({
    super.key,
    required this.type,
    this.selectedCategory,
    required this.onCategorySelected,
    this.isCompact = false,
    this.customTitle,
  });

  @override
  Widget build(BuildContext context) {
    final List<CategoryUsage> frequentList =
        AppState.instance.getFrequentlyUsedCategories(
      type: type,
      limit: 5,
    );

    if (frequentList.isEmpty) return const SizedBox.shrink();

    final isExpense = type == 'expense';
    final accentColor = isExpense ? AppTheme.expenseColor : AppTheme.incomeColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_fire_department_rounded,
                size: isCompact ? 13 : 15,
                color: Colors.amber.shade900,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              customTitle ?? 'Sering Dipakai',
              style: TextStyle(
                fontSize: isCompact ? 12 : 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Text(
                'Saran Cepat',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.amber.shade900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: frequentList.map((item) {
              final isSelected = selectedCategory != null &&
                  selectedCategory!.toLowerCase() == item.name.toLowerCase();

              final catIcon = item.icon ??
                  TransactionCard.getCategoryIcon(item.name, isExpense);
              final iconColor = item.color ?? accentColor;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onCategorySelected(item.name),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 10 : 12,
                        vertical: isCompact ? 6 : 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryLight.withValues(alpha: 0.15)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : (item.count > 0
                                  ? Colors.amber.shade300
                                  : Colors.grey.shade300),
                          width: isSelected ? 1.6 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.12),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            catIcon,
                            size: isCompact ? 14 : 16,
                            color: isSelected ? AppTheme.primaryColor : iconColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item.count > 0
                                ? '${item.name} (${item.count}x)'
                                : '★ ${item.name}',
                            style: TextStyle(
                              fontSize: isCompact ? 11.5 : 12.5,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
