import 'package:flutter/material.dart';
import '../../../models/category_confirmation_item.dart';
import '../../../theme/app_theme.dart';
import 'guessed_category_badge.dart';
import 'transaction_type_indicator.dart';

class CategoryConfirmationCard extends StatelessWidget {
  final CategoryConfirmationItem item;
  final VoidCallback onConfirm;
  final VoidCallback onEditCategory;
  final Function(String) onSelectAlternative;
  final VoidCallback? onToggleType;
  final VoidCallback onDelete;

  const CategoryConfirmationCard({
    super.key,
    required this.item,
    required this.onConfirm,
    required this.onEditCategory,
    required this.onSelectAlternative,
    this.onToggleType,
    required this.onDelete,
  });

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
    if (diff.inHours < 24) return '${diff.inHours}j lalu';
    return '${diff.inDays}h lalu';
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = item.isExpense;
    final typeColor = isExpense ? AppTheme.expenseColor : AppTheme.incomeColor;
    final isConfirmed = item.isConfirmed;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConfirmed
              ? Colors.green.withValues(alpha: 0.3)
              : AppTheme.primaryColor.withValues(alpha: 0.35),
          width: isConfirmed ? 1.2 : 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: (isConfirmed ? Colors.black : AppTheme.primaryColor)
                .withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Raw Sentence & Pilah Masuk/Keluar Badge
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: isConfirmed
                  ? Colors.grey.shade50
                  : AppTheme.primaryColor.withValues(alpha: 0.04),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.format_quote_rounded,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.rawSentence,
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.grey.shade800,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTimeAgo(item.occurredAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Type Pill (Pilah Masuk / Keluar)
                TransactionTypeIndicator(
                  type: item.type,
                  onToggle: onToggleType,
                  showReasoning: true,
                  reasoning: item.typeReasoning,
                  isCompact: true,
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 0.6),

          // Body: Amount and Tebak Kategori Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Amount Display
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Nominal',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      item.formattedAmount,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: typeColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // AI Categorization Highlight Box
                GuessedCategoryBadge(
                  category: item.detectedCategory,
                  isExpense: item.isExpense,
                  confidenceScore: item.confidenceScore,
                  reasoning: item.aiReasoning,
                  isCustom: item.isCustomCategory,
                  onTap: onEditCategory,
                ),

                // Fallback Quick Picker Box for Empty / Failed Guess
                if ((item.detectedCategory.isEmpty ||
                        item.detectedCategory == 'Belum Dikategorikan' ||
                        item.detectedCategory == 'Kategori Kosong') &&
                    !isConfirmed) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.touch_app_outlined,
                                size: 14, color: Colors.amber.shade900),
                            const SizedBox(width: 4),
                            Text(
                              'Pilih kategori langsung (Fallback Cepat):',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: (isExpense
                                  ? [
                                      'Makan & Minuman',
                                      'Transportasi',
                                      'Belanja',
                                      'Tagihan & Utilitas',
                                      'Lainnya'
                                    ]
                                  : [
                                      'Gaji',
                                      'Freelance',
                                      'Bonus',
                                      'Transfer Masuk',
                                      'Lainnya'
                                    ])
                              .map((quickCat) => ActionChip(
                                    label: Text(quickCat),
                                    labelStyle: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade800,
                                    ),
                                    backgroundColor: Colors.white,
                                    side: BorderSide(
                                        color: Colors.amber.shade300),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () =>
                                        onSelectAlternative(quickCat),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
                if (item.alternativeCategories.isNotEmpty && !isConfirmed) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Saran kategori alternatif:',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: item.alternativeCategories.map((alt) {
                      final isSelected = alt == item.detectedCategory;
                      return ActionChip(
                        label: Text(alt),
                        avatar: isSelected
                            ? const Icon(Icons.check, size: 12)
                            : null,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? AppTheme.primaryColor
                              : Colors.grey.shade700,
                        ),
                        backgroundColor: isSelected
                            ? AppTheme.primaryColor.withValues(alpha: 0.12)
                            : Colors.white,
                        side: BorderSide(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : Colors.grey.shade300,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onSelectAlternative(alt),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 14),

                // Card Footer Actions
                if (!isConfirmed) ...[
                  Row(
                    children: [
                      // Perbaiki Kategori (Edit button)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onEditCategory,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textPrimary,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.tune_rounded, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Ubah Kategori',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Simpan & Konfirmasi button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onConfirm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Konfirmasi',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 20),
                        color: Colors.red.shade400,
                        tooltip: 'Abaikan / Hapus',
                      ),
                    ],
                  ),
                ] else ...[
                  // Already Confirmed Banner
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: Colors.green.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Terkonfirmasi ke Buku Kas',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: onEditCategory,
                        icon: const Icon(Icons.edit_outlined, size: 14),
                        label: const Text(
                          'Ubah',
                          style: TextStyle(fontSize: 11),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
