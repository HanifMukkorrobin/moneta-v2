import 'package:flutter/material.dart';
import '../../../mock/mock_data.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_theme.dart';
import '../../category_management/manage_categories_screen.dart';
import '../../chat/widgets/transaction_card.dart';
import 'frequent_category_suggestions.dart';

class CategoryPickerSheet extends StatefulWidget {
  final String initialCategory;
  final String initialType;
  final Function(String selectedCategory, String selectedType, bool isCustom)
      onSelected;

  const CategoryPickerSheet({
    super.key,
    required this.initialCategory,
    required this.initialType,
    required this.onSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required String initialCategory,
    required String initialType,
    required Function(String category, String type, bool isCustom) onSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CategoryPickerSheet(
        initialCategory: initialCategory,
        initialType: initialType,
        onSelected: onSelected,
      ),
    );
  }

  @override
  State<CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<CategoryPickerSheet> {
  late String _currentType;
  late String _currentCategory;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customCatController = TextEditingController();
  bool _isCustomMode = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _currentType = widget.initialType;
    _currentCategory = widget.initialCategory;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customCatController.dispose();
    super.dispose();
  }

  bool get _isExpense => _currentType == 'expense';

  List<String> get _availableCategories {
    final state = AppState.instance;
    final fromState = _isExpense
        ? state.expenseCategories.map((c) => c.name).toList()
        : state.incomeCategories.map((c) => c.name).toList();

    final base = fromState.isNotEmpty
        ? fromState
        : (_isExpense
            ? MockData.expenseCategories
            : MockData.incomeCategories);

    if (_searchQuery.trim().isEmpty) return base;
    return base
        .where(
            (c) => c.toLowerCase().contains(_searchQuery.toLowerCase().trim()))
        .toList();
  }

  void _applySelection() {
    String finalCat = _currentCategory;
    bool isCustom = false;

    if (_isCustomMode && _customCatController.text.trim().isNotEmpty) {
      finalCat = _customCatController.text.trim();
      isCustom = true;
      AppState.instance.addCustomCategory(finalCat, type: _currentType);
    }

    widget.onSelected(finalCat, _currentType, isCustom);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final typeColor =
        _isExpense ? AppTheme.expenseColor : AppTheme.incomeColor;

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
            // Handle
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

            // Title & Close
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pemilih Kategori Manual',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pilih kategori atau ubah jenis transaksi di kartu',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
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

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type Switcher (Pilah Masuk / Keluar)
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
                                  _currentType = 'expense';
                                  if (!MockData.expenseCategories
                                      .contains(_currentCategory)) {
                                    _currentCategory = 'Makan & Minuman';
                                  }
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _isExpense
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: _isExpense
                                      ? [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.05),
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
                                      color: _isExpense
                                          ? AppTheme.expenseColor
                                          : Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Pengeluaran',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: _isExpense
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: _isExpense
                                              ? AppTheme.expenseColor
                                              : Colors.grey.shade700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
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
                                  _currentType = 'income';
                                  if (!MockData.incomeCategories
                                      .contains(_currentCategory)) {
                                    _currentCategory = 'Gaji';
                                  }
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: !_isExpense
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: !_isExpense
                                      ? [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.05),
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
                                      color: !_isExpense
                                          ? AppTheme.incomeColor
                                          : Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Pemasukan',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: !_isExpense
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: !_isExpense
                                              ? AppTheme.incomeColor
                                              : Colors.grey.shade700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
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

                    const SizedBox(height: 16),

                    // Frequent Category Suggestions
                    if (_searchQuery.trim().isEmpty && !_isCustomMode) ...[
                      FrequentCategorySuggestions(
                        type: _currentType,
                        selectedCategory: _currentCategory,
                        onCategorySelected: (cat) {
                          setState(() {
                            _currentCategory = cat;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Search Bar or Custom Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _isCustomMode
                                ? 'Buat Kategori Kustom'
                                : 'Daftar Kategori',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ManageCategoriesScreen(
                                      initialType: _currentType,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.settings_outlined, size: 14),
                              label: const Text('Kelola',
                                  style: TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey.shade700,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isCustomMode = !_isCustomMode;
                                });
                              },
                              icon: Icon(
                                _isCustomMode
                                    ? Icons.list_rounded
                                    : Icons.add_circle_outline_rounded,
                                size: 16,
                              ),
                              label: Text(
                                _isCustomMode
                                    ? 'Lihat Semua Kategori'
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
                      ],
                    ),

                    if (_isCustomMode) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.bookmark_add_outlined,
                                  color: Colors.purple,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Kategori Kustom Baru',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                    color: Colors.purple.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _customCatController,
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText: 'Contoh: Gym, Skincare, Hobi Kamera',
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: Colors.purple.shade300),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Kategori kustom akan langsung disimpan dan melatih AI mengenali transaksi serupa.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.purple.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      // Search TextField
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

                      const SizedBox(height: 14),

                      // Category Grid Chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableCategories.map((cat) {
                          final isSelected =
                              !_isCustomMode && _currentCategory == cat;
                          final icon = TransactionCard.getCategoryIcon(
                              cat, _isExpense);

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
                                  _currentCategory = cat;
                                  _isCustomMode = false;
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Quick Summary of Selection
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 16,
                            color: typeColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isCustomMode &&
                                      _customCatController.text.trim().isNotEmpty
                                  ? 'Kategori terpilih: ${_customCatController.text.trim()} (Custom • ${_isExpense ? 'Pengeluaran' : 'Pemasukan'})'
                                  : 'Kategori terpilih: $_currentCategory (${_isExpense ? 'Pengeluaran' : 'Pemasukan'})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Confirm Button
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
                onPressed: _applySelection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Terapkan Kategori',
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
