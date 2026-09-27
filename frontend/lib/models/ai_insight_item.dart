import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum AiWarnLevel {
  normal,
  warning,
  critical;

  static AiWarnLevel fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'critical':
      case 'kritis':
        return AiWarnLevel.critical;
      case 'warning':
      case 'waspada':
        return AiWarnLevel.warning;
      case 'normal':
      case 'aman':
      default:
        return AiWarnLevel.normal;
    }
  }

  String get keyName {
    switch (this) {
      case AiWarnLevel.critical:
        return 'critical';
      case AiWarnLevel.warning:
        return 'warning';
      case AiWarnLevel.normal:
        return 'normal';
    }
  }

  String get label {
    switch (this) {
      case AiWarnLevel.critical:
        return 'Kondisi Kritis';
      case AiWarnLevel.warning:
        return 'Perlu Waspada';
      case AiWarnLevel.normal:
        return 'Keuangan Aman';
    }
  }

  Color get color {
    switch (this) {
      case AiWarnLevel.critical:
        return const Color(0xFFEF4444); // Red
      case AiWarnLevel.warning:
        return const Color(0xFFF59E0B); // Amber
      case AiWarnLevel.normal:
        return const Color(0xFF10B981); // Emerald Green
    }
  }

  IconData get icon {
    switch (this) {
      case AiWarnLevel.critical:
        return Icons.error_outline_rounded;
      case AiWarnLevel.warning:
        return Icons.warning_amber_rounded;
      case AiWarnLevel.normal:
        return Icons.check_circle_outline_rounded;
    }
  }
}

class AiInsightItem {
  final String id;
  final String userId;
  final DateTime date;
  final double avgDailySpend;
  final int estimatedDaysLeft;
  final String dailyAdvice;
  final AiWarnLevel warnLevel;
  final double recommendedDailyBudget;
  final double totalMonthlyBudget;
  final double totalSpent;
  final double remainingBalance;

  const AiInsightItem({
    required this.id,
    this.userId = 'user_default',
    required this.date,
    required this.avgDailySpend,
    required this.estimatedDaysLeft,
    required this.dailyAdvice,
    this.warnLevel = AiWarnLevel.normal,
    this.recommendedDailyBudget = 0.0,
    this.totalMonthlyBudget = 0.0,
    this.totalSpent = 0.0,
    this.remainingBalance = 0.0,
  });

  bool get isNormal => warnLevel == AiWarnLevel.normal;
  bool get isWarning => warnLevel == AiWarnLevel.warning;
  bool get isCritical => warnLevel == AiWarnLevel.critical;

  String get formattedAvgDailySpend => NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(avgDailySpend);

  String get formattedRecommendedDailyBudget => NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(recommendedDailyBudget);

  String get formattedRemainingBalance => NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(remainingBalance);

  String get formattedTotalSpent => NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(totalSpent);

  String get formattedTotalMonthlyBudget => NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(totalMonthlyBudget);

  AiInsightItem copyWith({
    String? id,
    String? userId,
    DateTime? date,
    double? avgDailySpend,
    int? estimatedDaysLeft,
    String? dailyAdvice,
    AiWarnLevel? warnLevel,
    double? recommendedDailyBudget,
    double? totalMonthlyBudget,
    double? totalSpent,
    double? remainingBalance,
  }) {
    return AiInsightItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      avgDailySpend: avgDailySpend ?? this.avgDailySpend,
      estimatedDaysLeft: estimatedDaysLeft ?? this.estimatedDaysLeft,
      dailyAdvice: dailyAdvice ?? this.dailyAdvice,
      warnLevel: warnLevel ?? this.warnLevel,
      recommendedDailyBudget:
          recommendedDailyBudget ?? this.recommendedDailyBudget,
      totalMonthlyBudget: totalMonthlyBudget ?? this.totalMonthlyBudget,
      totalSpent: totalSpent ?? this.totalSpent,
      remainingBalance: remainingBalance ?? this.remainingBalance,
    );
  }
}
