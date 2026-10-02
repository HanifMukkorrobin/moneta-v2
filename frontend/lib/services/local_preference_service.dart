import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Service untuk menyimpan preferensi pengguna (seperti Tema Terang/Gelap)
/// secara lokal di perangkat dengan fallback in-memory yang aman.
class LocalPreferenceService {
  static LocalPreferenceService? _instance;
  static LocalPreferenceService get instance =>
      _instance ??= LocalPreferenceService._();

  LocalPreferenceService._() {
    _initSync();
  }

  @visibleForTesting
  static void setMockInstance(LocalPreferenceService mock) {
    _instance = mock;
  }

  static const String _defaultFileName = 'moneta_local_preferences.json';
  String _filePath = _defaultFileName;
  final Map<String, dynamic> _cache = {};
  bool _initialized = false;

  void _initSync() {
    if (_initialized) return;
    try {
      final file = File(_filePath);
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        if (content.isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map<String, dynamic>) {
            _cache.addAll(decoded);
          }
        }
      }
    } catch (_) {
      // Abaikan error I/O dan fallback ke memory cache
    }
    _initialized = true;
  }

  void _persistSync() {
    try {
      final file = File(_filePath);
      file.writeAsStringSync(jsonEncode(_cache), flush: true);
    } catch (_) {
      // Abaikan error I/O (misal di sandboxed/test environment)
    }
  }

  /// Simpan mode tema ('Terang', 'Gelap', 'Ikuti Sistem')
  void saveThemeMode(String mode) {
    _cache['themeMode'] = mode;
    _persistSync();
  }

  /// Ambil mode tema yang tersimpan
  String? getThemeMode() {
    _initSync();
    return _cache['themeMode'] as String?;
  }

  /// Simpan nilai generic string
  void setString(String key, String value) {
    _cache[key] = value;
    _persistSync();
  }

  /// Ambil nilai string
  String? getString(String key) {
    _initSync();
    return _cache[key] as String?;
  }

  /// Simpan nilai boolean
  void setBool(String key, bool value) {
    _cache[key] = value;
    _persistSync();
  }

  /// Ambil nilai boolean
  bool? getBool(String key) {
    _initSync();
    return _cache[key] as bool?;
  }

  /// Simpan token autentikasi sesi
  void saveAuthToken(String token) {
    _cache['authToken'] = token;
    _persistSync();
  }

  /// Ambil token autentikasi sesi
  String? getAuthToken() {
    _initSync();
    return _cache['authToken'] as String?;
  }

  /// Hapus token autentikasi sesi
  void clearAuthToken() {
    _cache.remove('authToken');
    _cache.remove('userId');
    _persistSync();
  }

  /// Simpan ID pengguna aktif
  void saveUserId(int userId) {
    _cache['userId'] = userId;
    _persistSync();
  }

  /// Ambil ID pengguna aktif
  int? getUserId() {
    _initSync();
    final val = _cache['userId'];
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val);
    return null;
  }

  /// Hapus preferensi tersimpan
  void clear() {
    _cache.clear();
    try {
      final file = File(_filePath);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {}
  }

  /// Reset untuk unit test
  @visibleForTesting
  void resetForTesting([String? customPath]) {
    clear();
    _filePath = customPath ?? _defaultFileName;
    _initialized = false;
    _initSync();
  }
}
