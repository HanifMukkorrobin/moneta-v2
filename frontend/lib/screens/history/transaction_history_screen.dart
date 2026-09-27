import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/transaction_item.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../category_confirmation/category_confirmation_screen.dart';
import '../category_confirmation/widgets/category_picker_sheet.dart';
import 'widgets/transaction_history_card.dart';

class TransactionHistoryScreen extends StatefulWidget {
  final List<TransactionItem>? initialTransactions;

  const TransactionHistoryScreen({
    super.key,
    this.initialTransactions,
  });

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _typeFilter = 'all'; // 'all', 'expense', 'income'
  String _selectedCategory = 'all';
  String _statusFilter = 'all'; // 'all', 'confirmed', 'pending'
  String _sortBy = 'newest'; // 'newest', 'oldest', 'highest', 'lowest'

  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_onStateChange);
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onStateChange);
    _searchController.dispose();
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  List<TransactionItem> get _sourceTransactions =>
      widget.initialTransactions ?? AppState.instance.allTransactions;

  List<String> get _availableCategories {
    final categories = <String>{};
    for (var tx in _sourceTransactions) {
      if (tx.category.isNotEmpty) {
        categories.add(tx.category);
      }
    }
    final sorted = categories.toList()..sort();
    return sorted;
  }

  List<TransactionItem> get _filteredTransactions {
    final list = _sourceTransactions.where((tx) {
      // Type filter
      if (_typeFilter == 'expense' && !tx.isExpense) return false;
      if (_typeFilter == 'income' && !tx.isIncome) return false;

      // Category filter
      if (_selectedCategory != 'all' && tx.category != _selectedCategory) {
        return false;
      }

      // Status filter
      if (_statusFilter == 'confirmed' && !tx.isConfirmed) return false;
      if (_statusFilter == 'pending' && tx.isConfirmed) return false;

      // Search query
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.toLowerCase().trim();
        final matchNote = tx.note.toLowerCase().contains(query);
        final matchCat = tx.category.toLowerCase().contains(query);
        return matchNote || matchCat;
      }

      return true;
    }).toList();

    // Sorting
    switch (_sortBy) {
      case 'oldest':
        list.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
        break;
      case 'highest':
        list.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case 'lowest':
        list.sort((a, b) => a.amount.compareTo(b.amount));
        break;
      case 'newest':
      default:
        list.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
        break;
    }

    return list;
  }

  double get _totalExpense {
    double total = 0;
    for (var tx in _sourceTransactions) {
      if (tx.isExpense) total += tx.amount;
    }
    return total;
  }

  double get _totalIncome {
    double total = 0;
    for (var tx in _sourceTransactions) {
      if (tx.isIncome) total += tx.amount;
    }
    return total;
  }

  double get _netBalance => _totalIncome - _totalExpense;

  int get _unconfirmedCount =>
      _sourceTransactions.where((t) => !t.isConfirmed).length;

  void _handleChangeCategory(TransactionItem tx) {
    final oldCat = tx.category;
    CategoryPickerSheet.show(
      context,
      initialCategory: tx.category,
      initialType: tx.type,
      onSelected: (newCategory, newType, isCustom) {
        AppState.instance.updateTransactionCategory(
          tx.id,
          newCategory,
          newType: newType,
          isCustom: isCustom,
        );

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kategori catatan "${tx.note}" diubah: $oldCat → $newCategory',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }

  void _handleToggleType(TransactionItem tx) {
    final newType = tx.isExpense ? 'income' : 'expense';
    final defaultCat = newType == 'income' ? 'Gaji' : 'Makan & Minuman';

    AppState.instance.updateTransactionCategory(
      tx.id,
      defaultCat,
      newType: newType,
    );

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Jenis transaksi diubah ke ${newType == 'expense' ? 'Pengeluaran' : 'Pemasukan'} ($defaultCat)',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleDeleteTransaction(TransactionItem tx) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Catatan Ini?'),
        content: Text(
          'Catatan "${tx.note}" (${tx.formattedAmount}) akan dihapus dari riwayat transaksi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.expenseColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final removed = AppState.instance.deleteTransaction(tx.id);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Catatan "${tx.note}" dihapus'),
          action: removed != null
              ? SnackBarAction(
                  label: 'Urungkan',
                  textColor: Colors.amberAccent,
                  onPressed: () {
                    AppState.instance.restoreMessage(removed, 0);
                  },
                )
              : null,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final filteredList = _filteredTransactions;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Riwayat Catatan Transaksi',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              'Kelola catatan & ganti kategori transaksi',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          // Sort Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded, size: 22),
            tooltip: 'Urutkan Riwayat',
            initialValue: _sortBy,
            onSelected: (val) {
              setState(() {
                _sortBy = val;
              });
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(
                value: 'newest',
                child: Text('Terbaru Dulu'),
              ),
              PopupMenuItem(
                value: 'oldest',
                child: Text('Terlama Dulu'),
              ),
              PopupMenuItem(
                value: 'highest',
                child: Text('Nominal Terbesar'),
              ),
              PopupMenuItem(
                value: 'lowest',
                child: Text('Nominal Terkecil'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded, size: 22),
            tooltip: 'Reset Data',
            onPressed: () {
              AppState.instance.resetToDefault();
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Data transaksi berhasil di-reset'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Financial Summary Card
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderSubtle),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            size: 18,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Catatan',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${_sourceTransactions.length} Transaksi',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Saldo Bersih',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          currencyFormatter.format(_netBalance),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _netBalance >= 0
                                ? AppTheme.incomeColor
                                : AppTheme.expenseColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppTheme.borderSubtle),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.arrow_outward_rounded,
                            size: 14,
                            color: AppTheme.expenseColor,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Keluar: ${currencyFormatter.format(_totalExpense)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.expenseColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 14,
                      width: 1,
                      color: AppTheme.borderSubtle,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.arrow_downward_rounded,
                            size: 14,
                            color: AppTheme.incomeColor,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Masuk: ${currencyFormatter.format(_totalIncome)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.incomeColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Unconfirmed items alert banner (if any)
          if (_unconfirmedCount > 0)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Material(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CategoryConfirmationScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 16, color: Colors.amber.shade800),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$_unconfirmedCount transaksi butuh konfirmasi kategori AI',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            size: 18, color: Colors.amber.shade800),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: 'Cari catatan atau kategori...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
          ),

          // Type and Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                // Type Filter Chips
                _buildChoiceChip('all', 'Semua Jenis', _typeFilter, (val) {
                  setState(() => _typeFilter = val);
                }),
                const SizedBox(width: 6),
                _buildChoiceChip('expense', 'Pengeluaran', _typeFilter, (val) {
                  setState(() => _typeFilter = val);
                }),
                const SizedBox(width: 6),
                _buildChoiceChip('income', 'Pemasukan', _typeFilter, (val) {
                  setState(() => _typeFilter = val);
                }),

                const SizedBox(width: 10),
                Container(height: 18, width: 1, color: Colors.grey.shade300),
                const SizedBox(width: 10),

                // All Categories chip
                _buildCategoryChip('all', 'Semua Kategori'),
                const SizedBox(width: 6),

                // Individual Category Chips
                ..._availableCategories.map((cat) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _buildCategoryChip(cat, cat),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // Transaction Cards List
          Expanded(
            child: filteredList.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24, top: 4),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final tx = filteredList[index];
                      return TransactionHistoryCard(
                        key: ValueKey(tx.id),
                        transaction: tx,
                        onChangeCategory: () => _handleChangeCategory(tx),
                        onToggleType: () => _handleToggleType(tx),
                        onDelete: () => _handleDeleteTransaction(tx),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip(
    String value,
    String label,
    String groupValue,
    Function(String) onSelected,
  ) {
    final isSelected = value == groupValue;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primaryColor,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : Colors.grey.shade700,
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
      ),
      visualDensity: VisualDensity.compact,
      onSelected: (selected) {
        if (selected) onSelected(value);
      },
    );
  }

  Widget _buildCategoryChip(String value, String label) {
    final isSelected = _selectedCategory == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primaryLight.withValues(alpha: 0.2),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? AppTheme.primaryColor : Colors.grey.shade700,
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
      ),
      visualDensity: VisualDensity.compact,
      onSelected: (selected) {
        setState(() {
          _selectedCategory = selected ? value : 'all';
        });
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 48,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tidak ada catatan transaksi ditemukan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Coba sesuaikan kata kunci pencarian atau ubah filter jenis/kategori di atas.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                  _typeFilter = 'all';
                  _selectedCategory = 'all';
                  _statusFilter = 'all';
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reset Filter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
