import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/transaction_item.dart';
import '../../../theme/app_theme.dart';
import '../../chat/widgets/transaction_card.dart';

class TransactionHistoryCard extends StatelessWidget {
  final TransactionItem transaction;
  final VoidCallback onChangeCategory;
  final VoidCallback onToggleType;
  final VoidCallback? onDelete;
  final VoidCallback? onConfirm;

  const TransactionHistoryCard({
    super.key,
    required this.transaction,
    required this.onChangeCategory,
    required this.onToggleType,
    this.onDelete,
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.isExpense;
    final typeColor = isExpense ? AppTheme.expenseColor : AppTheme.incomeColor;
    final dateFormatted =
        DateFormat('dd MMM yyyy, HH:mm').format(transaction.occurredAt);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: transaction.isConfirmed
              ? AppTheme.borderSubtle
              : Colors.amber.shade300,
          width: transaction.isConfirmed ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Info Row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Icon Avatar
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    TransactionCard.getCategoryIcon(
                        transaction.category, isExpense),
                    color: typeColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Note and Date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.note,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dateFormatted,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Amount and Status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      transaction.formattedAmount,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: typeColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: transaction.isConfirmed
                            ? Colors.green.shade50
                            : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: transaction.isConfirmed
                              ? Colors.green.shade200
                              : Colors.amber.shade300,
                        ),
                      ),
                      child: Text(
                        transaction.isConfirmed ? 'Tersimpan' : 'Menunggu',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: transaction.isConfirmed
                              ? Colors.green.shade700
                              : Colors.amber.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Category Badge and Attribute Strip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Clickable Category Badge to change category directly
                InkWell(
                  onTap: onChangeCategory,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.category_rounded,
                          size: 13,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          transaction.category,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_drop_down_rounded,
                          size: 16,
                          color: AppTheme.primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),

                // Type Badge (Pemasukan / Pengeluaran)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isExpense
                            ? Icons.arrow_outward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 12,
                        color: typeColor,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        isExpense ? 'Pengeluaran' : 'Pemasukan',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: typeColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // Custom or AI Badge
                if (transaction.isCustomCategory)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded,
                            size: 12, color: Colors.purple.shade700),
                        const SizedBox(width: 3),
                        Text(
                          'Kategori Sendiri',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.purple.shade800,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (transaction.confidenceScore != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome,
                            size: 11, color: Colors.blue),
                        const SizedBox(width: 3),
                        Text(
                          transaction.formattedConfidence,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: AppTheme.borderSubtle),

          // Bottom Action Buttons Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                // "Ganti Kategori" Button
                TextButton(
                  onPressed: onChangeCategory,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.edit_rounded, size: 15),
                      SizedBox(width: 4),
                      Text(
                        'Ganti Kategori',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 4),

                // "Ubah Jenis" (Masuk / Keluar toggle)
                TextButton(
                  onPressed: onToggleType,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isExpense
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_outward_rounded,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isExpense ? 'Ubah ke Masuk' : 'Ubah ke Keluar',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Delete Button
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: Colors.grey.shade500,
                    ),
                    tooltip: 'Hapus Catatan',
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
