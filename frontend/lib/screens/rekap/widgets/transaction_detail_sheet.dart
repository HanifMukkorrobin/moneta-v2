import 'package:flutter/material.dart';
import '../../../models/monthly_rekap_data.dart';
import '../../../models/transaction_item.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_theme.dart';
import '../../category_confirmation/widgets/category_picker_sheet.dart';

class TransactionDetailSheet extends StatelessWidget {
  final TransactionItem transaction;
  final VoidCallback? onUpdated;

  const TransactionDetailSheet({
    super.key,
    required this.transaction,
    this.onUpdated,
  });

  static Future<void> show(
    BuildContext context,
    TransactionItem transaction, {
    VoidCallback? onUpdated,
  }) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => TransactionDetailSheet(
        transaction: transaction,
        onUpdated: onUpdated,
      ),
    );

    if (result == 'change_category' && context.mounted) {
      CategoryPickerSheet.show(
        context,
        initialCategory: transaction.category,
        initialType: transaction.type,
        onSelected: (newCat, newType, isCustom) {
          transaction.category = newCat;
          transaction.type = newType;
          transaction.isCustomCategory = isCustom;
          AppState.instance.updateTransactionCategory(
            transaction.id,
            newCat,
            newType: newType,
            isCustom: isCustom,
          );
          onUpdated?.call();
        },
      );
    }
  }

  String _getMonthName(int month) {
    const names = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    if (month >= 1 && month <= 12) return names[month];
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final icon = MonthlyRekapData.getCategoryIcon(transaction.category);
    final color = MonthlyRekapData.getCategoryColor(transaction.category);
    final dateStr = '${transaction.occurredAt.day} ${_getMonthName(transaction.occurredAt.month)} ${transaction.occurredAt.year}';
    final timeStr = '${transaction.timeFormatted} WIB';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
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

            // Top Header: Title & Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Detail Transaksi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                IconButton(
                  key: const Key('close_detail_sheet_button'),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Tutup',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Main Banner: Category Avatar, Note, Amount & Type Badge
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 24, color: color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.note,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: transaction.isIncome
                                    ? AppTheme.incomeColor.withValues(alpha: 0.15)
                                    : AppTheme.expenseColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                transaction.isIncome ? 'Pemasukan' : 'Pengeluaran',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: transaction.isIncome
                                      ? AppTheme.incomeColor
                                      : AppTheme.expenseColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    transaction.formattedAmount,
                    key: const Key('detail_formatted_amount_text'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: transaction.isIncome
                          ? AppTheme.incomeColor
                          : AppTheme.expenseColor,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),
            const Divider(height: 1, color: AppTheme.borderSubtle),
            const SizedBox(height: 14),

            // Metadata rows
            _buildDetailRow(
              icon: Icons.category_rounded,
              label: 'Kategori',
              value: transaction.category,
              badge: transaction.isCustomCategory ? 'Kustom' : null,
              color: color,
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              icon: Icons.calendar_today_rounded,
              label: 'Tanggal & Waktu',
              value: '$dateStr • $timeStr',
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              icon: transaction.isConfirmed
                  ? Icons.check_circle_rounded
                  : Icons.schedule_rounded,
              label: 'Status Verifikasi',
              value: transaction.isConfirmed ? 'Terkonfirmasi' : 'Menunggu Konfirmasi',
              valueColor: transaction.isConfirmed
                  ? AppTheme.incomeColor
                  : Colors.amber.shade900,
            ),
            if (transaction.confidenceScore != null) ...[
              const SizedBox(height: 12),
              _buildDetailRow(
                icon: Icons.auto_awesome_rounded,
                label: 'Akurasi AI',
                value: transaction.formattedConfidence,
                valueColor: AppTheme.primaryColor,
              ),
            ],
            const SizedBox(height: 12),
            _buildDetailRow(
              icon: Icons.tag_rounded,
              label: 'ID Transaksi',
              value: '#${transaction.id}',
              valueColor: Colors.grey.shade600,
            ),

            const SizedBox(height: 22),

            // Action Buttons: Ganti Kategori, Konfirmasi, & Tutup
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('detail_change_category_button'),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Ganti Kategori'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(context, 'change_category');
                    },
                  ),
                ),
                if (!transaction.isConfirmed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      key: const Key('detail_confirm_transaction_button'),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Konfirmasi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        transaction.isConfirmed = true;
                        AppState.instance.confirmTransaction(transaction.id);
                        onUpdated?.call();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Transaksi berhasil dikonfirmasi.'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                key: const Key('detail_close_button'),
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup', style: TextStyle(color: AppTheme.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    String? badge,
    Color? color,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? AppTheme.textSecondary),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: valueColor ?? AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.purple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// Convenient aliases matching task nomenclature
typedef TampilanDetailTransaksi = TransactionDetailSheet;
typedef RekapTransactionDetailSheet = TransactionDetailSheet;
