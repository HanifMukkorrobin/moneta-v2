import '../../models/transaction_item.dart';
import 'moneta_api_client.dart';

class TransactionApiService {
  static final TransactionApiService instance = TransactionApiService();
  final MonetaApiClient _client;

  TransactionApiService({MonetaApiClient? client})
      : _client = client ?? MonetaApiClient.instance;

  Future<List<TransactionItem>> getTransactions({
    String? month,
    String? type,
    String? category,
    bool? isConfirmed,
    int? userId,
  }) async {
    final res = await _client.get(
      '/api/transactions',
      queryParameters: {
        if (month != null) 'month': month,
        if (type != null) 'type': type,
        if (category != null) 'category': category,
        if (isConfirmed != null) 'isConfirmed': isConfirmed,
        if (userId != null) 'userId': userId,
      },
    );
    final rawList = res['data'] ?? res['transactions'] ?? [];
    if (rawList is List) {
      return rawList
          .whereType<Map<String, dynamic>>()
          .map(TransactionItem.fromJson)
          .toList();
    }
    return [];
  }

  Future<TransactionItem> getTransactionDetail(String id) async {
    final cleanId = _extractId(id);
    final res = await _client.get('/api/transactions/$cleanId');
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    return TransactionItem.fromJson(data);
  }

  Future<TransactionItem> confirmTransaction({
    String? transactionId,
    String? note,
    double? amount,
    String? type,
    String? category,
    String? categoryName,
    DateTime? occurredAt,
    int? userId,
  }) async {
    final numericId = transactionId != null ? _tryParseNumericId(transactionId) : null;
    final effCategory = category ?? categoryName;
    final res = await _client.post(
      '/api/transactions/confirm',
      body: {
        if (numericId != null) 'transactionId': numericId,
        if (note != null) 'note': note,
        if (amount != null) 'amount': amount,
        if (type != null) 'type': type,
        if (effCategory != null) 'category': effCategory,
        if (occurredAt != null) 'occurredAt': occurredAt.toIso8601String(),
        if (userId != null) 'userId': userId,
      },
    );
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    return TransactionItem.fromJson(data);
  }

  Future<TransactionItem> createTransaction({
    String? type,
    double? amount,
    String? category,
    String? categoryName,
    String? note,
    DateTime? occurredAt,
    int? userId,
  }) =>
      confirmTransaction(
        type: type,
        amount: amount,
        category: category ?? categoryName,
        note: note,
        occurredAt: occurredAt,
        userId: userId,
      );

  Future<TransactionItem> updateTransaction(
    String id, {
    String? note,
    double? amount,
    String? type,
    String? category,
    String? categoryName,
    bool? isConfirmed,
    DateTime? occurredAt,
  }) async {
    final cleanId = _extractId(id);
    final effCategory = category ?? categoryName;
    final res = await _client.put(
      '/api/transactions/$cleanId',
      body: {
        if (note != null) 'note': note,
        if (amount != null) 'amount': amount,
        if (type != null) 'type': type,
        if (effCategory != null) 'category': effCategory,
        if (isConfirmed != null) 'isConfirmed': isConfirmed,
        if (occurredAt != null) 'occurredAt': occurredAt.toIso8601String(),
      },
    );
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    return TransactionItem.fromJson(data);
  }

  Future<TransactionItem> updateTransactionCategory(
    String id, {
    String? category,
    String? categoryName,
    String? type,
    bool isCustom = false,
  }) async {
    final cleanId = _extractId(id);
    final effCategory = category ?? categoryName ?? 'Lainnya';
    final res = await _client.put(
      '/api/transactions/$cleanId/category',
      body: {
        'category': effCategory,
        if (type != null) 'type': type,
        'isCustom': isCustom,
      },
    );
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    return TransactionItem.fromJson(data);
  }

  Future<TransactionItem> confirmTransactionCategory(
    String id, {
    String? category,
    String? categoryName,
    String? type,
    bool isCustom = false,
  }) =>
      updateTransactionCategory(
        id,
        category: category ?? categoryName,
        type: type,
        isCustom: isCustom,
      );

  Future<TransactionItem> switchTransactionType(
    String id, {
    required String type,
    String? category,
  }) async {
    final cleanId = _extractId(id);
    final res = await _client.put(
      '/api/transactions/$cleanId/type',
      body: {
        'type': type,
        if (category != null) 'category': category,
      },
    );
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    return TransactionItem.fromJson(data);
  }

  Future<void> deleteTransaction(String id) async {
    final cleanId = _extractId(id);
    await _client.delete('/api/transactions/$cleanId');
  }

  String _extractId(String raw) {
    final match = RegExp(r'\d+').firstMatch(raw);
    return match != null ? match.group(0)! : raw;
  }

  int? _tryParseNumericId(String raw) {
    final direct = int.tryParse(raw);
    if (direct != null) return direct;
    final match = RegExp(r'\d+').firstMatch(raw);
    return match != null ? int.tryParse(match.group(0)!) : null;
  }
}
