import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Konfigurasi environment global untuk aplikasi Flutter Moneta v2
/// menggunakan `flutter_dotenv` dengan fallback nilai default yang aman.
class AppEnv {
  static bool _initialized = false;
  static final Map<String, String> _overrides = {};

  static bool get isInitialized => _initialized || dotenv.isInitialized;

  /// Memuat file `.env` (atau `.env.example` sebagai cadangan) menggunakan `flutter_dotenv`.
  /// Aman dipanggil berulang kali maupun di dalam lingkungan widget/unit test.
  static Future<void> init({String fileName = '.env'}) async {
    if (_initialized) return;
    try {
      await dotenv.load(fileName: fileName, isOptional: true);
      if (!dotenv.isInitialized || dotenv.env.isEmpty) {
        await dotenv.load(fileName: '.env.example', isOptional: true);
      }
    } catch (_) {
      // Abaikan bila asset belum tersedia (mis. saat unit test murni)
    }
    _initialized = true;
  }

  /// Override variabel environment khusus untuk pengujian.
  @visibleForTesting
  static void setTestOverrides(Map<String, String> values) {
    _overrides
      ..clear()
      ..addAll(values);
  }

  @visibleForTesting
  static void clearTestOverrides() {
    _overrides.clear();
  }

  static String getString(String key, String fallback) {
    if (_overrides.containsKey(key)) {
      final v = _overrides[key];
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    if (dotenv.isInitialized) {
      final val = dotenv.maybeGet(key);
      if (val != null && val.trim().isNotEmpty) {
        return val.trim();
      }
    }
    return fallback;
  }

  static int getInt(String key, int fallback) {
    final raw = getString(key, '');
    if (raw.isEmpty) return fallback;
    return int.tryParse(raw) ?? fallback;
  }

  static double getDouble(String key, double fallback) {
    final raw = getString(key, '');
    if (raw.isEmpty) return fallback;
    return double.tryParse(raw) ?? fallback;
  }

  static bool getBool(String key, bool fallback) {
    final raw = getString(key, '').toLowerCase();
    if (raw.isEmpty) return fallback;
    if (raw == 'true' || raw == '1' || raw == 'yes') return true;
    if (raw == 'false' || raw == '0' || raw == 'no') return false;
    return fallback;
  }

  /// Base URL REST API Backend
  static String get apiBaseUrl {
    if (_overrides.containsKey('API_BASE_URL')) {
      return _overrides['API_BASE_URL']!;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return getString(
        'API_BASE_URL_ANDROID',
        getString('API_BASE_URL', 'http://10.0.2.2:3000'),
      );
    }
    return getString('API_BASE_URL', 'http://localhost:3000');
  }

  static int get apiTimeoutMs => getInt('API_TIMEOUT_MS', 15000);
  static Duration get apiTimeout => Duration(milliseconds: apiTimeoutMs);

  static String get appName => getString('APP_NAME', 'Moneta');
  static String get defaultCurrency => getString('DEFAULT_CURRENCY', 'IDR');
  static String get defaultCurrencySymbol =>
      getString('DEFAULT_CURRENCY_SYMBOL', 'Rp');
  static double get defaultMonthlyBudgetLimit =>
      getDouble('DEFAULT_MONTHLY_BUDGET_LIMIT', 6000000);
  static double get defaultMonthlyBudget => defaultMonthlyBudgetLimit;
  static double get defaultTargetDailySpend =>
      getDouble('DEFAULT_TARGET_DAILY_SPEND', 65000);
  static int get defaultBudgetAlertThreshold =>
      getInt('DEFAULT_BUDGET_ALERT_THRESHOLD', 80);
  static double get defaultNeedsPct => getDouble('DEFAULT_NEEDS_PCT', 50);
  static double get defaultSavingsPct => getDouble('DEFAULT_SAVINGS_PCT', 30);
  static double get defaultFunPct => getDouble('DEFAULT_FUN_PCT', 20);
  static String get defaultTimezone =>
      getString('DEFAULT_TIMEZONE', 'Asia/Jakarta');
  static String get defaultMorningReminderTime =>
      getString('DEFAULT_MORNING_REMINDER_TIME', '08:00');
  static String get defaultEveningReminderTime =>
      getString('DEFAULT_EVENING_REMINDER_TIME', '20:00');

  static TimeOfDay parseTimeOfDay(String hhMm, {TimeOfDay? fallback}) {
    final parts = hhMm.trim().split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), ''));
      if (h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60) {
        return TimeOfDay(hour: h, minute: m);
      }
    }
    return fallback ?? const TimeOfDay(hour: 8, minute: 0);
  }
}
