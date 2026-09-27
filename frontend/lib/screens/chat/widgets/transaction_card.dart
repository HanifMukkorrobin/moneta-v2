import 'package:flutter/material.dart';
import '../../../models/transaction_item.dart';
import '../../../theme/app_theme.dart';
import '../../category_confirmation/widgets/guessed_category_badge.dart';
import '../../category_confirmation/widgets/transaction_type_indicator.dart';

class TransactionCard extends StatelessWidget {
  final TransactionItem transaction;
  final VoidCallback onConfirm;
  final VoidCallback onChangeCategory;
  final VoidCallback onDelete;
  final VoidCallback? onToggleType;

  const TransactionCard({
    super.key,
    required this.transaction,
    required this.onConfirm,
    required this.onChangeCategory,
    required this.onDelete,
    this.onToggleType,
  });

  static IconData getCategoryIcon(String category, bool isExpense) {
    switch (category) {
      case 'Makan & Minuman':
        return Icons.restaurant_rounded;
      case 'Transportasi':
        return Icons.directions_car_rounded;
      case 'Belanja':
        return Icons.shopping_bag_rounded;
      case 'Hiburan':
        return Icons.sports_esports_rounded;
      case 'Tagihan & Utilitas':
        return Icons.receipt_long_rounded;
      case 'Hutang & Paylater':
        return Icons.credit_card_rounded;
      case 'Kebutuhan Rumah':
        return Icons.home_rounded;
      case 'Kesehatan':
        return Icons.medical_services_rounded;
      case 'Gaji':
        return Icons.account_balance_wallet_rounded;
      case 'Freelance':
        return Icons.laptop_mac_rounded;
      case 'Bonus':
        return Icons.card_giftcard_rounded;
      case 'Investasi':
        return Icons.trending_up_rounded;
      case 'Transfer Masuk':
        return Icons.move_to_inbox_rounded;
      default:
        return isExpense ? Icons.sell_rounded : Icons.savings_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.isExpense;
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
          // Sub-header: AI Detection Tag & Time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: 11,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isConfirmed ? 'Tercatat Otomatis' : 'Hasil Parse AI',
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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

          const SizedBox(height: 10),

          // Main Row: Type Badge + Toggle & Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Type Badge (clickable to toggle if allowed)
              TransactionTypeIndicator(
                type: transaction.type,
                onToggle: onToggleType,
              ),

              // Large Formatted Amount
              Text(
                transaction.formattedAmount,
                style: TextStyle(
                  color:
                      isExpense ? AppTheme.expenseColor : AppTheme.incomeColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Note / prompt quotation
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

          // Category Badge + Status
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
                      child: GuessedCategoryBadge(
                        category: transaction.category,
                        isExpense: transaction.isExpense,
                        confidenceScore: transaction.confidenceScore,
                        isCustom: false,
                        onTap: onChangeCategory,
                        isCompact: true,
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

          // Action buttons for confirmed transactions
          if (isConfirmed) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onChangeCategory,
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Ubah Data', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
                  label: const Text('Hapus',
                      style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],

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
