import 'package:flutter/material.dart';
import '../../mock/debt_mock_data.dart';
import '../../models/debt_item.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_format.dart';
import 'widgets/debt_card.dart';
import 'widgets/debt_summary_card.dart';
import 'widgets/jadwal_jatuh_tempo_section.dart';
import 'widgets/pelunasan_dialog.dart';
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
  double get _totalPaidDebt => _debts
      .where((d) => d.isPaid)
      .fold(0.0, (sum, d) => sum + d.totalAmount);

  void _markAsPaid(DebtItem debt) {
    final index = _debts.indexWhere((d) => d.id == debt.id);
    if (index != -1) {
      final previousDebt = _debts[index];
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
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            key: const Key('btn_undo_mark_paid'),
            label: 'Urungkan',
            textColor: Colors.amberAccent,
            onPressed: () {
              setState(() {
                final curIdx = _debts.indexWhere((d) => d.id == debt.id);
                if (curIdx != -1) {
                  _debts[curIdx] = previousDebt;
                }
              });
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Pelunasan "${debt.name}" dibatalkan.'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ),
      );
    }
  }

  void _reopenDebt(DebtItem debt) {
    final index = _debts.indexWhere((d) => d.id == debt.id);
    if (index != -1) {
      setState(() {
        _debts[index] = debt.copyWith(
          status: 'active',
          remainingAmount: debt.totalAmount > 0 ? debt.totalAmount : 100000,
        );
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: Key('snackbar_debt_reopened_${debt.id}'),
          content: Text('Tagihan "${debt.name}" berhasil diaktifkan kembali!'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openPelunasanDialog(DebtItem debt) {
    PelunasanDialog.show(
      context,
      debt: debt,
      onConfirm: (amount, isFull, notes) {
        final index = _debts.indexWhere((d) => d.id == debt.id);
        if (index != -1) {
          final previousDebt = _debts[index];
          final newRemaining = isFull
              ? 0.0
              : (debt.remainingAmount - amount).clamp(0.0, debt.totalAmount);
          final isNowPaid = newRemaining <= 0;

          setState(() {
            _debts[index] = debt.copyWith(
              remainingAmount: newRemaining,
              status: isNowPaid ? 'paid' : 'active',
              notes: notes ?? debt.notes,
            );
          });

          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isNowPaid
                  ? 'Tagihan "${debt.name}" berhasil ditandai lunas!'
                  : 'Pembayaran ${CurrencyFormat.formatRupiah(amount)} untuk "${debt.name}" berhasil dicatat!'),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Urungkan',
                textColor: Colors.amberAccent,
                onPressed: () {
                  setState(() {
                    final curIdx = _debts.indexWhere((d) => d.id == debt.id);
                    if (curIdx != -1) {
                      _debts[curIdx] = previousDebt;
                    }
                  });
                },
              ),
            ),
          );
        }
      },
    );
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

              // 2. Jadwal Jatuh Tempo (Timeline & Penanda Segera)
              JadwalJatuhTempoSection(
                debts: _debts,
                onSelectDebt: (debt) {
                  setState(() {
                    _searchQuery = debt.name;
                    _searchController.text = debt.name;
                  });
                },
                onFilterDueSoon: () {
                  setState(() {
                    _selectedFilter = 'due_soon';
                  });
                },
              ),

              // 3. Search Field
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
              if (_selectedFilter == 'paid') ...[
                _buildDaftarLunasBanner(),
              ],
              if (filtered.isEmpty)
                _buildEmptyState()
              else
                Column(
                  children: filtered
                      .map((debt) => DebtCard(
                            debt: debt,
                            onMarkPaid: () => _markAsPaid(debt),
                            onReopen: () => _reopenDebt(debt),
                            onTap: () => _openPelunasanDialog(debt),
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

  Widget _buildDaftarLunasBanner() {
    return Container(
      key: const Key('daftar_lunas_summary_banner'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_rounded,
              size: 20,
              color: Color(0xFF047857),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daftar Lunas: $_paidCount Tagihan Selesai',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF065F46),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Total ${CurrencyFormat.formatRupiah(_totalPaidDebt)} hutang & paylater telah berhasil dilunasi!',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF047857),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_selectedFilter == 'paid') {
      return Container(
        key: const Key('empty_paid_debts'),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_outlined,
                size: 36,
                color: Color(0xFF047857),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Belum Ada Catatan Hutang Lunas',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tagihan yang sudah dilunasi akan tercatat rapi di sini sebagai arsip.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

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
