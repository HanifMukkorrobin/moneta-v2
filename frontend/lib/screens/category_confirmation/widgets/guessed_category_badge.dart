import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../chat/widgets/transaction_card.dart';

class GuessedCategoryBadge extends StatelessWidget {
  final String category;
  final bool isExpense;
  final double? confidenceScore;
  final String? reasoning;
  final bool isCustom;
  final VoidCallback? onTap;
  final bool isCompact;

  const GuessedCategoryBadge({
    super.key,
    required this.category,
    required this.isExpense,
    this.confidenceScore,
    this.reasoning,
    this.isCustom = false,
    this.onTap,
    this.isCompact = false,
  });

  String get formattedConfidence {
    final score = confidenceScore ?? 0.95;
    return '${(score * 100).round()}% Akurat';
  }

  bool get isHighConfidence => (confidenceScore ?? 0.95) >= 0.85;

  @override
  Widget build(BuildContext context) {
    final categoryIcon =
        TransactionCard.getCategoryIcon(category, isExpense);
    final themeColor =
        isExpense ? AppTheme.expenseColor : AppTheme.incomeColor;

    if (isCompact) {
      Widget compactWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              categoryIcon,
              size: 13,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 5),
            Text(
              category,
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: isHighConfidence
                    ? Colors.green.shade50
                    : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 9,
                    color: isHighConfidence
                        ? Colors.green.shade700
                        : Colors.amber.shade800,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    formattedConfidence,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isHighConfidence
                          ? Colors.green.shade800
                          : Colors.amber.shade900,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.edit_outlined,
                size: 12,
                color: AppTheme.primaryColor,
              ),
            ],
          ],
        ),
      );

      if (onTap != null) {
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: compactWidget,
        );
      }
      return compactWidget;
    }

    // Detailed Box
    Widget detailedWidget = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  categoryIcon,
                  color: themeColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: 11,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Tebakan Kategori AI:',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (isCustom) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Custom',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      category,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              // Confidence Pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isHighConfidence
                      ? Colors.green.shade50
                      : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isHighConfidence
                        ? Colors.green.shade300
                        : Colors.amber.shade300,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 12,
                      color: isHighConfidence
                          ? Colors.green.shade700
                          : Colors.amber.shade800,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formattedConfidence,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isHighConfidence
                            ? Colors.green.shade800
                            : Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (reasoning != null && reasoning!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.psychology_outlined,
                  size: 14,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    reasoning!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade700,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: detailedWidget,
      );
    }
    return detailedWidget;
  }
}
