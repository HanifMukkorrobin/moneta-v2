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
}
