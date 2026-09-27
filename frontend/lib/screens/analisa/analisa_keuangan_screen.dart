import 'package:flutter/material.dart';
import '../../mock/ai_insight_mock_data.dart';
import '../../mock/daily_spending_mock_data.dart';
import '../../models/ai_insight_item.dart';
import '../../models/daily_spending_item.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../chat/widgets/financial_analysis_card.dart';
import 'widgets/avg_daily_spend_card.dart';
import 'widgets/money_depletion_projection_card.dart';

class AnalisaKeuanganScreen extends StatefulWidget {
  final DailySpendingAnalysis? initialAnalysis;
  final AiInsightItem? initialInsight;

  const AnalisaKeuanganScreen({
    super.key,
    this.initialAnalysis,
    this.initialInsight,
  });

  @override
  State<AnalisaKeuanganScreen> createState() => _AnalisaKeuanganScreenState();
}

class _AnalisaKeuanganScreenState extends State<AnalisaKeuanganScreen> {
  late DailySpendingAnalysis _spendingAnalysis;

  @override
  void initState() {
    super.initState();
    _spendingAnalysis =
        widget.initialAnalysis ?? DailySpendingMockData.getDefaultDailyAnalysis();
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

  void _toggleAnalysisPreset() {
    setState(() {
      if (_spendingAnalysis.avgDailySpend < 100000) {
        _spendingAnalysis = DailySpendingMockData.getHighSpendingAnalysis();
      } else {
        _spendingAnalysis = DailySpendingMockData.getDefaultDailyAnalysis();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Data simulasi diganti: Rata-rata ${_spendingAnalysis.formattedAvgDailySpend}/hari',
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppState.instance;
    final insight = widget.initialInsight ?? appState.aiInsight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analisa & Saran AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Ganti Data Simulasi',
            onPressed: _toggleAnalysisPreset,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reset Analisa',
            onPressed: () {
              setState(() {
                _spendingAnalysis =
                    DailySpendingMockData.getDefaultDailyAnalysis();
              });
              appState.resetToDefault();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        key: const Key('analisa_body_scroll_view'),
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // AI Analysis Overview Card
            FinancialAnalysisCard(
              insight: insight,
              initialExpanded: true,
            ),

            // Perkiraan Uang Bertahan dan Tanggal Habis Card
            MoneyDepletionProjectionCard(
              insight: insight,
            ),

            // Rata-rata Pengeluaran Harian Card
            AvgDailySpendCard(
              analysis: _spendingAnalysis,
            ),

            // AI Insight Recommendation Card
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lightbulb_outline_rounded,
                          color: AppTheme.primaryColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Rekomendasi Hemat AI',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _TipItem(
                    text:
                        'Pengeluaran di akhir pekan rata-rata 85% lebih tinggi daripada hari kerja. Tetapkan batas jajan khusus Sabtu-Minggu.',
                  ),
                  const SizedBox(height: 8),
                  const _TipItem(
                    text:
                        'Kategori Makan & Minuman mendominasi 48% pengeluaran harian. Membawa bekal 2x seminggu dapat menghemat hingga Rp 150.000/pekan.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipItem extends StatelessWidget {
  final String text;

  const _TipItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Icon(
            Icons.check_circle_outline_rounded,
            size: 14,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
