import 'package:flutter/material.dart';
import '../utils/category_icon_mapper.dart';

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

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    final nameVal = (json['name'] ?? '').toString();
    final typeVal = (json['type'] ?? 'expense').toString().toLowerCase() == 'income'
        ? 'income'
        : 'expense';
    final rawDefault = json['isDefault'] ?? json['is_default'];
    final rawCustom = json['isCustom'] ?? json['is_custom'];
    bool isDefaultVal = false;
    if (rawDefault != null) {
      isDefaultVal = rawDefault == true || rawDefault == 1 || rawDefault == '1';
    } else if (rawCustom != null) {
      isDefaultVal = !(rawCustom == true || rawCustom == 1 || rawCustom == '1');
    } else if (json.containsKey('user_id') && json['user_id'] == null) {
      isDefaultVal = true;
    }

    final rawCreatedAt = json['createdAt'] ?? json['created_at'];
    final parsedDate = rawCreatedAt != null
        ? (DateTime.tryParse(rawCreatedAt.toString()) ?? DateTime.now())
        : DateTime.now();

    return CategoryItem(
      id: (json['id'] ?? '').toString(),
      name: nameVal,
      type: typeVal,
      isDefault: isDefaultVal,
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
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'isDefault': isDefault,
      'isCustom': isCustom,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
