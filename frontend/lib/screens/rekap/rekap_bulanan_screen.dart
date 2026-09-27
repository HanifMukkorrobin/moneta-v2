import 'package:flutter/material.dart';
import '../../mock/rekap_mock_data.dart';
import '../../models/monthly_rekap_data.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import 'widgets/category_breakdown_section.dart';
import 'widgets/monthly_transaction_list_section.dart';
import 'widgets/rekap_comparison_card.dart';
import 'widgets/rekap_summary_card.dart';

class RekapBulananScreen extends StatefulWidget {
  final String initialMonth;

  const RekapBulananScreen({
    super.key,
    this.initialMonth = '2026-09',
  });

  @override
  State<RekapBulananScreen> createState() => _RekapBulananScreenState();
}

class _RekapBulananScreenState extends State<RekapBulananScreen> {
  late String _currentMonth;
  String? _selectedCategoryFilter;

  @override
  void initState() {
    super.initState();
    _currentMonth = widget.initialMonth;
  }

  void _previousMonth() {
    final idx = RekapMockData.availableMonths.indexOf(_currentMonth);
    if (idx != -1 && idx < RekapMockData.availableMonths.length - 1) {
      setState(() {
        _currentMonth = RekapMockData.availableMonths[idx + 1];
        _selectedCategoryFilter = null;
      });
    }
  }

  void _nextMonth() {
    final idx = RekapMockData.availableMonths.indexOf(_currentMonth);
    if (idx > 0) {
      setState(() {
        _currentMonth = RekapMockData.availableMonths[idx - 1];
        _selectedCategoryFilter = null;
      });
    }
  }

  bool get _canGoNext =>
      RekapMockData.availableMonths.indexOf(_currentMonth) > 0;

  bool get _canGoPrevious =>
      RekapMockData.availableMonths.indexOf(_currentMonth) <
      RekapMockData.availableMonths.length - 1;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final rekapData = RekapMockData.getMonthlyRekap(
          month: _currentMonth,
          activeTransactions: AppState.instance.allTransactions,
        );

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(
            title: const Text('Rekap Bulanan'),
            elevation: 0,
            backgroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.textPrimary),
                tooltip: 'Segarkan Rekap',
                onPressed: () {
                  setState(() {
                    _selectedCategoryFilter = null;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Rekap bulanan berhasil diperbarui.'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
          body: RefreshIndicator(
            color: AppTheme.primaryColor,
            onRefresh: () async {
              setState(() {});
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Month Navigator Bar
                  _buildMonthNavigator(),

                  // Quick Month Chips
                  _buildQuickMonthChips(),

                  // Financial Summary Banner
                  RekapSummaryCard(data: rekapData),

                  // Month-over-Month Comparison
                  RekapComparisonCard(data: rekapData),

                  // Category Breakdown & Chart Section
                  CategoryBreakdownSection(
                    data: rekapData,
                    selectedCategory: _selectedCategoryFilter,
                    onCategoryFilter: (cat) {
                      setState(() {
                        _selectedCategoryFilter = cat;
                      });
                    },
                  ),

                  // Transactions List for the month
                  MonthlyTransactionListSection(
                    transactions: rekapData.transactions,
                    activeCategoryFilter: _selectedCategoryFilter,
                    onCategoryFilterChanged: (cat) {
                      setState(() {
                        _selectedCategoryFilter = cat;
                      });
                    },
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMonthNavigator() {
    final label = RekapMockData.getMonthLabel(_currentMonth);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            color: _canGoPrevious ? AppTheme.primaryColor : Colors.grey.shade300,
            onPressed: _canGoPrevious ? _previousMonth : null,
            tooltip: 'Bulan Sebelumnya',
          ),
          Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                size: 18,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            color: _canGoNext ? AppTheme.primaryColor : Colors.grey.shade300,
            onPressed: _canGoNext ? _nextMonth : null,
            tooltip: 'Bulan Berikutnya',
          ),
        ],
      ),
    );
  }

  Widget _buildQuickMonthChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: RekapMockData.availableMonths.map((m) {
          final isSelected = m == _currentMonth;
          final label = RekapMockData.getMonthLabel(m);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
              ),
              side: BorderSide(
                color: isSelected ? AppTheme.primaryColor : AppTheme.borderSubtle,
                width: isSelected ? 1.4 : 1.0,
              ),
              onSelected: (val) {
                if (val) {
                  setState(() {
                    _currentMonth = m;
                    _selectedCategoryFilter = null;
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}
