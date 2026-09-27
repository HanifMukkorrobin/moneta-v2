import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'transaction_item.dart';

class CategoryBreakdownItem {
  final String category;
  final String type; // 'expense' or 'income'
  final double total;
  final double percentage; // 0.0 - 100.0
  final int transactionCount;
  final IconData? icon;
  final Color? color;
  final bool isCustom;

  const CategoryBreakdownItem({
    required this.category,
    required this.type,
    required this.total,
    required this.percentage,
    required this.transactionCount,
    this.icon,
    this.color,
    this.isCustom = false,
  });

  bool get isExpense => type == 'expense';
  bool get isIncome => type == 'income';

  String get formattedTotal {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(total);
  }

  String get formattedPercentage {
    return '${percentage.toStringAsFixed(1)}%';
  }
}

class MonthlyRekapData {
  final String month; // e.g. "2026-09"
  final String monthLabel; // e.g. "September 2026"
  final double totalIncome;
  final double totalExpense;
  final double netSavings;
  final double savingsRate; // 0.0 - 100.0
  final int confirmedTransactionsCount;
  final int pendingTransactionsCount;
  final double lastMonthTotalExpense;
  final double lastMonthTotalIncome;
  final double expenseDiffPct; // difference vs last month (-10.5 means 10.5% lower)
  final double incomeDiffPct;
  final List<CategoryBreakdownItem> categoryBreakdown;
  final List<TransactionItem> transactions;

  const MonthlyRekapData({
    required this.month,
    required this.monthLabel,
    required this.totalIncome,
    required this.totalExpense,
    required this.netSavings,
    required this.savingsRate,
    required this.confirmedTransactionsCount,
    required this.pendingTransactionsCount,
    required this.lastMonthTotalExpense,
    required this.lastMonthTotalIncome,
    required this.expenseDiffPct,
    required this.incomeDiffPct,
    required this.categoryBreakdown,
    required this.transactions,
  });

  bool get isSurplus => netSavings >= 0;

  String get formattedTotalIncome {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(totalIncome);
  }

  String get formattedTotalExpense {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(totalExpense);
  }

  String get formattedNetSavings {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final prefix = netSavings >= 0 ? '+ ' : '- ';
    return '$prefix${formatter.format(netSavings.abs())}';
  }

  String get formattedSavingsRate {
    return '${savingsRate.toStringAsFixed(1)}%';
  }

  List<CategoryBreakdownItem> get expenseBreakdown =>
      categoryBreakdown.where((c) => c.isExpense).toList();

  List<CategoryBreakdownItem> get incomeBreakdown =>
      categoryBreakdown.where((c) => c.isIncome).toList();
}
