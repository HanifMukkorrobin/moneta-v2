import '../../models/ai_insight_item.dart';
import 'moneta_api_client.dart';

class DailyAdviceApiService {
  static final DailyAdviceApiService instance = DailyAdviceApiService();
  final MonetaApiClient _client;

  DailyAdviceApiService({MonetaApiClient? client})
      : _client = client ?? MonetaApiClient.instance;

  Future<AiInsightItem> getDailyAdvice({
    String? preset,
    bool forceRefresh = false,
    int? userId,
  }) async {
    final res = await _client.get(
      '/api/saran-harian',
      queryParameters: {
        if (preset != null) 'preset': preset,
        if (forceRefresh) 'refresh': 'true',
        if (userId != null) 'userId': userId,
      },
    );
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    return AiInsightItem.fromJson(data);
  }

  Future<AiInsightItem> applyDailyAdvice({
    String? date,
    int? userId,
  }) async {
    final res = await _client.post(
      '/api/saran-harian/apply',
      body: {
        if (date != null) 'date': date,
        if (userId != null) 'userId': userId,
      },
    );
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    return AiInsightItem.fromJson(data);
  }

  Future<AiInsightItem> refreshDailyAdvice({int? userId}) =>
      getDailyAdvice(forceRefresh: true, userId: userId);

  Future<AiInsightItem> refreshAdvice({int? userId}) =>
      refreshDailyAdvice(userId: userId);
}
