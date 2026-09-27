import 'package:flutter/material.dart';
import '../utils/currency_format.dart';

class SavingTipItem {
  final String id;
  final String title;
  final String category;
  final String description;
  final double potentialSaving;
  final String impactLevel; // 'Tinggi', 'Sedang', 'Ringan'
  final IconData icon;
  final bool isApplied;
  final String actionText;

  final String? date;
  final DateTime? appliedAt;

  const SavingTipItem({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.potentialSaving,
    this.impactLevel = 'Sedang',
    this.icon = Icons.lightbulb_outline_rounded,
    this.isApplied = false,
    this.actionText = 'Terapkan Hari Ini',
    this.date,
    this.appliedAt,
  });

  String get formattedPotentialSaving =>
      CurrencyFormat.formatRupiah(potentialSaving);

  Color get impactColor {
    switch (impactLevel.toLowerCase()) {
      case 'tinggi':
        return const Color(0xFF10B981); // Emerald Green
      case 'sedang':
        return const Color(0xFF3B82F6); // Blue
      case 'ringan':
      default:
        return const Color(0xFF8B5CF6); // Purple
    }
  }

  SavingTipItem copyWith({
    String? id,
    String? title,
    String? category,
    String? description,
    double? potentialSaving,
    String? impactLevel,
    IconData? icon,
    bool? isApplied,
    String? actionText,
    String? date,
    DateTime? appliedAt,
  }) {
    return SavingTipItem(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      description: description ?? this.description,
      potentialSaving: potentialSaving ?? this.potentialSaving,
      impactLevel: impactLevel ?? this.impactLevel,
      icon: icon ?? this.icon,
      isApplied: isApplied ?? this.isApplied,
      actionText: actionText ?? this.actionText,
      date: date ?? this.date,
      appliedAt: appliedAt ?? this.appliedAt,
    );
  }
}

