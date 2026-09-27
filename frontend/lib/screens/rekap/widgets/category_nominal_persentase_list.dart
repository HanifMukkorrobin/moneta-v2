import 'package:flutter/material.dart';
import '../../../models/monthly_rekap_data.dart';
import '../../../theme/app_theme.dart';

class CategoryNominalPersentaseList extends StatefulWidget {
  final List<CategoryBreakdownItem> items;
  final String type; // 'expense' or 'income'
  final String? selectedCategory;
  final ValueChanged<String?> onCategorySelected;
  final bool showSearch;
  final bool showSorting;
  final bool showRankBadges;

  const CategoryNominalPersentaseList({
    super.key,
    required this.items,
    this.type = 'expense',
    this.selectedCategory,
    required this.onCategorySelected,
    this.showSearch = true,
    this.showSorting = true,
    this.showRankBadges = true,
  });

  @override
  State<CategoryNominalPersentaseList> createState() =>
      _CategoryNominalPersentaseListState();
}

class _CategoryNominalPersentaseListState
    extends State<CategoryNominalPersentaseList> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'highest'; // 'highest', 'lowest', 'most_trx', 'name'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CategoryBreakdownItem> get _filteredAndSortedItems {
    final list = widget.items.where((item) {
      if (_searchQuery.isNotEmpty) {
        return item.category.toLowerCase().contains(_searchQuery.toLowerCase());
      }
      return true;
    }).toList();

    switch (_sortBy) {
      case 'lowest':
        list.sort((a, b) => a.total.compareTo(b.total));
        break;
      case 'most_trx':
        list.sort((a, b) => b.transactionCount.compareTo(a.transactionCount));
        break;
      case 'name':
        list.sort((a, b) => a.category.toLowerCase().compareTo(b.category.toLowerCase()));
        break;
      case 'highest':
      default:
        list.sort((a, b) => b.total.compareTo(a.total));
        break;
    }

    return list;
  }

  Color _getRankBadgeColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFD97706); // Amber / Gold
      case 2:
        return const Color(0xFF64748B); // Slate / Silver
      case 3:
        return const Color(0xFFB45309); // Bronze
      default:
        return Colors.grey.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Column(
            key: const Key('category_list_empty_message'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_open_rounded,
                size: 32,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 8),
              Text(
                'Tidak ada kategori ${widget.type == 'expense' ? 'pengeluaran' : 'pemasukan'}.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final items = _filteredAndSortedItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Optional Search & Sort Bar
        if (widget.showSearch || widget.showSorting) ...[
          Row(
            children: [
              if (widget.showSearch)
                Expanded(
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: TextField(
                      key: const Key('category_list_search_input'),
                      controller: _searchController,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Cari kategori...',
                        hintStyle: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onChanged: (val) {
                        setState(() => _searchQuery = val.trim());
                      },
                    ),
                  ),
                ),
              if (widget.showSorting) ...[
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  key: const Key('category_sort_button'),
                  initialValue: _sortBy,
                  tooltip: 'Urutkan Kategori',
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (val) {
                    setState(() => _sortBy = val);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sort_rounded,
                          size: 16,
                          color: AppTheme.textPrimary,
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_drop_down_rounded,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                      ],
                    ),
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'highest',
                      child: Text('Nominal Tertinggi', style: TextStyle(fontSize: 12)),
                    ),
                    const PopupMenuItem(
                      value: 'lowest',
                      child: Text('Nominal Terendah', style: TextStyle(fontSize: 12)),
                    ),
                    const PopupMenuItem(
                      value: 'most_trx',
                      child: Text('Transaksi Terbanyak', style: TextStyle(fontSize: 12)),
                    ),
                    const PopupMenuItem(
                      value: 'name',
                      child: Text('Nama (A - Z)', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
        ],

        // Empty state when search has no matches
        if (items.isEmpty)
          Padding(
            key: const Key('category_list_search_empty_message'),
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Tidak ditemukan kategori untuk "$_searchQuery"',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppTheme.borderSubtle),
            itemBuilder: (context, index) {
              final item = items[index];
              final isSelected = widget.selectedCategory?.toLowerCase() ==
                  item.category.toLowerCase();
              final rank = index + 1;

              return InkWell(
                key: Key('category_chart_item_${item.category}'),
                onTap: () {
                  if (isSelected) {
                    widget.onCategorySelected(null);
                  } else {
                    widget.onCategorySelected(item.category);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (item.color ?? AppTheme.primaryColor).withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(
                            color: (item.color ?? AppTheme.primaryColor)
                                .withValues(alpha: 0.3),
                          )
                        : null,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Rank badge
                          if (widget.showRankBadges) ...[
                            Container(
                              width: 20,
                              height: 20,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _getRankBadgeColor(rank).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '#$rank',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _getRankBadgeColor(rank),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],

                          // Color icon avatar
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: (item.color ?? Colors.grey)
                                  .withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              item.icon ?? Icons.bookmark_border_rounded,
                              size: 17,
                              color: item.color ?? AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Category name & transaction count
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        item.category,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isSelected
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          color: AppTheme.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (item.isCustom) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: Colors.purple.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                              color: Colors.purple.shade200),
                                        ),
                                        child: const Text(
                                          'Kustom',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purple,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.transactionCount} transaksi',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Nominal and Percentage Badges
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                item.formattedTotal,
                                key: Key('category_total_${item.category}'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: widget.type == 'expense'
                                      ? AppTheme.textPrimary
                                      : AppTheme.incomeColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                key: Key('category_pct_${item.category}'),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: (item.color ?? Colors.grey)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item.formattedPercentage,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: item.color ?? AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Visual proportion bar for nominal percentage
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: (item.percentage.clamp(0.0, 100.0)) / 100,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            item.color ?? AppTheme.primaryColor,
                          ),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
