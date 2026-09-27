import 'package:flutter/material.dart';
import '../../mock/rekap_mock_data.dart';
import '../../models/monthly_rekap_data.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import 'widgets/category_breakdown_section.dart';
import 'widgets/month_navigator_bar.dart';
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
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity != null) {
                  // Swipe Left -> Next Month (newer)
                  if (details.primaryVelocity! < -250 && _canGoNext) {
                    _nextMonth();
                  }
                  // Swipe Right -> Previous Month (older)
                  else if (details.primaryVelocity! > 250 && _canGoPrevious) {
                    _previousMonth();
                  }
                }
              },
              child: SingleChildScrollView(
                key: const Key('rekap_body_scroll_view'),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Month Navigator Bar with in-page month switcher & bottom sheet picker
                    MonthNavigatorBar(
                      selectedMonth: _currentMonth,
                      availableMonths: RekapMockData.availableMonths,
                      onMonthChanged: (newMonth) {
                        setState(() {
                          _currentMonth = newMonth;
                          _selectedCategoryFilter = null;
                        });
                      },
                    ),

                    // Financial Summary Banner (Kartu Ringkasan Pemasukan dan Pengeluaran)
                    RekapSummaryCard(
                      data: rekapData,
                      onIncomeTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Total Pemasukan: ${rekapData.formattedTotalIncome} (${rekapData.incomeTransactionsCount} transaksi)',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      onExpenseTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Total Pengeluaran: ${rekapData.formattedTotalExpense} (${rekapData.expenseTransactionsCount} transaksi)',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),

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
          ),
        );
      },
    );
  }
}
