import 'package:flutter/material.dart';

class CategoryItem {
  final String id;
  String name;
  String type; // 'expense' | 'income'
  final bool isDefault;
  final IconData? icon;
  final Color? color;
  final DateTime createdAt;

  CategoryItem({
    required this.id,
    required this.name,
    required this.type,
    this.isDefault = false,
    this.icon,
    this.color,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isExpense => type == 'expense';
  bool get isIncome => type == 'income';
  bool get isCustom => !isDefault;

  CategoryItem copyWith({
    String? id,
    String? name,
    String? type,
    bool? isDefault,
    IconData? icon,
    Color? color,
    DateTime? createdAt,
  }) {
    return CategoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
