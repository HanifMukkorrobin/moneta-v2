import 'package:flutter/material.dart';
import '../../../models/transaction_item.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/category_icon_mapper.dart';
import 'transaction_card.dart';

class ManualInputSheet extends StatefulWidget {
  final String? initialNote;
  final Function(TransactionItem) onSave;

  const ManualInputSheet({
    super.key,
    this.initialNote,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialNote,
    required Function(TransactionItem) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ManualInputSheet(
        initialNote: initialNote,
        onSave: onSave,
      ),
    );
  }

  @override
  State<ManualInputSheet> createState() => _ManualInputSheetState();
}

class _ManualInputSheetState extends State<ManualInputSheet> {
  final TextEditingController _amountController = TextEditingController();
  late TextEditingController _noteController;
  String _selectedType = 'expense';
  String _selectedCategory = CategoryIconMapper.defaultExpenseCategories.first;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.initialNote ?? '');
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _addAmount(double add) {
    final current = double.tryParse(_amountController.text) ?? 0;
    final updated = current + add;
    setState(() {
      _amountController.text = updated.toInt().toString();
    });
  }

  void _handleSave() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nominal harus lebih besar dari Rp 0'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final note = _noteController.text.trim().isEmpty
        ? (_selectedType == 'expense' ? 'Pengeluaran Manual' : 'Pemasukan Manual')
        : _noteController.text.trim();

    final tx = TransactionItem(
      id: 'tx_manual_${DateTime.now().millisecondsSinceEpoch}',
      note: note,
      amount: amount,
      type: _selectedType,
      category: _selectedCategory,
      occurredAt: _selectedDate,
      isConfirmed: true,
    );

    widget.onSave(tx);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = _selectedType == 'expense';
    final categories = isExpense
        ? CategoryIconMapper.defaultExpenseCategories
        : CategoryIconMapper.defaultIncomeCategories;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 20,
      ),
      child: SingleChildScrollView(
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
                  color: AppTheme.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.edit_note_rounded,
                        color: AppTheme.primaryColor, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Input Transaksi Manual',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Type Segment
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedType = 'expense';
                          _selectedCategory = CategoryIconMapper.defaultExpenseCategories.first;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isExpense ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: isExpense
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                  )
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Pengeluaran',
                          style: TextStyle(
                            color: isExpense
                                ? AppTheme.expenseColor
                                : AppTheme.textSecondary,
                            fontWeight: isExpense
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedType = 'income';
                          _selectedCategory = CategoryIconMapper.defaultIncomeCategories.first;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: !isExpense ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: !isExpense
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                  )
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Pemasukan',
                          style: TextStyle(
                            color: !isExpense
                                ? AppTheme.incomeColor
                                : AppTheme.textSecondary,
                            fontWeight: !isExpense
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Nominal Input
            const Text(
              'Nominal (Rp)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                prefixText: 'Rp ',
                hintText: 'Contoh: 50000',
              ),
            ),

            const SizedBox(height: 8),

            // Quick Add Chips
            Row(
              children: [
                _buildQuickChip('+10rb', 10000),
                const SizedBox(width: 6),
                _buildQuickChip('+25rb', 25000),
                const SizedBox(width: 6),
                _buildQuickChip('+50rb', 50000),
                const SizedBox(width: 6),
                _buildQuickChip('+100rb', 100000),
              ],
            ),

            const SizedBox(height: 16),

            // Catatan
            const Text(
              'Catatan Transaksi',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                hintText: 'Contoh: Belanja sayur di pasar',
              ),
            ),

            const SizedBox(height: 16),

            // Kategori
            const Text(
              'Kategori',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                final catIcon =
                    TransactionCard.getCategoryIcon(cat, isExpense);
                return ChoiceChip(
                  avatar: Icon(
                    catIcon,
                    size: 14,
                    color: isSelected ? Colors.white : AppTheme.primaryColor,
                  ),
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryColor,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedCategory = cat;
                      });
                    }
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Date picker
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.borderSubtle),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Tanggal: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Ubah',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _handleSave,
                    child: const Text('Simpan Transaksi'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, double add) {
    return InkWell(
      onTap: () => _addAmount(add),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }
}
