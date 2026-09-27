import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class TransactionTypeIndicator extends StatelessWidget {
  final String type; // 'expense' or 'income'
  final VoidCallback? onToggle;
  final bool showReasoning;
  final String? reasoning;
  final bool isCompact;

  const TransactionTypeIndicator({
    super.key,
    required this.type,
    this.onToggle,
    this.showReasoning = false,
    this.reasoning,
    this.isCompact = false,
  });

  bool get isExpense => type == 'expense';

  @override
  Widget build(BuildContext context) {
    final typeColor = isExpense ? AppTheme.expenseColor : AppTheme.incomeColor;
    final label = isExpense ? 'Pengeluaran' : 'Pemasukan';
    final iconData =
        isExpense ? Icons.arrow_outward_rounded : Icons.arrow_downward_rounded;

    Widget pill = Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 10,
        vertical: isCompact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: typeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(isCompact ? 6 : 20),
        border: Border.all(
          color: typeColor.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            iconData,
            size: isCompact ? 12 : 14,
            color: typeColor,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: typeColor,
                fontSize: isCompact ? 11 : 12,
                fontWeight: FontWeight.w700,
                letterSpacing: isCompact ? 0.3 : 0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onToggle != null) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.swap_vert_rounded,
              size: isCompact ? 12 : 14,
              color: typeColor.withValues(alpha: 0.7),
            ),
          ],
        ],
      ),
    );

    if (onToggle != null) {
      pill = Tooltip(
        message: 'Ketuk untuk beralih jenis transaksi (Pemasukan / Pengeluaran)',
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(isCompact ? 6 : 20),
          child: pill,
        ),
      );
    }

    if (!showReasoning || reasoning == null || reasoning!.isEmpty) {
      return pill;
    }

    return Row(
      children: [
        pill,
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            reasoning!,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
