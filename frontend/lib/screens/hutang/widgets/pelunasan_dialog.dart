import 'package:flutter/material.dart';
import '../../../models/debt_item.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/currency_format.dart';

class PelunasanDialog extends StatefulWidget {
  final DebtItem debt;
  final Function(double amount, bool isFull, String? notes) onConfirm;

  const PelunasanDialog({
    super.key,
    required this.debt,
    required this.onConfirm,
  });

  static Future<void> show(
    BuildContext context, {
    required DebtItem debt,
    required Function(double amount, bool isFull, String? notes) onConfirm,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PelunasanDialog(
        debt: debt,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<PelunasanDialog> createState() => _PelunasanDialogState();
}

class _PelunasanDialogState extends State<PelunasanDialog> {
  bool _isFullPayment = true;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _amountController.text =
        widget.debt.remainingAmount.toInt().toString();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _handleConfirm() {
    setState(() {
      _errorMessage = null;
    });

    if (_isFullPayment) {
      widget.onConfirm(
        widget.debt.remainingAmount,
        true,
        _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );
      Navigator.of(context).pop();
      return;
    }

    final clean = _amountController.text
        .replaceAll('.', '')
        .replaceAll(',', '')
        .replaceAll(' ', '');
    final val = double.tryParse(clean);

    if (val == null || val <= 0) {
      setState(() {
        _errorMessage = 'Nominal pembayaran harus lebih dari Rp 0';
      });
      return;
    }

    if (val > widget.debt.remainingAmount) {
      setState(() {
        _errorMessage =
            'Nominal pembayaran tidak boleh melebihi sisa tagihan (${widget.debt.formattedRemainingAmount})';
      });
      return;
    }

    final isFull = val >= widget.debt.remainingAmount;
    widget.onConfirm(
      val,
      isFull,
      _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
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
              const SizedBox(height: 12),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF10B981),
                        size: 22,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Pelunasan Tagihan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    key: const Key('btn_close_pelunasan_sheet'),
                    icon: const Icon(Icons.close_rounded),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Target Debt Info Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.debt.type.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        widget.debt.type.icon,
                        size: 18,
                        color: widget.debt.type.color,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.debt.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Sisa Tagihan: ${widget.debt.formattedRemainingAmount}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFFB45309),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Mode Pelunasan (Radio / Choice)
              const Text(
                'Pilihan Pelunasan',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              // Option 1: Lunasi Penuh
              InkWell(
                key: const Key('radio_full_payment'),
                onTap: () {
                  setState(() {
                    _isFullPayment = true;
                    _errorMessage = null;
                    _amountController.text =
                        widget.debt.remainingAmount.toInt().toString();
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isFullPayment
                        ? const Color(0xFF10B981).withValues(alpha: 0.08)
                        : AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isFullPayment
                          ? const Color(0xFF10B981)
                          : AppTheme.borderSubtle,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isFullPayment
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        size: 18,
                        color: _isFullPayment
                            ? const Color(0xFF047857)
                            : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Lunasi Penuh (${widget.debt.formattedRemainingAmount})',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: _isFullPayment
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: _isFullPayment
                                ? const Color(0xFF047857)
                                : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Option 2: Bayar Sebagian / Cicilan
              InkWell(
                key: const Key('radio_partial_payment'),
                onTap: () {
                  setState(() {
                    _isFullPayment = false;
                    _errorMessage = null;
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: !_isFullPayment
                        ? AppTheme.primaryColor.withValues(alpha: 0.08)
                        : AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: !_isFullPayment
                          ? AppTheme.primaryColor
                          : AppTheme.borderSubtle,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        !_isFullPayment
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        size: 18,
                        color: !_isFullPayment
                            ? AppTheme.primaryColor
                            : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bayar Sebagian / Cicil Tagihan',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: !_isFullPayment
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: !_isFullPayment
                                ? AppTheme.primaryColor
                                : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (!_isFullPayment) ...[
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('input_partial_paid_amount'),
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Nominal yang Dibayar (Rp)',
                    prefixText: 'Rp ',
                    prefixStyle: const TextStyle(fontWeight: FontWeight.bold),
                    filled: true,
                    fillColor: AppTheme.surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppTheme.borderSubtle),
                    ),
                  ),
                ),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  key: const Key('error_pelunasan_text'),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Catatan Pembayaran
              TextFormField(
                key: const Key('input_pelunasan_notes'),
                controller: _notesController,
                decoration: InputDecoration(
                  hintText: 'Catatan pelunasan (opsional, misal: transfer BCA)',
                  hintStyle: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.borderSubtle),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('btn_cancel_pelunasan'),
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      key: const Key('btn_confirm_pelunasan'),
                      onPressed: _handleConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Konfirmasi Pelunasan',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
