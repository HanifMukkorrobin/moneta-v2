import 'package:flutter/material.dart';
import '../../models/monthly_rekap_data.dart';
import '../../services/api/moneta_api_client.dart';
import '../../services/api/rekap_api_service.dart';
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
  MonthlyRekapData? _rekapData;

  @override
  void initState() {
    super.initState();
    _currentMonth = widget.initialMonth;
    _syncRekapFromBackend();
  }

  Future<void> _syncRekapFromBackend() async {
    try {
      final data = await RekapApiService.instance.getMonthlyRecap(_currentMonth);
      if (mounted) {
        setState(() {
          _rekapData = data;
        });
      }
    } catch (_) {}
  }

  void _previousMonth() {
    final idx = MonthlyRekapData.availableMonths.indexOf(_currentMonth);
    if (idx != -1 && idx < MonthlyRekapData.availableMonths.length - 1) {
      setState(() {
        _currentMonth = MonthlyRekapData.availableMonths[idx + 1];
        _selectedCategoryFilter = null;
        _rekapData = null;
      });
      _syncRekapFromBackend();
    }
  }

  void _nextMonth() {
    final idx = MonthlyRekapData.availableMonths.indexOf(_currentMonth);
    if (idx > 0) {
      setState(() {
        _currentMonth = MonthlyRekapData.availableMonths[idx - 1];
        _selectedCategoryFilter = null;
        _rekapData = null;
      });
      _syncRekapFromBackend();
    }
  }

  bool get _canGoNext =>
      MonthlyRekapData.availableMonths.indexOf(_currentMonth) > 0;

  bool get _canGoPrevious =>
      MonthlyRekapData.availableMonths.indexOf(_currentMonth) <
      MonthlyRekapData.availableMonths.length - 1;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final hasBackendSession = MonetaApiClient.instance.authToken != null &&
            MonetaApiClient.instance.authToken!.isNotEmpty;
        final rekapData = _rekapData ??
            MonthlyRekapData.getMonthlyRekap(
              month: _currentMonth,
              activeTransactions: AppState.instance.allTransactions,
              includeBaseline: !hasBackendSession,
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
                  _syncRekapFromBackend();
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
              await _syncRekapFromBackend();
              if (mounted) setState(() {});
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
                      availableMonths: MonthlyRekapData.availableMonths,
                      onMonthChanged: (newMonth) {
                        setState(() {
                          _currentMonth = newMonth;
                          _selectedCategoryFilter = null;
                        });
                        _syncRekapFromBackend();
                      },
                    ),

                    // Top Empty State Banner if no transactions for selected month
                    if (rekapData.transactions.isEmpty)
                      Container(
                        key: const Key('rekap_month_empty_banner'),
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.calendar_month_outlined,
                                size: 22,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Belum Ada Catatan Keuangan',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Belum ada transaksi tercatat di ${rekapData.monthLabel}. Semua bagian rekap di bawah ini akan terisi otomatis saat Anda mulai mencatat.',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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
                    RekapComparisonCard(
                      data: rekapData,
                      showEmptyPlaceholder: true,
                    ),

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
                      monthLabel: rekapData.monthLabel,
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
