import 'package:flutter/material.dart';
import '../../../models/debt_item.dart';
import '../../../theme/app_theme.dart';

class TambahHutangBottomSheet extends StatefulWidget {
  final Function(DebtItem) onAdd;

  const TambahHutangBottomSheet({
    super.key,
    required this.onAdd,
  });

  static Future<void> show(
    BuildContext context, {
    required Function(DebtItem) onAdd,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TambahHutangBottomSheet(onAdd: onAdd),
    );
  }

  @override
  State<TambahHutangBottomSheet> createState() =>
      _TambahHutangBottomSheetState();
}

class _TambahHutangBottomSheetState extends State<TambahHutangBottomSheet> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _totalAmountController = TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DebtType _selectedType = DebtType.paylater;
  late DateTime _selectedDueDate;
  bool _hasPartialPayment = false;

  @override
  void initState() {
    super.initState();
    // Default jatuh tempo 30 hari ke depan
    _selectedDueDate = DateTime.now().add(const Duration(days: 30));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _totalAmountController.dispose();
    _paidAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _addQuickAmount(int amount) {
    final cleanText = _totalAmountController.text
        .replaceAll('.', '')
        .replaceAll(',', '')
        .replaceAll(' ', '');
    final current = int.tryParse(cleanText) ?? 0;
    final updated = current + amount;
    setState(() {
      _totalAmountController.text = updated.toString();
    });
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 10),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDueDate = picked;
      });
    }
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final cleanTotal = _totalAmountController.text
        .replaceAll('.', '')
        .replaceAll(',', '')
        .replaceAll(' ', '');
    final total = double.tryParse(cleanTotal) ?? 0;

    double remaining = total;
    if (_hasPartialPayment) {
      final cleanPaid = _paidAmountController.text
          .replaceAll('.', '')
          .replaceAll(',', '')
          .replaceAll(' ', '');
      final paid = double.tryParse(cleanPaid) ?? 0;
      remaining = (total - paid).clamp(0.0, total);
    }

    final newDebt = DebtItem(
      id: 'debt_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      type: _selectedType,
      totalAmount: total,
      remainingAmount: remaining,
      dueDate: _selectedDueDate,
      status: remaining <= 0 ? 'paid' : 'active',
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    );

    widget.onAdd(newDebt);
    Navigator.of(context).pop();
  }

  String _formatDueDateText(DateTime date) {
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
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
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
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

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.note_add_rounded,
                          color: AppTheme.primaryColor,
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Tambah Hutang / Paylater',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      key: const Key('btn_close_debt_sheet'),
                      icon: const Icon(Icons.close_rounded),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 1. Pilihan Tipe Hutang
                const Text(
                  'Tipe Tagihan',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: DebtType.values.map((type) {
                      final isSelected = _selectedType == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          key: Key('debt_type_chip_${type.name}'),
                          avatar: Icon(
                            type.icon,
                            size: 15,
                            color: isSelected ? Colors.white : type.color,
                          ),
                          label: Text(
                            type.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected ? Colors.white : AppTheme.textPrimary,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: type.color,
                          backgroundColor: AppTheme.surfaceColor,
                          showCheckmark: false,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isSelected
                                  ? type.color
                                  : AppTheme.borderSubtle,
                            ),
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                _selectedType = type;
                              });
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Nama Hutang / Pihak Pemberi Hutang
                const Text(
                  'Nama Hutang / Layanan',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  key: const Key('input_debt_name'),
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Misal: Spaylater, Pinjaman Bank, Hutang Doni',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                    prefixIcon: const Icon(
                      Icons.title_rounded,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama hutang / paylater wajib diisi';
                    }
                    if (value.trim().length < 3) {
                      return 'Nama minimal 3 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 3. Total Nominal Hutang
                const Text(
                  'Total Nominal Tagihan (Rp)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  key: const Key('input_debt_total_amount'),
                  controller: _totalAmountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '0',
                    prefixText: 'Rp ',
                    prefixStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    prefixIcon: const Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nominal hutang wajib diisi';
                    }
                    final clean = value
                        .replaceAll('.', '')
                        .replaceAll(',', '')
                        .replaceAll(' ', '');
                    final parsed = double.tryParse(clean);
                    if (parsed == null || parsed <= 0) {
                      return 'Nominal harus lebih dari Rp 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // Quick nominal chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildQuickAmountChip('+100rb', 100000),
                      _buildQuickAmountChip('+500rb', 500000),
                      _buildQuickAmountChip('+1jt', 1000000),
                      _buildQuickAmountChip('+2.5jt', 2500000),
                      _buildQuickAmountChip('+5jt', 5000000),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Tanggal Jatuh Tempo
                const Text(
                  'Tanggal Jatuh Tempo',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  key: const Key('btn_pick_due_date'),
                  onTap: _pickDueDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_rounded,
                              size: 20,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _formatDueDateText(_selectedDueDate),
                              key: const Key('text_selected_due_date'),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const Icon(
                          Icons.arrow_drop_down_rounded,
                          color: AppTheme.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 5. Opsi Sudah Terbayar Sebagian (Switch)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sudah Dicicil / Dibayar Sebagian?',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Centang jika Anda sudah membayar cicilan sebelumnya',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch.adaptive(
                      key: const Key('switch_partial_paid'),
                      value: _hasPartialPayment,
                      activeTrackColor: AppTheme.primaryColor,
                      onChanged: (val) {
                        setState(() {
                          _hasPartialPayment = val;
                        });
                      },
                    ),
                  ],
                ),

                if (_hasPartialPayment) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    key: const Key('input_debt_paid_amount'),
                    controller: _paidAmountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Jumlah yang sudah dibayar',
                      prefixText: 'Rp ',
                      prefixStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF047857),
                      ),
                      prefixIcon: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 20,
                        color: Color(0xFF10B981),
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppTheme.borderSubtle),
                      ),
                    ),
                    validator: (val) {
                      if (!_hasPartialPayment) return null;
                      if (val == null || val.trim().isEmpty) {
                        return 'Masukkan jumlah yang sudah dibayar';
                      }
                      final cleanPaid = val
                          .replaceAll('.', '')
                          .replaceAll(',', '')
                          .replaceAll(' ', '');
                      final paid = double.tryParse(cleanPaid);
                      if (paid == null || paid < 0) {
                        return 'Jumlah bayar tidak valid';
                      }

                      final cleanTotal = _totalAmountController.text
                          .replaceAll('.', '')
                          .replaceAll(',', '')
                          .replaceAll(' ', '');
                      final total = double.tryParse(cleanTotal) ?? 0;
                      if (total > 0 && paid > total) {
                        return 'Jumlah terbayar tidak boleh melebihi total hutang';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),

                // 6. Catatan Tambahan (Opsional)
                const Text(
                  'Catatan (Opsional)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  key: const Key('input_debt_notes'),
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Misal: Bunga 0%, cicilan tenor 3 bulan, dsb.',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                    prefixIcon: const Icon(
                      Icons.note_alt_outlined,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    key: const Key('btn_submit_debt'),
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Simpan Catatan Tagihan',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAmountChip(String label, int amount) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        key: Key('chip_quick_amount_$amount'),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.08),
        side: BorderSide(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        onPressed: () => _addQuickAmount(amount),
      ),
    );
  }
}
