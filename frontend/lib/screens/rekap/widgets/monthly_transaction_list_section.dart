import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/transaction_item.dart';
import '../../../theme/app_theme.dart';
import '../../../mock/rekap_mock_data.dart';

class MonthlyTransactionListSection extends StatefulWidget {
  final List<TransactionItem> transactions;
  final String? monthLabel;
  final String? activeCategoryFilter;
  final ValueChanged<String?> onCategoryFilterChanged;

  const MonthlyTransactionListSection({
    super.key,
    required this.transactions,
    this.monthLabel,
    this.activeCategoryFilter,
    required this.onCategoryFilterChanged,
  });

  @override
  State<MonthlyTransactionListSection> createState() =>
      _MonthlyTransactionListSectionState();
}

class _MonthlyTransactionListSectionState
    extends State<MonthlyTransactionListSection> {
  final TextEditingController _searchController = TextEditingController();
  String _typeFilter = 'all'; // 'all', 'expense', 'income'
  String _searchQuery = '';
  String _sortBy = 'newest'; // 'newest', 'oldest', 'highest', 'lowest'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TransactionItem> get _filteredTransactions {
    final list = widget.transactions.where((tx) {
      // Type filter
      if (_typeFilter == 'expense' && !tx.isExpense) return false;
      if (_typeFilter == 'income' && !tx.isIncome) return false;

      // Category filter
      if (widget.activeCategoryFilter != null &&
          widget.activeCategoryFilter!.isNotEmpty) {
        if (tx.category.toLowerCase() !=
            widget.activeCategoryFilter!.toLowerCase()) {
          return false;
        }
      }

      // Search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchNote = tx.note.toLowerCase().contains(query);
        final matchCat = tx.category.toLowerCase().contains(query);
        final matchAmount = tx.amount.toString().contains(query);
        if (!matchNote && !matchCat && !matchAmount) return false;
      }

      return true;
    }).toList();

    // Apply sorting
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

  Map<String, List<TransactionItem>> _groupByDate(List<TransactionItem> items) {
    final Map<String, List<TransactionItem>> grouped = {};
    for (var tx in items) {
      final key = DateFormat('yyyy-MM-dd').format(tx.occurredAt);
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(tx);
    }
    return grouped;
  }

  void _showTransactionDetailSheet(TransactionItem tx) {
    final icon = RekapMockData.getCategoryIcon(tx.category);
    final color = RekapMockData.getCategoryColor(tx.category);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 22, color: color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.note,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tx.isIncome ? 'Pemasukan' : 'Pengeluaran',
                            style: TextStyle(
                              fontSize: 12,
                              color: tx.isIncome ? AppTheme.incomeColor : AppTheme.expenseColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      tx.formattedAmount,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: tx.isIncome ? AppTheme.incomeColor : AppTheme.expenseColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 16),
                _buildSheetRow(
                  label: 'Kategori',
                  value: tx.category,
                  badge: tx.isCustomCategory ? 'Kustom' : null,
                ),
                const SizedBox(height: 12),
                _buildSheetRow(
                  label: 'Tanggal & Waktu',
                  value: '${tx.occurredAt.day} ${_getMonthName(tx.occurredAt.month)} ${tx.occurredAt.year}, ${tx.timeFormatted}',
                ),
                const SizedBox(height: 12),
                _buildSheetRow(
                  label: 'Status Verifikasi',
                  value: tx.isConfirmed ? 'Terkonfirmasi' : 'Menunggu Konfirmasi',
                  valueColor: tx.isConfirmed ? AppTheme.incomeColor : Colors.amber.shade900,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Tutup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetRow({
    required String label,
    required String value,
    String? badge,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: valueColor ?? AppTheme.textPrimary,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTransactions;
    final headerTitle = widget.monthLabel != null
        ? 'Daftar Transaksi: ${widget.monthLabel}'
        : 'Riwayat Transaksi Bulan Ini';

    final grouped = _groupByDate(filtered);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title & Counter & Sort
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        size: 16,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        headerTitle,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Text(
                      '${filtered.length} Transaksi',
                      key: const Key('filtered_transaction_count_badge'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  PopupMenuButton<String>(
                    key: const Key('transaction_sort_button'),
                    initialValue: _sortBy,
                    tooltip: 'Urutkan Transaksi',
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (val) {
                      setState(() => _sortBy = val);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: const Icon(
                        Icons.sort_rounded,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'newest',
                        child: Text('Terbaru', style: TextStyle(fontSize: 12)),
                      ),
                      PopupMenuItem(
                        value: 'oldest',
                        child: Text('Terlama', style: TextStyle(fontSize: 12)),
                      ),
                      PopupMenuItem(
                        value: 'highest',
                        child: Text('Nominal Terbesar', style: TextStyle(fontSize: 12)),
                      ),
                      PopupMenuItem(
                        value: 'lowest',
                        child: Text('Nominal Terkecil', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Search Field
          TextField(
            key: const Key('transaction_search_input'),
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim();
              });
            },
            decoration: InputDecoration(
              hintText: 'Cari transaksi atau kategori...',
              hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.textSecondary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              fillColor: AppTheme.backgroundColor,
              filled: true,
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
                borderSide: const BorderSide(color: AppTheme.primaryColor),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Filter Chips: Semua, Pengeluaran, Pemasukan, and Active Category
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  keyName: 'filter_chip_all',
                  label: 'Semua',
                  isSelected: _typeFilter == 'all',
                  onTap: () {
                    setState(() {
                      _typeFilter = 'all';
                    });
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  keyName: 'filter_chip_expense',
                  label: 'Pengeluaran',
                  isSelected: _typeFilter == 'expense',
                  activeColor: AppTheme.expenseColor,
                  onTap: () {
                    setState(() {
                      _typeFilter = 'expense';
                    });
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  keyName: 'filter_chip_income',
                  label: 'Pemasukan',
                  isSelected: _typeFilter == 'income',
                  activeColor: AppTheme.incomeColor,
                  onTap: () {
                    setState(() {
                      _typeFilter = 'income';
                    });
                  },
                ),
                if (widget.activeCategoryFilter != null) ...[
                  const SizedBox(width: 8),
                  Chip(
                    key: const Key('active_category_filter_chip'),
                    label: Text(
                      'Kategori: ${widget.activeCategoryFilter}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    backgroundColor: AppTheme.primaryColor,
                    deleteIcon: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                    onDeleted: () => widget.onCategoryFilterChanged(null),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Transactions List
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 40,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tidak ada transaksi yang cocok.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: grouped.keys.length,
              itemBuilder: (context, groupIndex) {
                final dateKey = grouped.keys.elementAt(groupIndex);
                final groupItems = grouped[dateKey]!;
                final firstDate = groupItems.first.occurredAt;
                final dateLabel = '${firstDate.day} ${_getMonthName(firstDate.month)} ${firstDate.year}';

                double dayNet = 0;
                for (var t in groupItems) {
                  if (t.isIncome) {
                    dayNet += t.amount;
                  } else {
                    dayNet -= t.amount;
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date group header
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            dateLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            (dayNet >= 0 ? '+ ' : '- ') +
                                NumberFormat.currency(
                                  locale: 'id_ID',
                                  symbol: 'Rp ',
                                  decimalDigits: 0,
                                ).format(dayNet.abs()),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: dayNet >= 0
                                  ? AppTheme.incomeColor
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.borderSubtle),
                    ...groupItems.map((tx) {
                      final icon = RekapMockData.getCategoryIcon(tx.category);
                      final color = RekapMockData.getCategoryColor(tx.category);

                      return InkWell(
                        key: Key('transaction_item_row_${tx.id}'),
                        onTap: () => _showTransactionDetailSheet(tx),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: Row(
                            children: [
                              // Category Icon
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  icon,
                                  size: 19,
                                  color: color,
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Note & Category / Time
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tx.note,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            tx.category,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: color,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          tx.timeFormatted,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Formatted Amount
                              Text(
                                tx.formattedAmount,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: tx.isIncome
                                      ? AppTheme.incomeColor
                                      : AppTheme.expenseColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 6),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String keyName,
    required String label,
    required bool isSelected,
    Color? activeColor,
    required VoidCallback onTap,
  }) {
    final effectiveColor = activeColor ?? AppTheme.primaryColor;
    return InkWell(
      key: Key(keyName),
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? effectiveColor.withValues(alpha: 0.15)
              : AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? effectiveColor : AppTheme.borderSubtle,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? effectiveColor : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const names = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    if (month >= 1 && month <= 12) return names[month];
    return '';
  }
}

// Convenient export alias matching the task title directly
typedef SelectedMonthTransactionList = MonthlyTransactionListSection;
typedef DaftarTransaksiBulanTerpilih = MonthlyTransactionListSection;
