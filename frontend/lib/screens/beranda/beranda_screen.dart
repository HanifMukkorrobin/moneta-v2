import 'package:flutter/material.dart';
import '../../mock/ai_insight_mock_data.dart';
import '../../models/ai_insight_item.dart';
import '../../models/transaction_item.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../analisa/analisa_keuangan_screen.dart';
import '../budget/atur_budget_screen.dart';
import '../chat/widgets/manual_input_sheet.dart';
import '../rekap/rekap_bulanan_screen.dart';
import 'riwayat_tips_hemat_screen.dart';
import 'widgets/daily_advice_card.dart';
import 'widgets/daily_saving_tips_card.dart';
import 'widgets/safe_spending_limit_card.dart';

class BerandaScreen extends StatefulWidget {
  final AiInsightItem? initialInsight;
  final VoidCallback? onNavigateToChat;
  final VoidCallback? onNavigateToRekap;
  final VoidCallback? onNavigateToBudget;
  final VoidCallback? onNavigateToAnalisa;

  const BerandaScreen({
    super.key,
    this.initialInsight,
    this.onNavigateToChat,
    this.onNavigateToRekap,
    this.onNavigateToBudget,
    this.onNavigateToAnalisa,
  });

  @override
  State<BerandaScreen> createState() => _BerandaScreenState();
}

class _BerandaScreenState extends State<BerandaScreen> {
  AiInsightItem? _simulatedInsight;

  @override
  void initState() {
    super.initState();
    _simulatedInsight = widget.initialInsight;
    AppState.instance.addListener(_onStateChange);
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  void _cycleMockPreset() {
    setState(() {
      final current = _simulatedInsight ?? AppState.instance.aiInsight;
      if (current.warnLevel == AiWarnLevel.normal) {
        _simulatedInsight = AiInsightMockData.getWarningInsight();
      } else if (current.warnLevel == AiWarnLevel.warning) {
        _simulatedInsight = AiInsightMockData.getCriticalInsight();
      } else {
        _simulatedInsight = AiInsightMockData.getDefaultInsight();
      }
    });

    final active = _simulatedInsight!;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Simulasi Saran AI: ${active.warnLevel.label} (${active.formattedRecommendedDailyBudget}/hari)',
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static const _dayNames = [
    'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
  ];
  static const _monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  String _formatIndonesianDate(DateTime date) {
    final dayName = _dayNames[(date.weekday - 1) % 7];
    final monthName = _monthNames[date.month - 1];
    return '$dayName, ${date.day} $monthName ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppState.instance;
    final insight = _simulatedInsight ?? appState.aiInsight;
    final now = DateTime.now();
    final recentTransactions = appState.confirmedTransactions.take(3).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beranda'),
        actions: [
          IconButton(
            key: const Key('beranda_preset_toggle_button'),
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Ganti Simulasi Saran AI',
            onPressed: _cycleMockPreset,
          ),
          IconButton(
            key: const Key('beranda_riwayat_tips_button'),
            icon: const Icon(Icons.history_edu_rounded),
            tooltip: 'Riwayat Tips Hemat',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RiwayatTipsHematScreen(),
                ),
              );
            },
          ),
          IconButton(
            key: const Key('beranda_refresh_button'),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Perbarui Saran',
            onPressed: () {
              setState(() {
                _simulatedInsight = null;
              });
              appState.recalculateAnalysis();
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Saran harian dan analisa berhasil diperbarui.'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _simulatedInsight = null;
          });
          appState.recalculateAnalysis();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Greeting & Date Header
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withValues(alpha: 0.08),
                      AppTheme.primaryColor.withValues(alpha: 0.02),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor:
                          AppTheme.primaryColor.withValues(alpha: 0.15),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppTheme.primaryColor,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selamat Datang di Moneta ✨',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatIndonesianDate(now),
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.wb_sunny_rounded,
                            size: 14,
                            color: Colors.amber,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Pagi',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Kartu Saran Harian AI
              DailyAdviceCard(
                insight: insight,
                onDetailedAnalysis: () {
                  if (widget.onNavigateToAnalisa != null) {
                    widget.onNavigateToAnalisa!();
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AnalisaKeuanganScreen(
                          initialInsight: insight,
                        ),
                      ),
                    );
                  }
                },
                onApplyAdvice: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Target harian ${insight.formattedRecommendedDailyBudget} telah diterapkan.',
                      ),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),

              // Kartu Batas Aman Belanja + Penanda Rendah
              SafeSpendingLimitCard(
                insight: insight,
                todaySpent: appState.todayTotalExpense,
              ),

              // Tips Hemat Harian (Mock)
              const DailySavingTipsCard(),

              // Overview Finansial Bulan Berjalan
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Ringkasan Finansial',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 18,
                          color: AppTheme.primaryColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _BerandaStatTile(
                            title: 'Sisa Saldo',
                            value: insight.formattedRemainingBalance,
                            subtitle:
                                'dari ${insight.formattedTotalMonthlyBudget}',
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _BerandaStatTile(
                            title: 'Daya Tahan',
                            value: '${insight.estimatedDaysLeft} Hari',
                            subtitle: insight.runsOutBeforeEndOfMonth
                                ? 'Perlu Hemat'
                                : 'Saldo Aman',
                            color: insight.runsOutBeforeEndOfMonth
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Quick Action Shortcuts
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Aksi Cepat',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _QuickActionBtn(
                          key: const Key('btn_quick_chat_input'),
                          icon: Icons.chat_bubble_outline_rounded,
                          label: 'Catat Chat',
                          color: Colors.blue,
                          onTap: () {
                            if (widget.onNavigateToChat != null) {
                              widget.onNavigateToChat!();
                            } else {
                              Navigator.maybePop(context);
                            }
                          },
                        ),
                        _QuickActionBtn(
                          key: const Key('btn_quick_manual_input'),
                          icon: Icons.edit_note_rounded,
                          label: 'Input Manual',
                          color: Colors.orange,
                          onTap: () {
                            ManualInputSheet.show(
                              context,
                              onSave: (tx) {
                                AppState.instance.addManualTransaction(tx);
                              },
                            );
                          },
                        ),
                        _QuickActionBtn(
                          key: const Key('btn_quick_rekap'),
                          icon: Icons.pie_chart_outline_rounded,
                          label: 'Rekap',
                          color: Colors.purple,
                          onTap: () {
                            if (widget.onNavigateToRekap != null) {
                              widget.onNavigateToRekap!();
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RekapBulananScreen(),
                                ),
                              );
                            }
                          },
                        ),
                        _QuickActionBtn(
                          key: const Key('btn_quick_budget'),
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Budget',
                          color: Colors.teal,
                          onTap: () {
                            if (widget.onNavigateToBudget != null) {
                              widget.onNavigateToBudget!();
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AturBudgetScreen(),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Catatan Terakhir Preview
              if (recentTransactions.isNotEmpty) ...[
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Transaksi Terakhir',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...recentTransactions.map(
                        (tx) => _RecentTxRow(transaction: tx),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BerandaStatTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _BerandaStatTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionBtn({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTxRow extends StatelessWidget {
  final TransactionItem transaction;

  const _RecentTxRow({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.isExpense;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (isExpense ? AppTheme.expenseColor : AppTheme.incomeColor)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isExpense ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              size: 14,
              color: isExpense ? AppTheme.expenseColor : AppTheme.incomeColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.note,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  transaction.category,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isExpense ? '-' : '+'}${transaction.formattedAmount}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isExpense ? AppTheme.expenseColor : AppTheme.incomeColor,
            ),
          ),
        ],
      ),
    );
  }
}
