import '../../models/category_confirmation_item.dart';
import '../../models/category_item.dart';
import '../../models/category_usage.dart';
import 'moneta_api_client.dart';

class CategoryApiService {
  static final CategoryApiService instance = CategoryApiService();
  final MonetaApiClient _client;

  CategoryApiService({MonetaApiClient? client})
      : _client = client ?? MonetaApiClient.instance;

  Future<List<CategoryItem>> getCategories({
    String? type,
    int? userId,
  }) async {
    final res = await _client.get(
      '/api/categories',
      queryParameters: {
        if (type != null) 'type': type,
        if (userId != null) 'userId': userId,
      },
    );
    final rawList = res['data'] ?? res['categories'] ?? [];
    if (rawList is List) {
      return rawList
          .whereType<Map<String, dynamic>>()
          .map(CategoryItem.fromJson)
          .toList();
    }
    return [];
  }

  Future<List<CategoryUsage>> getCategoryUsageStats({int? userId}) async {
    final res = await _client.get(
      '/api/categories/stats',
      queryParameters: {if (userId != null) 'userId': userId},
    );
    final rawList = res['data'] ?? res['stats'] ?? [];
    if (rawList is List) {
      return rawList
          .whereType<Map<String, dynamic>>()
          .map(CategoryUsage.fromJson)
          .toList();
    }
    return [];
  }

  Future<CategoryItem> createCategory({
    required String name,
    required String type,
    int? userId,
  }) async {
    final res = await _client.post(
      '/api/categories',
      body: {
        'name': name,
        'type': type,
        if (userId != null) 'userId': userId,
      },
    );
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    return CategoryItem.fromJson(data);
  }

  Future<CategoryItem> updateCategory(
    String id, {
    required String name,
    String type = 'expense',
  }) async {
    final cleanId = _extractId(id);
    final res = await _client.put(
      '/api/categories/$cleanId',
      body: {
        'name': name,
        'type': type,
      },
    );
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    return CategoryItem.fromJson(data);
  }

  Future<void> deleteCategory(String id) async {
    final cleanId = _extractId(id);
    await _client.delete('/api/categories/$cleanId');
  }

  Future<CategoryConfirmationItem> classifySentence({
    required String text,
    String? type,
    int? userId,
  }) async {
    final res = await _client.post(
      '/api/categories/classify',
      body: {
        'text': text,
        if (type != null) 'type': type,
        if (userId != null) 'userId': userId,
      },
    );
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    return CategoryConfirmationItem.fromJson(data);
  }

  String _extractId(String raw) {
    final match = RegExp(r'\d+').firstMatch(raw);
    return match != null ? match.group(0)! : raw;
  }
}
