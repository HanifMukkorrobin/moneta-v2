import 'package:flutter/material.dart';
import '../../../models/category_confirmation_item.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/category_icon_mapper.dart';
import '../../chat/widgets/transaction_card.dart';

class EditCategorySheet extends StatefulWidget {
  final CategoryConfirmationItem item;
  final Function(String newCategory, String newType, bool isCustom) onSave;

  const EditCategorySheet({
    super.key,
    required this.item,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required CategoryConfirmationItem item,
    required Function(String newCategory, String newType, bool isCustom) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditCategorySheet(item: item, onSave: onSave),
    );
  }

  @override
  State<EditCategorySheet> createState() => _EditCategorySheetState();
}

class _EditCategorySheetState extends State<EditCategorySheet> {
  late String _selectedType;
  late String _selectedCategory;
  final TextEditingController _customCatController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool _isCreatingCustom = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedType = widget.item.type;
    _selectedCategory = widget.item.detectedCategory;
  }

  @override
  void dispose() {
    _customCatController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _currentCategories {
    final list = _selectedType == 'income'
        ? CategoryIconMapper.defaultIncomeCategories
        : CategoryIconMapper.defaultExpenseCategories;

    if (_searchQuery.trim().isEmpty) return list;
    return list
        .where(
            (c) => c.toLowerCase().contains(_searchQuery.toLowerCase().trim()))
        .toList();
  }

  void _handleSave() {
    String finalCat = _selectedCategory;
    bool isCustom = false;

    if (_isCreatingCustom && _customCatController.text.trim().isNotEmpty) {
      finalCat = _customCatController.text.trim();
      isCustom = true;
    }

    widget.onSave(finalCat, _selectedType, isCustom);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = _selectedType == 'expense';
    final typeColor = isExpense ? AppTheme.expenseColor : AppTheme.incomeColor;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sheet Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Perbaiki / Ganti Kategori',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Perbaiki hasil tebakan AI agar makin akurat',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Item context preview
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.item.rawSentence,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Nominal: ${widget.item.formattedAmount}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: typeColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Pilah Masuk & Keluar Segmented Selector
                    const Text(
                      'Pilah Jenis Transaksi',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedType = 'expense';
                                  if (!CategoryIconMapper.defaultExpenseCategories
                                      .contains(_selectedCategory)) {
                                    _selectedCategory = 'Makan & Minuman';
                                  }
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isExpense
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: isExpense
                                      ? [
                                          BoxShadow(
                                            color:
                                                Colors.black.withValues(alpha: 0.05),
                                            blurRadius: 4,
                                          )
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.arrow_outward_rounded,
                                      size: 16,
                                      color: isExpense
                                          ? AppTheme.expenseColor
                                          : Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Pengeluaran',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isExpense
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isExpense
                                            ? AppTheme.expenseColor
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedType = 'income';
                                  if (!CategoryIconMapper.defaultIncomeCategories
                                      .contains(_selectedCategory)) {
                                    _selectedCategory = 'Gaji';
                                  }
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: !isExpense
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: !isExpense
                                      ? [
                                          BoxShadow(
                                            color:
                                                Colors.black.withValues(alpha: 0.05),
                                            blurRadius: 4,
                                          )
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.arrow_downward_rounded,
                                      size: 16,
                                      color: !isExpense
                                          ? AppTheme.incomeColor
                                          : Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Pemasukan',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: !isExpense
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: !isExpense
                                            ? AppTheme.incomeColor
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Category Search / Selection
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Pilih Kategori',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _isCreatingCustom = !_isCreatingCustom;
                            });
                          },
                          icon: Icon(
                            _isCreatingCustom
                                ? Icons.list_rounded
                                : Icons.add_circle_outline_rounded,
                            size: 16,
                          ),
                          label: Text(
                            _isCreatingCustom
                                ? 'Daftar Kategori'
                                : '+ Kategori Sendiri',
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),

                    if (_isCreatingCustom) ...[
                      // Custom Category Field (Kategori Sendiri)
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Buat Kategori Kustom Sendiri',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _customCatController,
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText: 'Contoh: Hobi Kopi, Skincare, Kos',
                                filled: true,
                                fillColor: Colors.white,
                                prefixIcon: const Icon(Icons.bookmark_add_outlined,
                                    size: 18),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: Colors.purple.shade300),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Search Bar
                      const SizedBox(height: 8),
                      TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Cari kategori...',
                          prefixIcon:
                              const Icon(Icons.search_rounded, size: 18),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Category Chips Grid
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _currentCategories.map((cat) {
                          final isSelected =
                              !_isCreatingCustom && _selectedCategory == cat;
                          final icon = TransactionCard.getCategoryIcon(
                              cat, isExpense);
                          return ChoiceChip(
                            avatar: Icon(
                              icon,
                              size: 16,
                              color: isSelected ? Colors.white : typeColor,
                            ),
                            label: Text(cat),
                            selected: isSelected,
                            selectedColor: AppTheme.primaryColor,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.textPrimary,
                            ),
                            backgroundColor: Colors.grey.shade100,
                            side: BorderSide(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : Colors.grey.shade300,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedCategory = cat;
                                  _isCreatingCustom = false;
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Action Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Terapkan Perubahan Kategori',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
