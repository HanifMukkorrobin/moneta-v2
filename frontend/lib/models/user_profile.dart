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
    this.id = 0,
    this.displayName = 'Pengguna',
    this.email = '',
    this.currency = 'IDR',
    this.currencySymbol = 'Rp',
    this.pinEnabled = false,
    this.pinCode,
    this.biometricEnabled = false,
    this.notificationsEnabled = true,
    this.aiAdviceTone = 'Standar',
    this.monthlyBudgetLimit = 0,
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
    bool toBool(dynamic v, bool fallback) {
      if (v == null) return fallback;
      if (v is bool) return v;
      return v == 1 || v == '1' || v == 'true';
    }

    int toInt(dynamic v, int fallback) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? fallback;
    }

    double toDouble(dynamic v, double fallback) {
      if (v == null) return fallback;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? fallback;
    }

    final rawCreated = json['createdAt'] ?? json['created_at'];

    return UserProfile(
      id: toInt(json['id'], 1),
      displayName: (json['displayName'] ?? json['display_name'] ?? 'Budi Santoso').toString(),
      email: (json['email'] ?? 'budi.santoso@moneta.ai').toString(),
      currency: (json['currency'] ?? 'IDR').toString(),
      currencySymbol: (json['currencySymbol'] ?? json['currency_symbol'] ?? 'Rp').toString(),
      pinEnabled: toBool(json['pinEnabled'] ?? json['pin_enabled'] ?? json['hasPin'], false),
      pinCode: (json['pinCode'] ?? json['pin_code'])?.toString(),
      biometricEnabled: toBool(json['biometricEnabled'] ?? json['biometric_enabled'], false),
      notificationsEnabled: toBool(json['notificationsEnabled'] ?? json['notifications_enabled'], true),
      aiAdviceTone: (json['aiAdviceTone'] ?? json['ai_advice_tone'] ?? 'Standar').toString(),
      monthlyBudgetLimit: toDouble(json['monthlyBudgetLimit'] ?? json['monthly_budget_limit'], 6000000),
      accountTier: (json['accountTier'] ?? json['account_tier'] ?? 'Personal AI').toString(),
      dateFormat: (json['dateFormat'] ?? json['date_format'] ?? 'DD/MM/YYYY').toString(),
      firstDayOfWeek: (json['firstDayOfWeek'] ?? json['first_day_of_week'] ?? 'Senin').toString(),
      themeMode: (json['themeMode'] ?? json['theme_mode'] ?? 'Terang').toString(),
      hideBalance: toBool(json['hideBalance'] ?? json['hide_balance'], false),
      autoConfirmChat: toBool(json['autoConfirmChat'] ?? json['auto_confirm_chat'], false),
      hapticFeedback: toBool(json['hapticFeedback'] ?? json['haptic_feedback'], true),
      budgetAlertThreshold: toInt(json['budgetAlertThreshold'] ?? json['budget_alert_threshold'], 80),
      createdAt: rawCreated != null
          ? DateTime.tryParse(rawCreated.toString()) ?? DateTime(2026, 1, 1)
          : DateTime(2026, 1, 1),
    );
  }

  static UserProfile empty() {
    return UserProfile(
      id: 0,
      displayName: 'Pengguna',
      email: '',
      currency: 'IDR',
      currencySymbol: 'Rp',
      pinEnabled: false,
      biometricEnabled: false,
      notificationsEnabled: true,
      aiAdviceTone: 'Standar',
      monthlyBudgetLimit: 0,
      accountTier: 'Personal AI',
      dateFormat: 'DD/MM/YYYY',
      firstDayOfWeek: 'Senin',
      themeMode: 'Terang',
      hideBalance: false,
      autoConfirmChat: false,
      hapticFeedback: true,
      budgetAlertThreshold: 80,
      createdAt: DateTime.now(),
    );
  }

  static UserProfile get defaultUser => UserProfile.fromJson({});

  static UserProfile defaultProfile() => empty();

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
