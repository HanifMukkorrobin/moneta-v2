import '../models/daily_spending_item.dart';

class DailySpendingMockData {
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
