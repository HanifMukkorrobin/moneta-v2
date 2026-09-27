import '../models/ai_insight_item.dart';

class AiInsightMockData {
  static AiInsightItem getDefaultInsight() {
    return AiInsightItem(
      id: 'insight_default',
      date: DateTime.now(),
      avgDailySpend: 78500,
      estimatedDaysLeft: 18,
      recommendedDailyBudget: 65000,
      dailyAdvice:
          'Pertahankan ritme belanja Anda. Batasi pos non-esensial maksimal Rp 65.000 hari ini agar saldo aman sampai akhir bulan.',
      warnLevel: AiWarnLevel.normal,
      totalMonthlyBudget: 6000000,
      totalSpent: 2850000,
      remainingBalance: 3150000,
    );
  }

  static AiInsightItem getWarningInsight() {
    return AiInsightItem(
      id: 'insight_warning',
      date: DateTime.now(),
      avgDailySpend: 135000,
      estimatedDaysLeft: 9,
      recommendedDailyBudget: 42000,
      dailyAdvice:
          'Perhatian: Pengeluaran 3 hari terakhir meningkat 40%! Batasi jajan dan hiburan maksimal Rp 42.000 hari ini.',
      warnLevel: AiWarnLevel.warning,
      totalMonthlyBudget: 6000000,
      totalSpent: 4800000,
      remainingBalance: 1200000,
    );
  }

  static AiInsightItem getCriticalInsight() {
    return AiInsightItem(
      id: 'insight_critical',
      date: DateTime.now(),
      avgDailySpend: 215000,
      estimatedDaysLeft: 3,
      recommendedDailyBudget: 15000,
      dailyAdvice:
          'Kritis: Sisa saldo menipis lebih cepat dari jadwal. Stop pengeluaran sekunder dan fokus hanya pada kebutuhan makan pokok.',
      warnLevel: AiWarnLevel.critical,
      totalMonthlyBudget: 6000000,
      totalSpent: 5650000,
      remainingBalance: 350000,
    );
  }

  static List<AiInsightItem> getAllPresets() {
    return [
      getDefaultInsight(),
      getWarningInsight(),
      getCriticalInsight(),
    ];
  }
}
