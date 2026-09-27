import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum BudgetBucketType {
  needs, // Kebutuhan (50%)
  savings, // Tabungan / Investasi (30%)
  fun, // Hiburan / Keinginan (20%)
}

class BudgetBucketItem {
  final BudgetBucketType type;
  final String title;
  final double percentage; // e.g. 50.0
  final double amountLimit;
  final double amountSpent;
  final Color color;
  final IconData icon;

  const BudgetBucketItem({
    required this.type,
    required this.title,
    required this.percentage,
    required this.amountLimit,
    required this.amountSpent,
    required this.color,
    required this.icon,
  });

  double get amountRemaining => (amountLimit - amountSpent).clamp(0, double.infinity);
  double get percentageUsed => amountLimit > 0 ? (amountSpent / amountLimit) * 100 : 0.0;
  bool get isOverBudget => amountSpent > amountLimit;

  String get formattedLimit => NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(amountLimit);

  String get formattedSpent => NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(amountSpent);

  String get formattedRemaining => NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(amountRemaining);
}

class CategoryBudgetItem {
  final String id;
  final String categoryName;
  final BudgetBucketType bucketType;
  final double amountLimit;
  final double amountSpent;
  final IconData icon;
  final Color color;

  const CategoryBudgetItem({
    required this.id,
    required this.categoryName,
    required this.bucketType,
    required this.amountLimit,
    required this.amountSpent,
    required this.icon,
    required this.color,
  });

  double get amountRemaining => (amountLimit - amountSpent);
  double get percentageUsed => amountLimit > 0 ? (amountSpent / amountLimit) * 100 : 0.0;
  bool get isOverBudget => amountSpent > amountLimit;

  String get formattedLimit => NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(amountLimit);

  String get formattedSpent => NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(amountSpent);

  String get formattedRemaining => NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(amountRemaining.abs());

  String get bucketLabel {
    switch (bucketType) {
      case BudgetBucketType.needs:
        return 'Kebutuhan';
      case BudgetBucketType.savings:
        return 'Tabungan';
      case BudgetBucketType.fun:
        return 'Hiburan';
    }
  }
}

class MonthlyBudgetSummary {
  final String month;
  final String monthLabel;
  final double totalBudget;
  final double totalSpent;
  final double needsPercentage;
  final double savingsPercentage;
  final double funPercentage;
  final List<BudgetBucketItem> buckets;
  final List<CategoryBudgetItem> categoryBudgets;

  const MonthlyBudgetSummary({
    required this.month,
    required this.monthLabel,
    required this.totalBudget,
    required this.totalSpent,
    required this.needsPercentage,
    required this.savingsPercentage,
    required this.funPercentage,
    required this.buckets,
    required this.categoryBudgets,
  });

  double get totalRemaining => totalBudget - totalSpent;
  double get percentageUsed => totalBudget > 0 ? (totalSpent / totalBudget) * 100 : 0.0;
  double get remainingPercentage => totalBudget > 0
      ? ((totalRemaining / totalBudget) * 100).clamp(0.0, 100.0)
      : 0.0;
  bool get isOverBudget => totalSpent > totalBudget;

  String get formattedTotalBudget => NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(totalBudget);

  String get formattedTotalSpent => NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(totalSpent);

  String get formattedTotalRemaining => NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(totalRemaining.abs());

  String get formattedRemainingWithSign {
    final formatted = formattedTotalRemaining;
    if (totalRemaining < 0) {
      return '- $formatted';
    }
    return formatted;
  }

  int get daysInMonth {
    try {
      final parts = month.split('-');
      if (parts.length >= 2) {
        final year = int.parse(parts[0]);
        final monthNum = int.parse(parts[1]);
        return DateTime(year, monthNum + 1, 0).day;
      }
    } catch (_) {}
    return 30;
  }

  double get dailyRemainingAverage {
    if (totalRemaining <= 0 || daysInMonth <= 0) return 0.0;
    return totalRemaining / daysInMonth;
  }

  String get formattedDailyRemainingAverage {
    final formatted = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(dailyRemainingAverage);
    return '$formatted / hari';
  }

  String get remainingStatusLabel {
    if (isOverBudget) {
      return 'Batas Terlampaui';
    } else if (remainingPercentage <= 15.0) {
      return 'Batas Menipis';
    } else if (remainingPercentage <= 30.0) {
      return 'Perlu Hemat';
    } else {
      return 'Batas Aman';
    }
  }
}
