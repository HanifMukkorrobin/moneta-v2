import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';

class EditBudgetLimitSheet extends StatefulWidget {
  final double currentAmount;
  final String monthLabel;
  final ValueChanged<double> onSave;
  final VoidCallback? onDelete;

  const EditBudgetLimitSheet({
    super.key,
    required this.currentAmount,
    required this.monthLabel,
    required this.onSave,
    this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    required double currentAmount,
    required String monthLabel,
    required ValueChanged<double> onSave,
    VoidCallback? onDelete,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => EditBudgetLimitSheet(
        currentAmount: currentAmount,
        monthLabel: monthLabel,
        onSave: onSave,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<EditBudgetLimitSheet> createState() => _EditBudgetLimitSheetState();
}

class _EditBudgetLimitSheetState extends State<EditBudgetLimitSheet> {
  late TextEditingController _controller;
  String? _errorMessage;

  final List<double> _quickPresets = const [
    3000000,
    5000000,
    7500000,
    10000000,
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.currentAmount > 0
        ? widget.currentAmount.toStringAsFixed(0)
        : '';
    _controller = TextEditingController(text: initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _parsedAmount {
    final cleaned = _controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  String _formatCurrency(double val) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(val);
  }

  void _onPresetTapped(double preset) {
    setState(() {
      _controller.text = preset.toStringAsFixed(0);
      _errorMessage = null;
    });
  }

  void _submitSave() {
    final amount = _parsedAmount;
    if (amount <= 0) {
      setState(() {
        _errorMessage = 'Nominal budget harus lebih besar dari Rp 0.';
      });
      return;
    }

    widget.onSave(amount);
    Navigator.pop(context);
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Budget Bulanan?'),
        content: Text(
          'Apakah Anda yakin ingin menghapus batas budget untuk ${widget.monthLabel}? Semua alokasi kantong budget akan diatur ulang.',
        ),
        actions: [
          TextButton(
            key: const Key('cancel_delete_budget_button'),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            key: const Key('confirm_delete_budget_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.expenseColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Close sheet
              widget.onDelete?.call();
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amount = _parsedAmount;
    final isNew = widget.currentAmount <= 0;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
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

          // Header: Title & Close
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isNew ? 'Tetapkan Budget Bulanan' : 'Ubah Batas Budget Bulanan',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              IconButton(
                key: const Key('close_edit_budget_sheet_button'),
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Text(
            'Periode ${widget.monthLabel}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),

          const SizedBox(height: 20),

          // Input field
          const Text(
            'Total Batas Budget (Nominal)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('budget_amount_input'),
            controller: _controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixText: 'Rp ',
              prefixStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
              hintText: '0',
              errorText: _errorMessage,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
            ),
            onChanged: (_) {
              if (_errorMessage != null) {
                setState(() => _errorMessage = null);
              } else {
                setState(() {});
              }
            },
          ),

          const SizedBox(height: 14),

          // Quick Presets
          const Text(
            'Pilihan Cepat',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _quickPresets.map((preset) {
              final isSelected = amount == preset;
              return ChoiceChip(
                key: Key('preset_chip_${preset.toStringAsFixed(0)}'),
                label: Text(
                  _formatCurrency(preset),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                selected: isSelected,
                selectedColor: AppTheme.primaryColor,
                backgroundColor: AppTheme.backgroundColor,
                onSelected: (_) => _onPresetTapped(preset),
              );
            }).toList(),
          ),

          const SizedBox(height: 18),

          // Preview Allocation breakdown (50/30/20)
          if (amount > 0) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Simulasi Alokasi 50/30/20:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSimRow('Kebutuhan (50%)', _formatCurrency(amount * 0.5)),
                  const SizedBox(height: 4),
                  _buildSimRow('Tabungan / Investasi (30%)', _formatCurrency(amount * 0.3)),
                  const SizedBox(height: 4),
                  _buildSimRow('Hiburan / Keinginan (20%)', _formatCurrency(amount * 0.2)),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Buttons: Simpan & (Optional) Hapus
          Row(
            children: [
              if (!isNew && widget.onDelete != null) ...[
                Expanded(
                  flex: 1,
                  child: OutlinedButton.icon(
                    key: const Key('delete_budget_button'),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Hapus'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.expenseColor,
                      side: const BorderSide(color: AppTheme.expenseColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _confirmDelete,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  key: const Key('save_budget_button'),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(isNew ? 'Tetapkan Budget' : 'Simpan Perubahan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _submitSave,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildSimRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
