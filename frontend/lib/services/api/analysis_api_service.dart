import '../../models/ai_insight_item.dart';
import '../../models/daily_spending_item.dart';
import 'moneta_api_client.dart';

class FinancialAnalysisBundle {
  final AiInsightItem insight;
  final DailySpendingAnalysis dailySpending;

  const FinancialAnalysisBundle({
    required this.insight,
    required this.dailySpending,
  });
}

class AnalysisApiService {
  static final AnalysisApiService instance = AnalysisApiService();
  final MonetaApiClient _client;

  AnalysisApiService({MonetaApiClient? client})
      : _client = client ?? MonetaApiClient.instance;

  Future<FinancialAnalysisBundle> getFinancialAnalysis({
    String? preset,
    bool forceRefresh = false,
    int? userId,
  }) async {
    final res = await _client.get(
      '/api/analisa',
      queryParameters: {
        if (preset != null) 'preset': preset,
        if (forceRefresh) 'refresh': 'true',
        if (userId != null) 'userId': userId,
      },
    );
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;

    final insightMap = (data['insight'] is Map<String, dynamic>)
        ? data['insight'] as Map<String, dynamic>
        : data;
    final dailyMap = (data['dailyAnalysis'] is Map<String, dynamic>)
        ? data['dailyAnalysis'] as Map<String, dynamic>
        : ((data['dailySpending'] is Map<String, dynamic>)
            ? data['dailySpending'] as Map<String, dynamic>
            : data);

    return FinancialAnalysisBundle(
      insight: AiInsightItem.fromJson(insightMap),
      dailySpending: DailySpendingAnalysis.fromJson(dailyMap),
    );
  }

  Future<DailySpendingAnalysis> getDailySpendingAverage({
    String? preset,
    int? userId,
  }) async {
    final res = await _client.get(
      '/api/analisa/rata-rata-harian',
      queryParameters: {
        if (preset != null) 'preset': preset,
        if (userId != null) 'userId': userId,
      },
    );
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    return DailySpendingAnalysis.fromJson(data);
  }

  Future<FinancialAnalysisBundle> getFinancialOverview({
    String? preset,
    int? userId,
  }) =>
      getFinancialAnalysis(preset: preset, userId: userId);

  Future<FinancialAnalysisBundle> getAnalysisSummary({
    String? preset,
    int? userId,
  }) =>
      getFinancialAnalysis(preset: preset, userId: userId);

  Future<DailySpendingAnalysis> recalculateAnalysis({int? userId}) async {
    final res = await _client.post(
      '/api/analisa/recalculate',
      body: {if (userId != null) 'userId': userId},
    );
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    final dailyMap = (data['dailyAnalysis'] is Map<String, dynamic>)
        ? data['dailyAnalysis'] as Map<String, dynamic>
        : ((data['dailySpending'] is Map<String, dynamic>)
            ? data['dailySpending'] as Map<String, dynamic>
            : data);
    return DailySpendingAnalysis.fromJson(dailyMap);
  }
}
