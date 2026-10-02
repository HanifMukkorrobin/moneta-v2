import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_env.dart';

class MonetaApiException implements Exception {
  final int statusCode;
  final String message;
  final String? code;
  final Map<String, dynamic>? body;

  const MonetaApiException({
    required this.statusCode,
    required this.message,
    this.code,
    this.body,
  });

  @override
  String toString() => 'MonetaApiException($statusCode): $message';
}

class MonetaApiClient {
  MonetaApiClient._internal();

  static final MonetaApiClient instance = MonetaApiClient._internal();

  http.Client _httpClient = http.Client();
  String? _authToken;
  int? _userId;
  String? _baseUrlOverride;

  /// Inject a custom [http.Client] (e.g., `MockClient` in widget/unit tests).
  void setHttpClient(http.Client client) {
    _httpClient = client;
  }

  void setAuthSession({String? token, int? userId}) {
    _authToken = token;
    _userId = userId;
  }

  void setAuthToken(String? token) {
    _authToken = token;
  }

  void setUserId(dynamic userId) {
    if (userId == null) {
      _userId = null;
    } else if (userId is int) {
      _userId = userId;
    } else {
      _userId = int.tryParse(userId.toString());
    }
  }

  void clearAuthSession() {
    _authToken = null;
    _userId = null;
  }

  String? get authToken => _authToken;
  int? get userId => _userId;

  String get baseUrl {
    final raw = _baseUrlOverride ?? AppEnv.apiBaseUrl;
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  set baseUrlOverride(String? url) {
    _baseUrlOverride = url;
  }

  Duration get timeout => Duration(milliseconds: AppEnv.apiTimeoutMs);

  Map<String, String> _buildHeaders([Map<String, String>? extraHeaders]) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    if (_userId != null) {
      headers['X-User-Id'] = _userId.toString();
    }
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    return headers;
  }

  Uri _buildUri(String path, [Map<String, dynamic>? queryParameters]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$baseUrl$normalizedPath');
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }
    final cleanQuery = <String, String>{};
    queryParameters.forEach((key, value) {
      if (value != null) {
        cleanQuery[key] = value.toString();
      }
    });
    return uri.replace(queryParameters: cleanQuery);
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, queryParameters);
    final response = await _httpClient
        .get(uri, headers: _buildHeaders(headers))
        .timeout(timeout);
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, queryParameters);
    final payload = body != null ? jsonEncode(body) : jsonEncode(<String, dynamic>{});
    final response = await _httpClient
        .post(uri, headers: _buildHeaders(headers), body: payload)
        .timeout(timeout);
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, queryParameters);
    final payload = body != null ? jsonEncode(body) : jsonEncode(<String, dynamic>{});
    final response = await _httpClient
        .put(uri, headers: _buildHeaders(headers), body: payload)
        .timeout(timeout);
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, queryParameters);
    final payload = body != null ? jsonEncode(body) : jsonEncode(<String, dynamic>{});
    final response = await _httpClient
        .patch(uri, headers: _buildHeaders(headers), body: payload)
        .timeout(timeout);
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, queryParameters);
    final payload = body != null ? jsonEncode(body) : null;
    final response = await _httpClient
        .delete(uri, headers: _buildHeaders(headers), body: payload)
        .timeout(timeout);
    return _decodeResponse(response);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final rawBody = utf8.decode(response.bodyBytes);
    Map<String, dynamic> decoded = <String, dynamic>{};
    if (rawBody.trim().isNotEmpty) {
      final parsed = jsonDecode(rawBody);
      if (parsed is Map<String, dynamic>) {
        decoded = parsed;
      } else if (parsed is List) {
        decoded = <String, dynamic>{'data': parsed};
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final errorMessage = (decoded['error'] ??
            decoded['message'] ??
            'Permintaan gagal (${response.statusCode})')
        .toString();
    throw MonetaApiException(
      statusCode: response.statusCode,
      message: errorMessage,
      code: decoded['code']?.toString(),
      body: decoded,
    );
  }
}
