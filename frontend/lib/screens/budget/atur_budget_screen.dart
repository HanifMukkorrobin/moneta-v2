import 'package:flutter/material.dart';
import '../../mock/budget_mock_data.dart';
import '../../models/budget_item.dart';
import '../../theme/app_theme.dart';
import 'widgets/budget_allocation_buckets_section.dart';
import 'widgets/budget_header_summary_card.dart';
import 'widgets/category_budget_list_section.dart';

class AturBudgetScreen extends StatefulWidget {
  final String initialMonth;

  const AturBudgetScreen({
    super.key,
    this.initialMonth = '2026-09',
  });

  @override
  State<AturBudgetScreen> createState() => _AturBudgetScreenState();
}

class _AturBudgetScreenState extends State<AturBudgetScreen> {
  late String _selectedMonth;
  late MonthlyBudgetSummary _budgetSummary;

  final List<String> _availableMonths = const [
    '2026-09',
    '2026-08',
    '2026-07',
  ];

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.initialMonth;
    _loadBudget();
  }

  void _loadBudget() {
    _budgetSummary = BudgetMockData.getMonthlyBudget(month: _selectedMonth);
  }

  void _onMonthSelected(String month) {
    setState(() {
      _selectedMonth = month;
      _loadBudget();
    });
  }

  String _getMonthLabel(String monthKey) {
    switch (monthKey) {
      case '2026-09':
        return 'September 2026';
      case '2026-08':
        return 'Agustus 2026';
      case '2026-07':
        return 'Juli 2026';
      default:
        return monthKey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _budgetSummary;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Atur Budget'),
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textPrimary),
            tooltip: 'Segarkan Budget',
            onPressed: () {
              setState(() {
                _loadBudget();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Data budget berhasil disegarkan.'),
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
          setState(() {
            _loadBudget();
          });
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month Selector Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getMonthLabel(_selectedMonth),
                          key: const Key('current_budget_month_label'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        key: const Key('budget_month_dropdown'),
                        value: _availableMonths.contains(_selectedMonth)
                            ? _selectedMonth
                            : _availableMonths.first,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primaryColor),
                        items: _availableMonths.map((m) {
                          return DropdownMenuItem<String>(
                            value: m,
                            child: Text(
                              _getMonthLabel(m),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) _onMonthSelected(val);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Empty State or Content
              if (summary.totalBudget <= 0)
                Container(
                  key: const Key('budget_empty_banner'),
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Belum Ada Budget Bulanan',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tentukan batas budget pengeluaran bulanan Anda untuk mengontrol keuangan lebih baik.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          key: const Key('create_budget_empty_button'),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Buat Budget Sekarang'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _budgetSummary = MonthlyBudgetSummary(
                                month: _selectedMonth,
                                monthLabel: _getMonthLabel(_selectedMonth),
                                totalBudget: BudgetMockData.defaultTotalBudget,
                                totalSpent: 0,
                                needsPercentage: BudgetMockData.defaultNeedsPct,
                                savingsPercentage: BudgetMockData.defaultSavingsPct,
                                funPercentage: BudgetMockData.defaultFunPct,
                                buckets: BudgetMockData.getDefaultBuckets(),
                                categoryBudgets: BudgetMockData.getDefaultCategoryBudgets(),
                              );
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // Main Header Summary Card
                BudgetHeaderSummaryCard(
                  summary: summary,
                  onEditBudget: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Fitur ubah batas budget akan segera dibuka.'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),

                // 3-Bucket Allocation Section
                BudgetAllocationBucketsSection(
                  buckets: summary.buckets,
                  onAdjustPercentages: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Fitur kustomisasi persentase 50/30/20 akan segera dibuka.'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),

                // Category-level Budgets List
                CategoryBudgetListSection(
                  items: summary.categoryBudgets,
                  onAddCategoryBudget: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Fitur tambah budget per kategori akan segera dibuka.'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  onCategoryTap: (item) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${item.categoryName}: Sisa Rp ${item.formattedRemaining}'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
