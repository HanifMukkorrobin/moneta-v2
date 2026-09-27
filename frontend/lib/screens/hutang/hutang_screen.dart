import 'package:flutter/material.dart';
import '../../mock/debt_mock_data.dart';
import '../../models/debt_item.dart';
import '../../theme/app_theme.dart';
import 'widgets/debt_card.dart';
import 'widgets/debt_summary_card.dart';
import 'widgets/tambah_hutang_bottom_sheet.dart';

class HutangScreen extends StatefulWidget {
  final List<DebtItem>? initialDebts;

  const HutangScreen({
    super.key,
    this.initialDebts,
  });

  @override
  State<HutangScreen> createState() => _HutangScreenState();
}

class _HutangScreenState extends State<HutangScreen> {
  late List<DebtItem> _debts;
  String _selectedFilter = 'all'; // 'all', 'active', 'due_soon', 'paid'
  String _searchQuery = '';
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _debts = List.of(widget.initialDebts ?? DebtMockData.getInitialDebts());
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DebtItem> get _filteredDebts {
    return _debts.where((debt) {
      if (_selectedFilter == 'active' && debt.isPaid) return false;
      if (_selectedFilter == 'paid' && !debt.isPaid) return false;
      if (_selectedFilter == 'due_soon' && !debt.isDueSoon) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = debt.name.toLowerCase().contains(q);
        final matchNotes = debt.notes?.toLowerCase().contains(q) ?? false;
        final matchType = debt.type.label.toLowerCase().contains(q);
        if (!matchName && !matchNotes && !matchType) return false;
      }

      return true;
    }).toList();
  }

  int get _activeCount => _debts.where((d) => !d.isPaid).length;
  int get _paidCount => _debts.where((d) => d.isPaid).length;
  int get _dueSoonCount => _debts.where((d) => d.isDueSoon).length;

  void _markAsPaid(DebtItem debt) {
    final index = _debts.indexWhere((d) => d.id == debt.id);
    if (index != -1) {
      setState(() {
        _debts[index] = debt.copyWith(
          status: 'paid',
          remainingAmount: 0,
        );
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tagihan "${debt.name}" berhasil ditandai lunas!'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedFilter = 'all';
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _refreshDebts() {
    setState(() {
      _debts = List.of(widget.initialDebts ?? DebtMockData.getInitialDebts());
      _selectedFilter = 'all';
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Daftar hutang berhasil diperbarui.'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openAddDebtForm() {
    TambahHutangBottomSheet.show(
      context,
      onAdd: (newDebt) {
        setState(() {
          _debts.insert(0, newDebt);
        });

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: const Key('snackbar_debt_added'),
            content: Text('Hutang "${newDebt.name}" berhasil ditambahkan!'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredDebts;

    return Scaffold(
      key: const Key('hutang_screen'),
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Catatan Hutang & Paylater',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        actions: [
          IconButton(
            key: const Key('btn_add_debt_appbar'),
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Tambah Hutang',
            onPressed: _openAddDebtForm,
          ),
          IconButton(
            key: const Key('btn_refresh_debts'),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Perbarui Data',
            onPressed: _refreshDebts,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshDebts(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Ringkasan Hutang
              DebtSummaryCard(
                debts: _debts,
                onFilterDueSoon: () {
                  setState(() {
                    _selectedFilter = 'due_soon';
                  });
                },
              ),

              // 2. Search Field
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: TextField(
                  key: const Key('debt_search_input'),
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari hutang atau paylater...',
                    hintStyle: const TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.textSecondary,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
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
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppTheme.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppTheme.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppTheme.primaryColor),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                ),
              ),

              // 3. Filter Chips
              _buildFilterChips(),

              const SizedBox(height: 6),

              // 4. Daftar Tagihan
              if (filtered.isEmpty)
                _buildEmptyState()
              else
                Column(
                  children: filtered
                      .map((debt) => DebtCard(
                            debt: debt,
                            onMarkPaid: () => _markAsPaid(debt),
                          ))
                      .toList(),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('btn_add_debt_fab'),
        onPressed: _openAddDebtForm,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'Tambah Hutang',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'id': 'all', 'label': 'Semua', 'count': _debts.length, 'key': 'filter_debt_all'},
      {'id': 'active', 'label': 'Aktif', 'count': _activeCount, 'key': 'filter_debt_active'},
      {
        'id': 'due_soon',
        'label': 'Jatuh Tempo Dekat',
        'count': _dueSoonCount,
        'key': 'filter_debt_due_soon'
      },
      {'id': 'paid', 'label': 'Lunas', 'count': _paidCount, 'key': 'filter_debt_paid'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              key: Key(f['key'] as String),
              label: Text(
                '${f['label']} (${f['count']})',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              selected: isSelected,
              selectedColor: AppTheme.primaryColor,
              backgroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              showCheckmark: false,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.borderSubtle,
                ),
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedFilter = f['id'] as String;
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      key: const Key('debt_empty_state'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              size: 36,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Tidak ada catatan hutang ditemukan',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Coba ganti filter status atau ubah kata kunci pencarian.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            key: const Key('btn_reset_debt_filters'),
            onPressed: _resetFilters,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Reset Filter'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
