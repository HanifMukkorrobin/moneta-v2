import 'package:flutter/material.dart';
import '../utils/currency_format.dart';

enum AiWarnLevel {
  normal,
  warning,
  critical;

  static AiWarnLevel fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'critical':
      case 'kritis':
        return AiWarnLevel.critical;
      case 'warning':
      case 'waspada':
        return AiWarnLevel.warning;
      case 'normal':
      case 'aman':
      default:
        return AiWarnLevel.normal;
    }
  }

  String get keyName {
    switch (this) {
      case AiWarnLevel.critical:
        return 'critical';
      case AiWarnLevel.warning:
        return 'warning';
      case AiWarnLevel.normal:
        return 'normal';
    }
  }

  String get label {
    switch (this) {
      case AiWarnLevel.critical:
        return 'Kondisi Kritis';
      case AiWarnLevel.warning:
        return 'Perlu Waspada';
      case AiWarnLevel.normal:
        return 'Keuangan Aman';
    }
  }

  Color get color {
    switch (this) {
      case AiWarnLevel.critical:
        return const Color(0xFFEF4444); // Red
      case AiWarnLevel.warning:
        return const Color(0xFFF59E0B); // Amber
      case AiWarnLevel.normal:
        return const Color(0xFF10B981); // Emerald Green
    }
  }

  IconData get icon {
    switch (this) {
      case AiWarnLevel.critical:
        return Icons.error_outline_rounded;
      case AiWarnLevel.warning:
        return Icons.warning_amber_rounded;
      case AiWarnLevel.normal:
        return Icons.check_circle_outline_rounded;
    }
  }
}

class AiInsightItem {
  final String id;
  final String userId;
  final DateTime date;
  final double avgDailySpend;
  final int estimatedDaysLeft;
  final String dailyAdvice;
  final AiWarnLevel warnLevel;
  final double recommendedDailyBudget;
  final double totalMonthlyBudget;
  final double totalSpent;
  final double remainingBalance;

  const AiInsightItem({
    required this.id,
    this.userId = 'user_default',
    required this.date,
    required this.avgDailySpend,
    required this.estimatedDaysLeft,
    required this.dailyAdvice,
    this.warnLevel = AiWarnLevel.normal,
    this.recommendedDailyBudget = 0.0,
    this.totalMonthlyBudget = 0.0,
    this.totalSpent = 0.0,
    this.remainingBalance = 0.0,
  });

  bool get isNormal => warnLevel == AiWarnLevel.normal;
  bool get isWarning => warnLevel == AiWarnLevel.warning;
  bool get isCritical => warnLevel == AiWarnLevel.critical;

  String get formattedAvgDailySpend =>
      CurrencyFormat.formatRupiah(avgDailySpend);

  String get formattedRecommendedDailyBudget =>
      CurrencyFormat.formatRupiah(recommendedDailyBudget);

  String get formattedRemainingBalance =>
      CurrencyFormat.formatRupiah(remainingBalance);

  String get formattedTotalSpent =>
      CurrencyFormat.formatRupiah(totalSpent);

  static const _monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];
  static const _shortMonthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];

  DateTime get projectedDepletionDate =>
      date.add(Duration(days: estimatedDaysLeft));

  String get formattedDepletionDate {
    final d = projectedDepletionDate;
    return '${d.day} ${_monthNames[d.month - 1]} ${d.year}';
  }

  String get formattedShortDepletionDate {
    final d = projectedDepletionDate;
    return '${d.day} ${_shortMonthNames[d.month - 1]} ${d.year}';
  }

  int get daysUntilEndOfMonth {
    final nextMonthFirstDay = DateTime(date.year, date.month + 1, 1);
    final lastDayOfMonth = nextMonthFirstDay.subtract(const Duration(days: 1));
    final diff = lastDayOfMonth.day - date.day;
    return diff > 0 ? diff : 1;
  }

  bool get runsOutBeforeEndOfMonth => estimatedDaysLeft < daysUntilEndOfMonth;

  String get depletionStatusMessage {
    if (runsOutBeforeEndOfMonth) {
      final daysDiff = daysUntilEndOfMonth - estimatedDaysLeft;
      return 'Habis $daysDiff hari sebelum akhir bulan';
    }
    final surplusDays = estimatedDaysLeft - daysUntilEndOfMonth;
    return 'Aman melampaui akhir bulan (+$surplusDays hari)';
  }

  String get formattedTotalMonthlyBudget =>
      CurrencyFormat.formatRupiah(totalMonthlyBudget);

  AiInsightItem copyWith({
    String? id,
    String? userId,
    DateTime? date,
    double? avgDailySpend,
    int? estimatedDaysLeft,
    String? dailyAdvice,
    AiWarnLevel? warnLevel,
    double? recommendedDailyBudget,
    double? totalMonthlyBudget,
    double? totalSpent,
    double? remainingBalance,
  }) {
    return AiInsightItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      avgDailySpend: avgDailySpend ?? this.avgDailySpend,
      estimatedDaysLeft: estimatedDaysLeft ?? this.estimatedDaysLeft,
      dailyAdvice: dailyAdvice ?? this.dailyAdvice,
      warnLevel: warnLevel ?? this.warnLevel,
      recommendedDailyBudget:
          recommendedDailyBudget ?? this.recommendedDailyBudget,
      totalMonthlyBudget: totalMonthlyBudget ?? this.totalMonthlyBudget,
      totalSpent: totalSpent ?? this.totalSpent,
      remainingBalance: remainingBalance ?? this.remainingBalance,
    );
  }

  factory AiInsightItem.fromJson(Map<String, dynamic> json) {
    double toD(dynamic v, [double fallback = 0.0]) =>
        v is num ? v.toDouble() : (v != null ? (double.tryParse(v.toString()) ?? fallback) : fallback);
    int toI(dynamic v, [int fallback = 0]) =>
        v is num ? v.toInt() : (v != null ? (int.tryParse(v.toString()) ?? fallback) : fallback);

    final rawDate = json['date'] ?? json['createdAt'] ?? json['created_at'];
    final parsedDate = rawDate != null
        ? (DateTime.tryParse(rawDate.toString()) ?? DateTime.now())
        : DateTime.now();

    final warnStr = (json['warnLevel'] ?? json['warn_level'] ?? 'normal').toString();

    return AiInsightItem(
      id: (json['id'] ?? 'insight_default').toString(),
      userId: (json['userId'] ?? json['user_id'] ?? 'user_default').toString(),
      date: parsedDate,
      avgDailySpend: toD(json['avgDailySpend'] ?? json['avg_daily_spend'], 78500),
      estimatedDaysLeft: toI(json['estimatedDaysLeft'] ?? json['estimated_days_left'], 18),
      dailyAdvice: (json['dailyAdvice'] ??
              json['daily_advice'] ??
              'Pertahankan ritme belanja Anda. Batasi pos non-esensial maksimal Rp 65.000 hari ini agar saldo aman sampai akhir bulan.')
          .toString(),
      warnLevel: AiWarnLevel.fromString(warnStr),
      recommendedDailyBudget: toD(
        json['recommendedDailyBudget'] ?? json['recommended_daily_budget'],
        65000,
      ),
      totalMonthlyBudget: toD(
        json['totalMonthlyBudget'] ?? json['total_monthly_budget'],
        6000000,
      ),
      totalSpent: toD(json['totalSpent'] ?? json['total_spent'], 2850000),
      remainingBalance: toD(
        json['remainingBalance'] ?? json['remaining_balance'],
        3150000,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'date': date.toIso8601String(),
      'avgDailySpend': avgDailySpend,
      'estimatedDaysLeft': estimatedDaysLeft,
      'dailyAdvice': dailyAdvice,
      'warnLevel': warnLevel.keyName,
      'recommendedDailyBudget': recommendedDailyBudget,
      'totalMonthlyBudget': totalMonthlyBudget,
      'totalSpent': totalSpent,
      'remainingBalance': remainingBalance,
    };
  }

  static AiInsightItem empty() {
    return AiInsightItem(
      id: 'insight_empty',
      date: DateTime.now(),
      avgDailySpend: 0,
      estimatedDaysLeft: 0,
      recommendedDailyBudget: 0,
      dailyAdvice:
          'Belum ada catatan pengeluaran. Catat pengeluaran atau pemasukan pertamamu untuk melihat rekomendasi AI!',
      warnLevel: AiWarnLevel.normal,
      totalMonthlyBudget: 0,
      totalSpent: 0,
      remainingBalance: 0,
    );
  }

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
