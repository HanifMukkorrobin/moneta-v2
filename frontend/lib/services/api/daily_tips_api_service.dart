import '../../models/saving_tip_item.dart';
import 'moneta_api_client.dart';

class DailyTipsApiService {
  static final DailyTipsApiService instance = DailyTipsApiService();
  final MonetaApiClient _client;

  DailyTipsApiService({MonetaApiClient? client})
      : _client = client ?? MonetaApiClient.instance;

  Future<List<SavingTipItem>> getDailyTips({
    String? category,
    String? impactLevel,
    int? userId,
  }) async {
    final res = await _client.get(
      '/api/tips',
      queryParameters: {
        if (category != null && category != 'Semua') 'category': category,
        if (impactLevel != null && impactLevel != 'Semua')
          'impactLevel': impactLevel,
        if (userId != null) 'userId': userId,
      },
    );
    final rawList = res['data'] ?? res['tips'] ?? [];
    if (rawList is List) {
      return rawList
          .whereType<Map<String, dynamic>>()
          .map(SavingTipItem.fromJson)
          .toList();
    }
    return [];
  }

  Future<List<SavingTipItem>> getTipsHistory({
    String? filter,
    String? category,
    int? userId,
  }) async {
    final res = await _client.get(
      '/api/riwayat-tips',
      queryParameters: {
        if (filter != null) 'filter': filter,
        if (category != null && category != 'Semua') 'category': category,
        if (userId != null) 'userId': userId,
      },
    );
    final data = res['data'];
    final rawList = (data is Map<String, dynamic>)
        ? (data['history'] ?? data['tips'] ?? [])
        : (data ?? res['history'] ?? res['tips'] ?? []);
    if (rawList is List) {
      return rawList
          .whereType<Map<String, dynamic>>()
          .map(SavingTipItem.fromJson)
          .toList();
    }
    return [];
  }

  Future<SavingTipItem> toggleApplyTip(
    String tipId, {
    bool isApplied = true,
    int? userId,
  }) async {
    final cleanId = _extractId(tipId);
    final res = await _client.post(
      '/api/tips/$cleanId/apply',
      body: {
        'isApplied': isApplied,
        if (userId != null) 'userId': userId,
      },
    );
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    final tipMap = (data['tip'] is Map<String, dynamic>)
        ? data['tip'] as Map<String, dynamic>
        : data;
    return SavingTipItem.fromJson(tipMap);
  }

  Future<SavingTipItem> toggleTipStatus(
    String tipId, {
    bool isApplied = true,
    int? userId,
  }) =>
      toggleApplyTip(tipId, isApplied: isApplied, userId: userId);

  Future<List<SavingTipItem>> generateNewAiTips({
    String? topCategory,
    double? totalSpent,
    int? userId,
  }) async {
    final res = await _client.post(
      '/api/tips/generate',
      body: {
        if (topCategory != null) 'topCategory': topCategory,
        if (totalSpent != null) 'totalSpent': totalSpent,
        if (userId != null) 'userId': userId,
      },
    );
    final rawList = res['data'] ?? res['tips'] ?? [];
    if (rawList is List) {
      return rawList
          .whereType<Map<String, dynamic>>()
          .map(SavingTipItem.fromJson)
          .toList();
    }
    return [];
  }

  String _extractId(String raw) {
    final match = RegExp(r'\d+').firstMatch(raw);
    return match != null ? match.group(0)! : raw;
  }
}
