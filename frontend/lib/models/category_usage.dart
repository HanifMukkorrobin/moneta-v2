import 'package:flutter/material.dart';
import '../utils/category_icon_mapper.dart';

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

  factory CategoryUsage.fromJson(Map<String, dynamic> json) {
    final nameVal = (json['name'] ?? json['category'] ?? '').toString();
    final typeVal = (json['type'] ?? 'expense').toString().toLowerCase() == 'income'
        ? 'income'
        : 'expense';
    final rawCount = json['count'] ?? json['usageCount'] ?? json['transactionCount'] ?? 0;
    final rawCustom = json['isCustom'] ?? json['is_custom'];
    final isCustomVal = rawCustom == true || rawCustom == 1 || rawCustom == '1';

    return CategoryUsage(
      name: nameVal,
      type: typeVal,
      count: rawCount is num ? rawCount.toInt() : (int.tryParse(rawCount.toString()) ?? 0),
      icon: CategoryIconMapper.getCategoryIcon(
        nameVal,
        iconKey: json['icon']?.toString(),
        type: typeVal,
      ),
      color: CategoryIconMapper.getCategoryColor(
        nameVal,
        colorHex: json['color']?.toString(),
        type: typeVal,
      ),
      isCustom: isCustomVal,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'count': count,
      'isCustom': isCustom,
    };
  }
}
