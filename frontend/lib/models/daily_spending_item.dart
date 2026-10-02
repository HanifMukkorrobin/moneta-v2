import '../config/app_env.dart';
import '../utils/currency_format.dart';

class DailySpendingPoint {
  final String dayLabel; // e.g. 'Sen', 'Sel', 'Rab'
  final DateTime date;
  final double amount;
  final bool isAboveAverage;

  const DailySpendingPoint({
    required this.dayLabel,
    required this.date,
    required this.amount,
    this.isAboveAverage = false,
  });

  String get formattedAmount => CurrencyFormat.formatRupiah(amount);

  String get formattedShortAmount =>
      CurrencyFormat.formatCompactRupiah(amount, withSymbol: false);

  factory DailySpendingPoint.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'];
    final parsedDate = rawDate != null
        ? (DateTime.tryParse(rawDate.toString()) ?? DateTime.now())
        : DateTime.now();
    final rawAmount = json['amount'] ?? 0;
    final amountVal = rawAmount is num
        ? rawAmount.toDouble()
        : (double.tryParse(rawAmount.toString()) ?? 0.0);
    final rawAbove = json['isAboveAverage'] ?? json['is_above_average'];

    return DailySpendingPoint(
      dayLabel: (json['dayLabel'] ?? json['day_label'] ?? 'Sen').toString(),
      date: parsedDate,
      amount: amountVal,
      isAboveAverage: rawAbove == true || rawAbove == 1 || rawAbove == '1',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dayLabel': dayLabel,
      'date': date.toIso8601String(),
      'amount': amount,
      'isAboveAverage': isAboveAverage,
    };
  }
}

class DailySpendingAnalysis {
  final double avgDailySpend;
  final double targetDailySpend;
  final double weekOverWeekPercent; // e.g. +7.5 or -4.2
  final double highestSpendAmount;
  final String highestSpendDay;
  final double lowestSpendAmount;
  final String lowestSpendDay;
  final String topCategoryName;
  final double topCategoryPercentage;
  final List<DailySpendingPoint> dailyPoints;

  const DailySpendingAnalysis({
    required this.avgDailySpend,
    required this.targetDailySpend,
    required this.weekOverWeekPercent,
    required this.highestSpendAmount,
    required this.highestSpendDay,
    required this.lowestSpendAmount,
    required this.lowestSpendDay,
    required this.topCategoryName,
    required this.topCategoryPercentage,
    required this.dailyPoints,
  });

  factory DailySpendingAnalysis.fromJson(Map<String, dynamic> json) {
    double toD(dynamic v, [double fallback = 0.0]) =>
        v is num ? v.toDouble() : (v != null ? (double.tryParse(v.toString()) ?? fallback) : fallback);

    final rawPoints = json['dailyPoints'] ?? json['daily_points'] ?? [];
    final points = <DailySpendingPoint>[];
    if (rawPoints is List) {
      for (final item in rawPoints) {
        if (item is Map<String, dynamic>) {
          points.add(DailySpendingPoint.fromJson(item));
        }
      }
    }

    return DailySpendingAnalysis(
      avgDailySpend: toD(json['avgDailySpend'] ?? json['avg_daily_spend'], 78500),
      targetDailySpend: toD(
        json['targetDailySpend'] ?? json['target_daily_spend'],
        AppEnv.defaultTargetDailySpend,
      ),
      weekOverWeekPercent: toD(
        json['weekOverWeekPercent'] ?? json['week_over_week_percent'],
        6.8,
      ),
      highestSpendAmount: toD(
        json['highestSpendAmount'] ?? json['highest_spend_amount'],
        145000,
      ),
      highestSpendDay: (json['highestSpendDay'] ??
              json['highest_spend_day'] ??
              'Sabtu')
          .toString(),
      lowestSpendAmount: toD(
        json['lowestSpendAmount'] ?? json['lowest_spend_amount'],
        35000,
      ),
      lowestSpendDay: (json['lowestSpendDay'] ??
              json['lowest_spend_day'] ??
              'Selasa')
          .toString(),
      topCategoryName: (json['topCategoryName'] ??
              json['top_category_name'] ??
              'Makan & Minuman')
          .toString(),
      topCategoryPercentage: toD(
        json['topCategoryPercentage'] ?? json['top_category_percentage'],
        48.0,
      ),
      dailyPoints: points,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'avgDailySpend': avgDailySpend,
      'targetDailySpend': targetDailySpend,
      'weekOverWeekPercent': weekOverWeekPercent,
      'highestSpendAmount': highestSpendAmount,
      'highestSpendDay': highestSpendDay,
      'lowestSpendAmount': lowestSpendAmount,
      'lowestSpendDay': lowestSpendDay,
      'topCategoryName': topCategoryName,
      'topCategoryPercentage': topCategoryPercentage,
      'dailyPoints': dailyPoints.map((p) => p.toJson()).toList(),
    };
  }

  bool get isAboveTarget => avgDailySpend > targetDailySpend;
  bool get isSpendingIncreasing => weekOverWeekPercent > 0;

  String get formattedAvgDailySpend =>
      CurrencyFormat.formatRupiah(avgDailySpend);

  String get formattedTargetDailySpend =>
      CurrencyFormat.formatRupiah(targetDailySpend);

  String get formattedHighestSpend =>
      CurrencyFormat.formatRupiah(highestSpendAmount);

  String get formattedLowestSpend =>
      CurrencyFormat.formatRupiah(lowestSpendAmount);

  String get comparisonBadgeLabel {
    final sign = weekOverWeekPercent > 0 ? '+' : '';
    return '$sign${weekOverWeekPercent.toStringAsFixed(1)}% vs pekan lalu';
  }

  double get maxBarAmount {
    if (dailyPoints.isEmpty) return 1.0;
    double max = 0;
    for (var point in dailyPoints) {
      if (point.amount > max) max = point.amount;
    }
    return max > 0 ? max : 1.0;
  }

  static DailySpendingAnalysis empty() {
    return const DailySpendingAnalysis(
      avgDailySpend: 0,
      targetDailySpend: 65000,
      weekOverWeekPercent: 0,
      highestSpendAmount: 0,
      highestSpendDay: '-',
      lowestSpendAmount: 0,
      lowestSpendDay: '-',
      topCategoryName: '-',
      topCategoryPercentage: 0,
      dailyPoints: [],
    );
  }

  static DailySpendingAnalysis getDefaultDailyAnalysis() {
    final now = DateTime.now();
    final points = [
      DailySpendingPoint(
        dayLabel: 'Sen',
        date: now.subtract(const Duration(days: 6)),
        amount: 62000,
        isAboveAverage: false,
      ),
      DailySpendingPoint(
        dayLabel: 'Sel',
        date: now.subtract(const Duration(days: 5)),
        amount: 35000,
        isAboveAverage: false,
      ),
      DailySpendingPoint(
        dayLabel: 'Rab',
        date: now.subtract(const Duration(days: 4)),
        amount: 88000,
        isAboveAverage: true,
      ),
      DailySpendingPoint(
        dayLabel: 'Kam',
        date: now.subtract(const Duration(days: 3)),
        amount: 72000,
        isAboveAverage: false,
      ),
      DailySpendingPoint(
        dayLabel: 'Jum',
        date: now.subtract(const Duration(days: 2)),
        amount: 95000,
        isAboveAverage: true,
      ),
      DailySpendingPoint(
        dayLabel: 'Sab',
        date: now.subtract(const Duration(days: 1)),
        amount: 145000,
        isAboveAverage: true,
      ),
      DailySpendingPoint(
        dayLabel: 'Min',
        date: now,
        amount: 52500,
        isAboveAverage: false,
      ),
    ];

    return DailySpendingAnalysis(
      avgDailySpend: 78500,
      targetDailySpend: 65000,
      weekOverWeekPercent: 6.8,
      highestSpendAmount: 145000,
      highestSpendDay: 'Sabtu',
      lowestSpendAmount: 35000,
      lowestSpendDay: 'Selasa',
      topCategoryName: 'Makan & Minuman',
      topCategoryPercentage: 48.0,
      dailyPoints: points,
    );
  }

  static DailySpendingAnalysis getHighSpendingAnalysis() {
    final now = DateTime.now();
    final points = [
      DailySpendingPoint(
        dayLabel: 'Sen',
        date: now.subtract(const Duration(days: 6)),
        amount: 110000,
        isAboveAverage: false,
      ),
      DailySpendingPoint(
        dayLabel: 'Sel',
        date: now.subtract(const Duration(days: 5)),
        amount: 95000,
        isAboveAverage: false,
      ),
      DailySpendingPoint(
        dayLabel: 'Rab',
        date: now.subtract(const Duration(days: 4)),
        amount: 160000,
        isAboveAverage: true,
      ),
      DailySpendingPoint(
        dayLabel: 'Kam',
        date: now.subtract(const Duration(days: 3)),
        amount: 130000,
        isAboveAverage: false,
      ),
      DailySpendingPoint(
        dayLabel: 'Jum',
        date: now.subtract(const Duration(days: 2)),
        amount: 175000,
        isAboveAverage: true,
      ),
      DailySpendingPoint(
        dayLabel: 'Sab',
        date: now.subtract(const Duration(days: 1)),
        amount: 220000,
        isAboveAverage: true,
      ),
      DailySpendingPoint(
        dayLabel: 'Min',
        date: now,
        amount: 85000,
        isAboveAverage: false,
      ),
    ];

    return DailySpendingAnalysis(
      avgDailySpend: 139285,
      targetDailySpend: 65000,
      weekOverWeekPercent: 34.5,
      highestSpendAmount: 220000,
      highestSpendDay: 'Sabtu',
      lowestSpendAmount: 85000,
      lowestSpendDay: 'Minggu',
      topCategoryName: 'Hiburan & Belanja',
      topCategoryPercentage: 54.0,
      dailyPoints: points,
    );
  }
}
