import 'package:flutter/material.dart';
import '../../models/saving_tip_item.dart';
import '../../services/api/daily_tips_api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_format.dart';

class RiwayatTipsHematScreen extends StatefulWidget {
  final List<SavingTipItem>? initialTips;
  final Function(SavingTipItem, bool)? onToggleTip;

  const RiwayatTipsHematScreen({
    super.key,
    this.initialTips,
    this.onToggleTip,
  });

  @override
  State<RiwayatTipsHematScreen> createState() => _RiwayatTipsHematScreenState();
}

class _RiwayatTipsHematScreenState extends State<RiwayatTipsHematScreen> {
  late List<SavingTipItem> _tips;
  late TextEditingController _searchController;
  String _selectedStatus = 'Semua'; // 'Semua', 'Diterapkan', 'Belum Diterapkan'
  String _selectedCategory = 'Semua';
  String _searchQuery = '';

  final List<String> _categories = [
    'Semua',
    'Makan & Minuman',
    'Belanja',
    'Tagihan & Utilitas',
    'Transportasi',
  ];

  @override
  void initState() {
    super.initState();
    _tips = List.of(widget.initialTips ?? SavingTipItem.getHistoryTips());
    _searchController = TextEditingController();
    if (widget.initialTips == null) {
      _syncHistoryFromBackend();
    }
  }

  Future<void> _syncHistoryFromBackend() async {
    try {
      final tips = await DailyTipsApiService.instance.getTipsHistory();
      if (mounted && tips.isNotEmpty) {
        setState(() {
          _tips = tips;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SavingTipItem> get _filteredTips {
    return _tips.where((tip) {
      // Filter status
      if (_selectedStatus == 'Diterapkan' && !tip.isApplied) return false;
      if (_selectedStatus == 'Belum Diterapkan' && tip.isApplied) return false;

      // Filter kategori
      if (_selectedCategory != 'Semua' && tip.category != _selectedCategory) {
        return false;
      }

      // Filter search
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchTitle = tip.title.toLowerCase().contains(query);
        final matchDesc = tip.description.toLowerCase().contains(query);
        final matchCat = tip.category.toLowerCase().contains(query);
        if (!matchTitle && !matchDesc && !matchCat) return false;
      }

      return true;
    }).toList();
  }

  int get _appliedCount => _tips.where((t) => t.isApplied).length;
  int get _unappliedCount => _tips.where((t) => !t.isApplied).length;

  double get _totalAppliedSavings {
    double total = 0;
    for (var tip in _tips) {
      if (tip.isApplied) {
        total += tip.potentialSaving;
      }
    }
    return total;
  }

  double get _totalPotentialSavingsAll {
    double total = 0;
    for (var tip in _tips) {
      total += tip.potentialSaving;
    }
    return total;
  }

  void _toggleApply(SavingTipItem tip) {
    final newStatus = !tip.isApplied;
    final index = _tips.indexWhere((t) => t.id == tip.id);
    if (index != -1) {
      setState(() {
        _tips[index] = tip.copyWith(
          isApplied: newStatus,
          appliedAt: newStatus ? DateTime.now() : null,
        );
      });
      widget.onToggleTip?.call(_tips[index], newStatus);
      DailyTipsApiService.instance
          .toggleTipStatus(tip.id, isApplied: newStatus)
          .catchError((_) => _tips[index]);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus
                ? 'Tip "${tip.title}" ditandai sebagai diterapkan.'
                : 'Tip "${tip.title}" dibatalkan dari daftar penerapan.',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedStatus = 'Semua';
      _selectedCategory = 'Semua';
      _searchQuery = '';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTips;
    final successRate = _tips.isEmpty
        ? 0
        : ((_appliedCount / _tips.length) * 100).toInt();

    return Scaffold(
      key: const Key('riwayat_tips_hemat_screen'),
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Riwayat Tips Hemat',
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
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Ringkasan Akumulasi & Pencapaian
            _buildSummaryBanner(successRate),

            // 2. Search Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                key: const Key('riwayat_tips_search_input'),
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari riwayat tips hemat...',
                  hintStyle: const TextStyle(
                    fontSize: 13,
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
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim();
                  });
                },
              ),
            ),

            // 3. Status Filter Tabs
            _buildStatusTabs(),

            // 4. Category Filter Chips
            _buildCategoryChips(),

            const SizedBox(height: 8),

            // 5. Tips List / Empty State
            if (filtered.isEmpty)
              _buildEmptyState()
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: filtered.map((tip) => _buildTipCard(tip)).toList(),
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBanner(int successRate) {
    return Container(
      key: const Key('riwayat_tips_summary_card'),
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.savings_rounded,
                      color: Color(0xFF047857),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Akumulasi Hemat Terlaksana',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                key: const Key('riwayat_success_badge'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$successRate% Diterapkan',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF047857),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            CurrencyFormat.formatRupiah(_totalAppliedSavings),
            key: const Key('total_applied_savings_amount'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF047857),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '$_appliedCount dari ${_tips.length} tips berhasil dijalankan',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                'Potensi total: ${CurrencyFormat.formatRupiah(_totalPotentialSavingsAll)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTabs() {
    final statusList = [
      {'label': 'Semua', 'count': _tips.length, 'key': 'filter_status_semua'},
      {
        'label': 'Diterapkan',
        'count': _appliedCount,
        'key': 'filter_status_diterapkan'
      },
      {
        'label': 'Belum Diterapkan',
        'count': _unappliedCount,
        'key': 'filter_status_belum'
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: statusList.map((item) {
          final isSelected = _selectedStatus == item['label'];
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                key: Key(item['key'] as String),
                onTap: () {
                  setState(() {
                    _selectedStatus = item['label'] as String;
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryColor : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.borderSubtle,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${item['label']} (${item['count']})',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: _categories.map((cat) {
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              key: Key('filter_category_$cat'),
              label: Text(
                cat,
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
                    _selectedCategory = cat;
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTipCard(SavingTipItem tip) {
    final isApplied = tip.isApplied;

    return Container(
      key: Key('riwayat_tip_item_${tip.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isApplied
            ? const Color(0xFF10B981).withValues(alpha: 0.04)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isApplied
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : AppTheme.borderSubtle,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Category, Date & Impact
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isApplied
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isApplied ? Icons.check_circle_rounded : tip.icon,
                  size: 16,
                  color: isApplied
                      ? const Color(0xFF10B981)
                      : AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              if (tip.date != null) ...[
                Container(
                  key: Key('riwayat_tip_date_${tip.id}'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Text(
                    tip.date!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tip.category,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: tip.impactColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Hemat ${tip.formattedPotentialSaving}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: tip.impactColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Title
          Text(
            tip.title,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: isApplied
                  ? const Color(0xFF047857)
                  : AppTheme.textPrimary,
              decoration: isApplied ? TextDecoration.lineThrough : null,
            ),
          ),
          const SizedBox(height: 6),
          // Description
          Text(
            tip.description,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppTheme.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          // Action Button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                key: Key('btn_toggle_riwayat_tip_${tip.id}'),
                onTap: () => _toggleApply(tip),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isApplied
                        ? const Color(0xFF10B981)
                        : AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isApplied
                            ? Icons.check_rounded
                            : Icons.add_task_rounded,
                        size: 14,
                        color: isApplied ? Colors.white : AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isApplied ? 'Diterapkan' : 'Terapkan Tip',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color:
                              isApplied ? Colors.white : AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      key: const Key('riwayat_tips_empty_state'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
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
              Icons.filter_list_off_rounded,
              size: 36,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Tidak ada riwayat tips ditemukan',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Coba ubah kata kunci pencarian atau ganti filter kategori/status.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            key: const Key('btn_reset_filters'),
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
