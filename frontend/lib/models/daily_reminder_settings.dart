import 'package:flutter/material.dart';

class DailyReminderSettings {
  final bool isEnabled;
  final TimeOfDay morningReminderTime;
  final bool isMorningReminderEnabled;
  final TimeOfDay eveningReminderTime;
  final bool isEveningReminderEnabled;
  final List<int> activeDays; // 1 = Senin, 7 = Minggu
  final bool notifyOnOverbudget;
  final bool notifySavingTips;
  final bool notifyDebtDue;
  final bool soundEnabled;
  final bool vibrationEnabled;

  const DailyReminderSettings({
    this.isEnabled = true,
    this.morningReminderTime = const TimeOfDay(hour: 8, minute: 0),
    this.isMorningReminderEnabled = true,
    this.eveningReminderTime = const TimeOfDay(hour: 20, minute: 0),
    this.isEveningReminderEnabled = true,
    this.activeDays = const [1, 2, 3, 4, 5, 6, 7],
    this.notifyOnOverbudget = true,
    this.notifySavingTips = true,
    this.notifyDebtDue = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
  });

  static String formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute WIB';
  }

  String get morningTimeFormatted => formatTime(morningReminderTime);
  String get eveningTimeFormatted => formatTime(eveningReminderTime);

  String get activeDaysSummary {
    if (activeDays.length == 7) return 'Setiap Hari';
    if (activeDays.isEmpty) return 'Tidak Aktif';
    if (activeDays.length == 5 &&
        activeDays.contains(1) &&
        activeDays.contains(2) &&
        activeDays.contains(3) &&
        activeDays.contains(4) &&
        activeDays.contains(5)) {
      return 'Hari Kerja (Sen - Jum)';
    }
    if (activeDays.length == 2 &&
        activeDays.contains(6) &&
        activeDays.contains(7)) {
      return 'Akhir Pekan (Sab - Min)';
    }

    final dayNames = {
      1: 'Sen',
      2: 'Sel',
      3: 'Rab',
      4: 'Kam',
      5: 'Jum',
      6: 'Sab',
      7: 'Min',
    };
    final sorted = List.of(activeDays)..sort();
    return sorted.map((d) => dayNames[d] ?? '').where((s) => s.isNotEmpty).join(', ');
  }

  DailyReminderSettings copyWith({
    bool? isEnabled,
    TimeOfDay? morningReminderTime,
    bool? isMorningReminderEnabled,
    TimeOfDay? eveningReminderTime,
    bool? isEveningReminderEnabled,
    List<int>? activeDays,
    bool? notifyOnOverbudget,
    bool? notifySavingTips,
    bool? notifyDebtDue,
    bool? soundEnabled,
    bool? vibrationEnabled,
  }) {
    return DailyReminderSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      morningReminderTime: morningReminderTime ?? this.morningReminderTime,
      isMorningReminderEnabled:
          isMorningReminderEnabled ?? this.isMorningReminderEnabled,
      eveningReminderTime: eveningReminderTime ?? this.eveningReminderTime,
      isEveningReminderEnabled:
          isEveningReminderEnabled ?? this.isEveningReminderEnabled,
      activeDays: activeDays ?? this.activeDays,
      notifyOnOverbudget: notifyOnOverbudget ?? this.notifyOnOverbudget,
      notifySavingTips: notifySavingTips ?? this.notifySavingTips,
      notifyDebtDue: notifyDebtDue ?? this.notifyDebtDue,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    );
  }

  static TimeOfDay parseTimeString(String? value, TimeOfDay fallback) {
    if (value == null || value.trim().isEmpty) return fallback;
    final parts = value.trim().split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60) {
        return TimeOfDay(hour: h, minute: m);
      }
    }
    return fallback;
  }

  static String toHHmm(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  factory DailyReminderSettings.fromJson(Map<String, dynamic> json) {
    bool toBool(dynamic v, bool fallback) {
      if (v == null) return fallback;
      if (v is bool) return v;
      return v == 1 || v == '1' || v == 'true';
    }

    final rawDays = json['activeDays'] ?? json['active_days'];
    List<int> days = const [1, 2, 3, 4, 5, 6, 7];
    if (rawDays is List) {
      days = rawDays
          .map((e) => e is num ? e.toInt() : (int.tryParse(e.toString()) ?? 1))
          .toList();
    }

    return DailyReminderSettings(
      isEnabled: toBool(json['isEnabled'] ?? json['is_enabled'], true),
      morningReminderTime: parseTimeString(
        (json['morningReminderTime'] ?? json['morning_reminder_time'])?.toString(),
        const TimeOfDay(hour: 8, minute: 0),
      ),
      isMorningReminderEnabled: toBool(
        json['isMorningReminderEnabled'] ?? json['is_morning_reminder_enabled'],
        true,
      ),
      eveningReminderTime: parseTimeString(
        (json['eveningReminderTime'] ?? json['evening_reminder_time'])?.toString(),
        const TimeOfDay(hour: 20, minute: 0),
      ),
      isEveningReminderEnabled: toBool(
        json['isEveningReminderEnabled'] ?? json['is_evening_reminder_enabled'],
        true,
      ),
      activeDays: days,
      notifyOnOverbudget: toBool(
        json['notifyOnOverbudget'] ?? json['notify_on_overbudget'],
        true,
      ),
      notifySavingTips: toBool(
        json['notifySavingTips'] ?? json['notify_saving_tips'],
        true,
      ),
      notifyDebtDue: toBool(
        json['notifyDebtDue'] ?? json['notify_debt_due'],
        true,
      ),
      soundEnabled: toBool(
        json['soundEnabled'] ?? json['sound_enabled'],
        true,
      ),
      vibrationEnabled: toBool(
        json['vibrationEnabled'] ?? json['vibration_enabled'],
        true,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isEnabled': isEnabled,
      'morningReminderTime': toHHmm(morningReminderTime),
      'isMorningReminderEnabled': isMorningReminderEnabled,
      'eveningReminderTime': toHHmm(eveningReminderTime),
      'isEveningReminderEnabled': isEveningReminderEnabled,
      'activeDays': activeDays,
      'notifyOnOverbudget': notifyOnOverbudget,
      'notifySavingTips': notifySavingTips,
      'notifyDebtDue': notifyDebtDue,
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
    };
  }
}
