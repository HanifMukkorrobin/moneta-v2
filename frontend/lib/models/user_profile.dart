import 'package:flutter/foundation.dart';

@immutable
class UserProfile {
  final int id;
  final String displayName;
  final String email;
  final String currency;
  final String currencySymbol;
  final bool pinEnabled;
  final String? pinCode;
  final bool biometricEnabled;
  final bool notificationsEnabled;
  final String aiAdviceTone; // 'Santai', 'Standar', 'Tegas'
  final double monthlyBudgetLimit;
  final String accountTier;
  final String dateFormat;
  final String firstDayOfWeek;
  final String themeMode;
  final bool hideBalance;
  final bool autoConfirmChat;
  final bool hapticFeedback;
  final int budgetAlertThreshold;
  final DateTime createdAt;

  const UserProfile({
    this.id = 1,
    this.displayName = 'Budi Santoso',
    this.email = 'budi.santoso@moneta.ai',
    this.currency = 'IDR',
    this.currencySymbol = 'Rp',
    this.pinEnabled = false,
    this.pinCode,
    this.biometricEnabled = false,
    this.notificationsEnabled = true,
    this.aiAdviceTone = 'Standar',
    this.monthlyBudgetLimit = 6000000,
    this.accountTier = 'Personal AI',
    this.dateFormat = 'DD/MM/YYYY',
    this.firstDayOfWeek = 'Senin',
    this.themeMode = 'Terang',
    this.hideBalance = false,
    this.autoConfirmChat = false,
    this.hapticFeedback = true,
    this.budgetAlertThreshold = 80,
    required this.createdAt,
  });

  UserProfile copyWith({
    int? id,
    String? displayName,
    String? email,
    String? currency,
    String? currencySymbol,
    bool? pinEnabled,
    String? pinCode,
    bool? biometricEnabled,
    bool? notificationsEnabled,
    String? aiAdviceTone,
    double? monthlyBudgetLimit,
    String? accountTier,
    String? dateFormat,
    String? firstDayOfWeek,
    String? themeMode,
    bool? hideBalance,
    bool? autoConfirmChat,
    bool? hapticFeedback,
    int? budgetAlertThreshold,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      currency: currency ?? this.currency,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      pinEnabled: pinEnabled ?? this.pinEnabled,
      pinCode: pinCode ?? this.pinCode,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      aiAdviceTone: aiAdviceTone ?? this.aiAdviceTone,
      monthlyBudgetLimit: monthlyBudgetLimit ?? this.monthlyBudgetLimit,
      accountTier: accountTier ?? this.accountTier,
      dateFormat: dateFormat ?? this.dateFormat,
      firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
      themeMode: themeMode ?? this.themeMode,
      hideBalance: hideBalance ?? this.hideBalance,
      autoConfirmChat: autoConfirmChat ?? this.autoConfirmChat,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      budgetAlertThreshold: budgetAlertThreshold ?? this.budgetAlertThreshold,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'email': email,
      'currency': currency,
      'currencySymbol': currencySymbol,
      'pinEnabled': pinEnabled,
      'pinCode': pinCode,
      'biometricEnabled': biometricEnabled,
      'notificationsEnabled': notificationsEnabled,
      'aiAdviceTone': aiAdviceTone,
      'monthlyBudgetLimit': monthlyBudgetLimit,
      'accountTier': accountTier,
      'dateFormat': dateFormat,
      'firstDayOfWeek': firstDayOfWeek,
      'themeMode': themeMode,
      'hideBalance': hideBalance,
      'autoConfirmChat': autoConfirmChat,
      'hapticFeedback': hapticFeedback,
      'budgetAlertThreshold': budgetAlertThreshold,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int? ?? 1,
      displayName: json['displayName'] as String? ?? 'Budi Santoso',
      email: json['email'] as String? ?? 'budi.santoso@moneta.ai',
      currency: json['currency'] as String? ?? 'IDR',
      currencySymbol: json['currencySymbol'] as String? ?? 'Rp',
      pinEnabled: json['pinEnabled'] as bool? ?? false,
      pinCode: json['pinCode'] as String?,
      biometricEnabled: json['biometricEnabled'] as bool? ?? false,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      aiAdviceTone: json['aiAdviceTone'] as String? ?? 'Standar',
      monthlyBudgetLimit: (json['monthlyBudgetLimit'] as num?)?.toDouble() ?? 6000000,
      accountTier: json['accountTier'] as String? ?? 'Personal AI',
      dateFormat: json['dateFormat'] as String? ?? 'DD/MM/YYYY',
      firstDayOfWeek: json['firstDayOfWeek'] as String? ?? 'Senin',
      themeMode: json['themeMode'] as String? ?? 'Terang',
      hideBalance: json['hideBalance'] as bool? ?? false,
      autoConfirmChat: json['autoConfirmChat'] as bool? ?? false,
      hapticFeedback: json['hapticFeedback'] as bool? ?? true,
      budgetAlertThreshold: json['budgetAlertThreshold'] as int? ?? 80,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime(2026, 1, 1)
          : DateTime(2026, 1, 1),
    );
  }

  static UserProfile defaultProfile() {
    return UserProfile(
      id: 1,
      displayName: 'Budi Santoso',
      email: 'budi.santoso@moneta.ai',
      currency: 'IDR',
      currencySymbol: 'Rp',
      pinEnabled: false,
      biometricEnabled: false,
      notificationsEnabled: true,
      aiAdviceTone: 'Standar',
      monthlyBudgetLimit: 6000000,
      accountTier: 'Personal AI',
      dateFormat: 'DD/MM/YYYY',
      firstDayOfWeek: 'Senin',
      themeMode: 'Terang',
      hideBalance: false,
      autoConfirmChat: false,
      hapticFeedback: true,
      budgetAlertThreshold: 80,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          displayName == other.displayName &&
          email == other.email &&
          currency == other.currency &&
          pinEnabled == other.pinEnabled &&
          biometricEnabled == other.biometricEnabled &&
          aiAdviceTone == other.aiAdviceTone &&
          monthlyBudgetLimit == other.monthlyBudgetLimit;

  @override
  int get hashCode =>
      id.hashCode ^
      displayName.hashCode ^
      email.hashCode ^
      currency.hashCode ^
      pinEnabled.hashCode ^
      biometricEnabled.hashCode ^
      aiAdviceTone.hashCode ^
      monthlyBudgetLimit.hashCode;
}
