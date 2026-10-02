import '../../models/daily_reminder_settings.dart';
import '../../models/debt_item.dart';
import 'moneta_api_client.dart';

class ReminderDebtApiService {
  static final ReminderDebtApiService instance = ReminderDebtApiService();
  final MonetaApiClient _client;

  ReminderDebtApiService({MonetaApiClient? client})
      : _client = client ?? MonetaApiClient.instance;

  Future<DailyReminderSettings> getReminderSettings({int? userId}) async {
    final res = await _client.get(
      '/api/pengaturan-pengingat',
      queryParameters: {if (userId != null) 'userId': userId},
    );
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    return DailyReminderSettings.fromJson(data);
  }

  Future<DailyReminderSettings> saveReminderSettings(
    DailyReminderSettings settings, {
    int? userId,
  }) async {
    final body = settings.toJson();
    if (userId != null) {
      body['userId'] = userId;
    }
    final res = await _client.put('/api/pengaturan-pengingat', body: body);
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    return DailyReminderSettings.fromJson(data);
  }

  Future<DailyReminderSettings> resetReminderSettings({int? userId}) async {
    final res = await _client.post(
      '/api/pengaturan-pengingat/reset',
      body: {if (userId != null) 'userId': userId},
    );
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    return DailyReminderSettings.fromJson(data);
  }

  Future<Map<String, dynamic>> triggerTestNotification({
    String type = 'morning',
    int? userId,
  }) async {
    final res = await _client.post(
      '/api/notifikasi/test',
      body: {
        'type': type,
        if (userId != null) 'userId': userId,
      },
    );
    return (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
  }

  Future<List<Map<String, dynamic>>> getNotificationLogs({int? userId}) async {
    final res = await _client.get(
      '/api/notifikasi',
      queryParameters: {if (userId != null) 'userId': userId},
    );
    final rawList = res['data'] ?? res['logs'] ?? [];
    if (rawList is List) {
      return rawList.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  Future<List<DebtItem>> getDebts({
    String? status,
    String? type,
    int? userId,
  }) async {
    final res = await _client.get(
      '/api/debts',
      queryParameters: {
        if (status != null) 'status': status,
        if (type != null) 'type': type,
        if (userId != null) 'userId': userId,
      },
    );
    final rawList = res['data'] ?? res['debts'] ?? [];
    if (rawList is List) {
      return rawList
          .whereType<Map<String, dynamic>>()
          .map(DebtItem.fromJson)
          .toList();
    }
    return [];
  }

  Future<DebtItem> createDebt({
    required String name,
    required double totalAmount,
    required double remainingAmount,
    required DateTime dueDate,
    required DebtType type,
    String? notes,
    int? userId,
  }) async {
    final dueStr =
        '${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';
    final res = await _client.post(
      '/api/debts',
      body: {
        'name': name,
        'totalAmount': totalAmount,
        'remainingAmount': remainingAmount,
        'dueDate': dueStr,
        'type': type.apiValue,
        if (notes != null) 'notes': notes,
        if (userId != null) 'userId': userId,
      },
    );
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    return DebtItem.fromJson(data);
  }

  Future<DebtItem> updateDebt(
    String id, {
    String? name,
    double? totalAmount,
    double? remainingAmount,
    DateTime? dueDate,
    DebtType? type,
    String? status,
    String? notes,
  }) async {
    final cleanId = _extractId(id);
    final dueStr = dueDate != null
        ? '${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}'
        : null;
    final res = await _client.put(
      '/api/debts/$cleanId',
      body: {
        if (name != null) 'name': name,
        if (totalAmount != null) 'totalAmount': totalAmount,
        if (remainingAmount != null) 'remainingAmount': remainingAmount,
        if (dueStr != null) 'dueDate': dueStr,
        if (type != null) 'type': type.apiValue,
        if (status != null) 'status': status,
        if (notes != null) 'notes': notes,
      },
    );
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    return DebtItem.fromJson(data);
  }

  Future<DebtItem> markDebtAsPaid(String id) async {
    final cleanId = _extractId(id);
    final res = await _client.post('/api/debts/$cleanId/pay');
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    return DebtItem.fromJson(data);
  }

  Future<DebtItem> payDebt(
    String id, {
    double? amount,
    bool isFull = false,
    bool isFullPayment = false,
    String? notes,
  }) =>
      markDebtAsPaid(id);

  Future<DebtItem> reopenDebt(String id, {double? remainingAmount}) async {
    final cleanId = _extractId(id);
    final res = await _client.post(
      '/api/debts/$cleanId/reopen',
      body: {
        if (remainingAmount != null) 'remainingAmount': remainingAmount,
      },
    );
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    return DebtItem.fromJson(data);
  }

  Future<void> deleteDebt(String id) async {
    final cleanId = _extractId(id);
    await _client.delete('/api/debts/$cleanId');
  }

  String _extractId(String raw) {
    final match = RegExp(r'\d+').firstMatch(raw);
    return match != null ? match.group(0)! : raw;
  }
}
