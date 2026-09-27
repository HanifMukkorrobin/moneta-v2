import 'package:flutter/material.dart';

class CategoryUsage {
  final String name;
  final String type; // 'expense' or 'income'
  final int count;
  final IconData? icon;
  final Color? color;
  final bool isCustom;

  const CategoryUsage({
    required this.name,
    required this.type,
    required this.count,
    this.icon,
    this.color,
    this.isCustom = false,
  });

  bool get isExpense => type == 'expense';
  bool get isIncome => type == 'income';
}
