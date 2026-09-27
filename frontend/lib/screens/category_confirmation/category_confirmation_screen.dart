import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../mock/category_confirmation_mock_data.dart';
import '../../models/category_confirmation_item.dart';
import '../../models/transaction_item.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import 'widgets/category_confirmation_card.dart';
import 'widgets/edit_category_sheet.dart';

class CategoryConfirmationScreen extends StatefulWidget {
  const CategoryConfirmationScreen({super.key});

  @override
  State<CategoryConfirmationScreen> createState() =>
      _CategoryConfirmationScreenState();
}

class _CategoryConfirmationScreenState
    extends State<CategoryConfirmationScreen> {
  late List<CategoryConfirmationItem> _items;
  String _selectedFilter = 'pending'; // 'all', 'pending', 'expense', 'income', 'confirmed'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _resetData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetData() {
    setState(() {
      _items = CategoryConfirmationMockData.getInitialItems();
    });
  }

  List<CategoryConfirmationItem> get _filteredItems {
    return _items.where((item) {
      // Filter by tab
      if (_selectedFilter == 'pending' && item.isConfirmed) return false;
      if (_selectedFilter == 'confirmed' && !item.isConfirmed) return false;
      if (_selectedFilter == 'expense' && !item.isExpense) return false;
      if (_selectedFilter == 'income' && !item.isIncome) return false;

      // Filter by search query
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.toLowerCase().trim();
        final matchSentence = item.rawSentence.toLowerCase().contains(query);
        final matchCategory =
            item.detectedCategory.toLowerCase().contains(query);
        return matchSentence || matchCategory;
      }

      return true;
    }).toList();
  }

  int get _pendingCount => _items.where((i) => !i.isConfirmed).length;
  int get _confirmedCount => _items.where((i) => i.isConfirmed).length;
  int get _expenseCount => _items.where((i) => i.isExpense).length;
  int get _incomeCount => _items.where((i) => i.isIncome).length;

  double get _pendingTotalAmount {
    double total = 0;
    for (var i in _items) {
      if (!i.isConfirmed) {
        total += i.amount;
      }
    }
    return total;
  }

  void _handleConfirmItem(CategoryConfirmationItem item) {
    setState(() {
      item.isConfirmed = true;
    });

    // Also sync to central AppState as confirmed transaction
    final newTx = TransactionItem(
      id: 'tx_conf_${item.id}',
      note: item.rawSentence,
      amount: item.amount,
      type: item.type,
      category: item.detectedCategory,
      occurredAt: item.occurredAt,
      isConfirmed: true,
    );
    AppState.instance.addManualTransaction(newTx);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${item.detectedCategory} (${item.formattedAmount}) dikonfirmasi!',
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleConfirmAll() {
    final pendingItems = _items.where((i) => !i.isConfirmed).toList();
    if (pendingItems.isEmpty) return;

    setState(() {
      for (var item in pendingItems) {
        item.isConfirmed = true;
        final newTx = TransactionItem(
          id: 'tx_conf_${item.id}',
          note: item.rawSentence,
          amount: item.amount,
          type: item.type,
          category: item.detectedCategory,
          occurredAt: item.occurredAt,
          isConfirmed: true,
        );
        AppState.instance.addManualTransaction(newTx);
      }
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Semua ${pendingItems.length} transaksi berhasil dikonfirmasi ke buku kas!',
        ),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _handleSelectAlternative(
      CategoryConfirmationItem item, String newCategory) {
    final oldCategory = item.detectedCategory;
    setState(() {
      item.detectedCategory = newCategory;
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Kategori diperbarui: $oldCategory → $newCategory',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleOpenEditCategory(CategoryConfirmationItem item) {
    EditCategorySheet.show(
      context,
      item: item,
      onSave: (newCategory, newType, isCustom) {
        setState(() {
          item.detectedCategory = newCategory;
          item.type = newType;
          item.isCustomCategory = isCustom;
        });

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Kategori diperbarui: $newCategory (${newType == 'expense' ? 'Pengeluaran' : 'Pemasukan'})',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }

  void _handleDeleteItem(CategoryConfirmationItem item) {
    final index = _items.indexOf(item);
    setState(() {
      _items.remove(item);
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Transaksi diabaikan & dihapus'),
        action: SnackBarAction(
          label: 'Urungkan',
          textColor: Colors.amberAccent,
          onPressed: () {
            setState(() {
              if (index >= 0 && index <= _items.length) {
                _items.insert(index, item);
              } else {
                _items.add(item);
              }
            });
          },
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.auto_awesome, color: AppTheme.primaryColor, size: 22),
            SizedBox(width: 8),
            Text('Kategori Otomatis AI', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Bagaimana AI bekerja?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            SizedBox(height: 6),
            Text(
              '1. Tebak Kategori: AI menganalisis kata kunci dalam kalimat chat dan mencocokkannya dengan kategori yang relevan.\n\n'
              '2. Pilah Masuk & Keluar: AI membedakan transaksi pemasukan atau pengeluaran secara cerdas.\n\n'
              '3. Perbaiki Kategori: Bila tebakan AI kurang pas, Anda dapat menggantinya. Tindakan ini melatih AI makin akurat untuk transaksi berikutnya.\n\n'
              '4. Kategori Sendiri: Anda bebas menambahkan kategori kustom sesuai preferensi pribadi.',
              style: TextStyle(fontSize: 12.5, height: 1.4),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final displayItems = _filteredItems;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Konfirmasi Kategori AI',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              'Kategori Otomatis & Pilah Masuk/Keluar',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, size: 22),
            tooltip: 'Tentang Kategori AI',
            onPressed: _showInfoDialog,
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded, size: 22),
            tooltip: 'Reset Data Tiruan',
            onPressed: () {
              _resetData();
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Data tiruan konfirmasi kategori berhasil di-reset'),
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
          // Top Summary Banner
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _pendingCount > 0
                            ? '$_pendingCount Transaksi Perlu Konfirmasi'
                            : 'Semua Kategori Sudah Dikonfirmasi! 🎉',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _pendingCount > 0
                            ? 'Total tertunda: ${currencyFormatter.format(_pendingTotalAmount)}'
                            : 'AI telah mencatat seluruh transaksi ke buku kas.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_pendingCount > 0)
                  ElevatedButton(
                    onPressed: _handleConfirmAll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Semua',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: 'Cari transaksi atau kategori...',
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
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

          // Filter Segment Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _buildFilterChip('pending', 'Perlu Ditinjau ($_pendingCount)'),
                const SizedBox(width: 8),
                _buildFilterChip('all', 'Semua (${_items.length})'),
                const SizedBox(width: 8),
                _buildFilterChip('expense', 'Pengeluaran ($_expenseCount)'),
                const SizedBox(width: 8),
                _buildFilterChip('income', 'Pemasukan ($_incomeCount)'),
                const SizedBox(width: 8),
                _buildFilterChip('confirmed', 'Terkonfirmasi ($_confirmedCount)'),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // Transaction Cards List
          Expanded(
            child: displayItems.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: displayItems.length,
                    itemBuilder: (context, index) {
                      final item = displayItems[index];
                      return CategoryConfirmationCard(
                        key: ValueKey(item.id),
                        item: item,
                        onConfirm: () => _handleConfirmItem(item),
                        onEditCategory: () => _handleOpenEditCategory(item),
                        onSelectAlternative: (alt) =>
                            _handleSelectAlternative(item, alt),
                        onDelete: () => _handleDeleteItem(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() {
            _selectedFilter = key;
          });
        }
      },
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? AppTheme.primaryColor : Colors.grey.shade700,
      ),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
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
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _selectedFilter == 'pending'
                    ? Icons.task_alt_rounded
                    : Icons.inbox_outlined,
                size: 48,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _selectedFilter == 'pending'
                  ? 'Semua Transaksi Sudah Dikonfirmasi!'
                  : 'Tidak ada transaksi yang cocok.',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _selectedFilter == 'pending'
                  ? 'Kategori yang ditebak AI telah diterima dan tersimpan ke buku kas.'
                  : 'Coba ubah kata kunci pencarian atau ganti filter di atas.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _resetData,
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: const Text('Muat Ulang Data Tiruan'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
