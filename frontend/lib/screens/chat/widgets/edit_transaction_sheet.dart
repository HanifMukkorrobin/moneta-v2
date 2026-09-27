import 'package:flutter/material.dart';
import '../../../mock/mock_data.dart';
import '../../../models/transaction_item.dart';
import '../../../theme/app_theme.dart';
import 'transaction_card.dart';

class EditTransactionSheet extends StatefulWidget {
  final TransactionItem transaction;
  final Function(TransactionItem) onSave;

  const EditTransactionSheet({
    super.key,
    required this.transaction,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required TransactionItem transaction,
    required Function(TransactionItem) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditTransactionSheet(
        transaction: transaction,
        onSave: onSave,
      ),
    );
  }

  @override
  State<EditTransactionSheet> createState() => _EditTransactionSheetState();
}

class _EditTransactionSheetState extends State<EditTransactionSheet> {
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late String _selectedType;
  late String _selectedCategory;
  late DateTime _selectedDate;
  final TextEditingController _customCategoryController =
      TextEditingController();
  bool _showCustomCategoryInput = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.transaction.amount.toInt().toString(),
    );
    _noteController = TextEditingController(text: widget.transaction.note);
    _selectedType = widget.transaction.type;
    _selectedCategory = widget.transaction.category;
    _selectedDate = widget.transaction.occurredAt;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final amount = double.tryParse(_amountController.text) ??
        widget.transaction.amount;
    final note = _noteController.text.trim().isEmpty
        ? widget.transaction.note
        : _noteController.text.trim();

    final updatedTx = widget.transaction.copyWith(
      amount: amount,
      note: note,
      type: _selectedType,
      category: _selectedCategory,
      occurredAt: _selectedDate,
    );

    widget.onSave(updatedTx);
    Navigator.pop(context);
  }

  void _addCustomCategory() {
    final name = _customCategoryController.text.trim();
    if (name.isNotEmpty) {
      setState(() {
        _selectedCategory = name;
        _showCustomCategoryInput = false;
        _customCategoryController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = _selectedType == 'expense';
    final categories = isExpense
        ? MockData.expenseCategories
        : MockData.incomeCategories;

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
                      'Ubah Data Transaksi',
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
            const SizedBox(height: 16),

            // Jenis Transaksi Toggle (Pengeluaran / Pemasukan)
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
                          _selectedCategory = MockData.expenseCategories.first;
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
                          _selectedCategory = MockData.incomeCategories.first;
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
                hintText: 'Contoh: 25000',
              ),
            ),

            const SizedBox(height: 16),

            // Catatan / Deskripsi Input
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
                hintText: 'Contoh: Makan siang nasi uduk',
              ),
            ),

            const SizedBox(height: 16),

            // Kategori Selection
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Kategori',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showCustomCategoryInput = !_showCustomCategoryInput;
                    });
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Kategori Baru',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),

            if (_showCustomCategoryInput) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customCategoryController,
                      decoration: const InputDecoration(
                        hintText: 'Nama kategori baru...',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addCustomCategory,
                    child: const Text('Tambah'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            const SizedBox(height: 6),
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

            const SizedBox(height: 24),

            // Save Buttons
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
                    child: const Text('Simpan Perubahan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
