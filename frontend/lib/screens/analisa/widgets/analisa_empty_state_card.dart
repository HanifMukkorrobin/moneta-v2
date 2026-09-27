import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../chat/widgets/manual_input_sheet.dart';

class AnalisaEmptyStateCard extends StatelessWidget {
  final VoidCallback? onStartChat;
  final VoidCallback? onManualInput;

  const AnalisaEmptyStateCard({
    super.key,
    this.onStartChat,
    this.onManualInput,
  });

  void _handleManualInput(BuildContext context) {
    if (onManualInput != null) {
      onManualInput!();
      return;
    }
    ManualInputSheet.show(
      context,
      onSave: (tx) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaksi ${tx.formattedAmount} berhasil disimpan!'),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('analisa_empty_state_card'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Illustration / Icon Badge
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 40,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),

          // Title
          const Text(
            'Belum Ada Data Transaksi untuk Dianalisa',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),

          // Explanatory Subtitle
          const Text(
            'AI memerlukan minimal 1 transaksi pengeluaran untuk mulai menghitung rata-rata harian, estimasi ketahanan saldo, dan rekomendasi belanja.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          // Sample Prompts Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.tips_and_updates_rounded,
                      size: 14,
                      color: Colors.amber.shade700,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Coba ketik transaksi seperti ini di Chat:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: const [
                    _SampleChip(label: '☕ Kopi 25rb'),
                    _SampleChip(label: '🍛 Makan siang 30rb'),
                    _SampleChip(label: '🛒 Belanja minimarket 75rb'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Primary CTA Button: Mulai Catat di Chat
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('btn_empty_start_chat'),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: const Text(
                'Mulai Catat Lewat Chat',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: onStartChat,
            ),
          ),
          const SizedBox(height: 8),

          // Secondary CTA Button: Input Transaksi Manual
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('btn_empty_manual_input'),
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: const Text(
                'Input Transaksi Manual',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryLight),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _handleManualInput(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _SampleChip extends StatelessWidget {
  final String label;

  const _SampleChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}
