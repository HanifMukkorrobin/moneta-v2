import '../../models/budget_item.dart';
import 'moneta_api_client.dart';

class BudgetApiService {
  static final BudgetApiService instance = BudgetApiService();
  final MonetaApiClient _client;

  BudgetApiService({MonetaApiClient? client})
      : _client = client ?? MonetaApiClient.instance;

  Future<MonthlyBudgetSummary> getMonthlyBudget({
    String month = '2026-09',
    int? userId,
  }) async {
    final res = await _client.get(
      '/api/budgets',
      queryParameters: {
        'month': month,
        if (userId != null) 'userId': userId,
      },
    );
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    return MonthlyBudgetSummary.fromJson(data);
  }

  Future<MonthlyBudgetSummary> saveMonthlyBudget({
    required String month,
    required double totalBudget,
    required double needsPct,
    required double savingsPct,
    required double funPct,
    List<CategoryBudgetItem>? categoryBudgets,
    int? userId,
  }) async {
    final res = await _client.post(
      '/api/budgets',
      body: {
        'month': month,
        'totalBudget': totalBudget,
        'needsPercentage': needsPct,
        'savingsPercentage': savingsPct,
        'funPercentage': funPct,
        if (categoryBudgets != null)
          'categoryBudgets': categoryBudgets.map((c) => c.toJson()).toList(),
        if (userId != null) 'userId': userId,
      },
    );
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    return MonthlyBudgetSummary.fromJson(data);
  }

  Future<MonthlyBudgetSummary> upsertBudgetLimit({
    required String month,
    required double totalBudget,
    double needsPct = 50,
    double savingsPct = 30,
    double funPct = 20,
    int? userId,
  }) =>
      saveMonthlyBudget(
        month: month,
        totalBudget: totalBudget,
        needsPct: needsPct,
        savingsPct: savingsPct,
        funPct: funPct,
        userId: userId,
      );

  Future<MonthlyBudgetSummary> updateAllocations({
    required String month,
    required double needsPercentage,
    required double savingsPercentage,
    required double funPercentage,
    double totalBudget = 6000000,
    int? userId,
  }) =>
      saveMonthlyBudget(
        month: month,
        totalBudget: totalBudget,
        needsPct: needsPercentage,
        savingsPct: savingsPercentage,
        funPct: funPercentage,
        userId: userId,
      );

  Future<MonthlyBudgetSummary> deleteBudgetLimit(
    String month, {
    int? userId,
  }) =>
      resetMonthlyBudget(month: month, userId: userId);

  Future<MonthlyBudgetSummary> resetMonthlyBudget({
    required String month,
    int? userId,
  }) async {
    final res = await _client.post(
      '/api/budgets/reset',
      body: {
        'month': month,
        if (userId != null) 'userId': userId,
      },
    );
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    return MonthlyBudgetSummary.fromJson(data);
  }
}
