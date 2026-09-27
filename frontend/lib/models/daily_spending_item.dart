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
}
