import '../../models/monthly_rekap_data.dart';
import '../../utils/category_icon_mapper.dart';
import 'moneta_api_client.dart';

class RekapApiService {
  static final RekapApiService instance = RekapApiService();
  final MonetaApiClient _client;

  RekapApiService({MonetaApiClient? client})
      : _client = client ?? MonetaApiClient.instance;

  Future<MonthlyRekapData> getMonthlyRekap({
    String month = '2026-09',
    int? userId,
  }) async {
    final res = await _client.get(
      '/api/rekap',
      queryParameters: {
        'month': month,
        if (userId != null) 'userId': userId,
      },
    );
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    return MonthlyRekapData.fromJson(data);
  }

  Future<MonthlyRekapData> getMonthlyRecap(
    String month, {
    int? userId,
  }) =>
      getMonthlyRekap(month: month, userId: userId);

  Future<List<String>> getAvailableMonths({int? userId}) async {
    try {
      final res = await _client.get(
        '/api/rekap/months',
        queryParameters: {if (userId != null) 'userId': userId},
      );
      final rawMonths = res['data'] ?? res['months'] ?? [];
      if (rawMonths is List && rawMonths.isNotEmpty) {
        return rawMonths.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return CategoryIconMapper.availableMonths;
  }
}
