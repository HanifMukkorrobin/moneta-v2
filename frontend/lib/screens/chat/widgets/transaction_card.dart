import 'package:flutter/material.dart';
import '../../../models/transaction_item.dart';
import '../../../theme/app_theme.dart';

class TransactionCard extends StatelessWidget {
  final TransactionItem transaction;
  final VoidCallback onConfirm;
  final VoidCallback onChangeCategory;
  final VoidCallback onDelete;

  const TransactionCard({
    super.key,
    required this.transaction,
    required this.onConfirm,
    required this.onChangeCategory,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.isExpense;
    final badgeColor = isExpense ? AppTheme.expenseColor : AppTheme.incomeColor;
    final isConfirmed = transaction.isConfirmed;

    return Container(
      margin: const EdgeInsets.only(left: 48, right: 12, top: 4, bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConfirmed
              ? AppTheme.primaryLight.withValues(alpha: 0.3)
              : AppTheme.primaryColor.withValues(alpha: 0.4),
          width: isConfirmed ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isConfirmed ? Colors.black : AppTheme.primaryColor)
                .withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Type badge & Time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isExpense ? Icons.arrow_outward : Icons.arrow_downward,
                      size: 14,
                      color: badgeColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isExpense ? 'Pengeluaran' : 'Pemasukan',
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 12,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    transaction.timeFormatted,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Amount
          Text(
            transaction.formattedAmount,
            style: TextStyle(
              color: isExpense ? AppTheme.expenseColor : AppTheme.incomeColor,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 6),

          // Note / description
          Row(
            children: [
              const Icon(
                Icons.notes_rounded,
                size: 14,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  transaction.note,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.borderSubtle),
          const SizedBox(height: 10),

          // Category badge with "Ubah" button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Text(
                      'Kategori: ',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Flexible(
                      child: InkWell(
                        onTap: onChangeCategory,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  transaction.category,
                                  style: const TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.edit_outlined,
                                size: 12,
                                color: AppTheme.primaryColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Status badge if confirmed
              if (isConfirmed)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 12, color: Colors.green),
                      SizedBox(width: 4),
                      Text(
                        'Tersimpan',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // Action buttons if pending confirmation
          if (!isConfirmed) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: onConfirm,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Simpan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: onChangeCategory,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Ubah',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  tooltip: 'Hapus',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.08),
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(36, 36),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
