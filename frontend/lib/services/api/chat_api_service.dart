import '../../models/chat_log_item.dart';
import '../../models/transaction_item.dart';
import 'moneta_api_client.dart';

class ChatParseResult {
  final bool success;
  final String? chatLogId;
  final TransactionItem? transaction;
  final String? errorMessage;

  const ChatParseResult({
    required this.success,
    this.chatLogId,
    this.transaction,
    this.errorMessage,
  });

  bool get isAiFailed => !success;
}

class ChatApiService {
  static final ChatApiService instance = ChatApiService();
  final MonetaApiClient _client;

  ChatApiService({MonetaApiClient? client})
      : _client = client ?? MonetaApiClient.instance;

  Future<ChatParseResult> parseChatMessage({
    required String message,
    int? userId,
  }) async {
    try {
      final res = await _client.post(
        '/api/chat/parse',
        body: {
          'message': message,
          if (userId != null) 'userId': userId,
        },
      );
      final data = (res['data'] is Map<String, dynamic>)
          ? res['data'] as Map<String, dynamic>
          : res;
      final chatLogId = (res['chatLogId'] ?? data['chatLogId'])?.toString();
      final txMap = data['transaction'] is Map<String, dynamic>
          ? data['transaction'] as Map<String, dynamic>
          : data;
      final tx = TransactionItem.fromJson(txMap);
      return ChatParseResult(
        success: true,
        chatLogId: chatLogId,
        transaction: tx,
      );
    } on MonetaApiException catch (e) {
      final body = e.body ?? <String, dynamic>{};
      return ChatParseResult(
        success: false,
        chatLogId: body['chatLogId']?.toString(),
        errorMessage: e.message,
      );
    }
  }

  Future<ChatParseResult> sendMessage({
    required String message,
    int? userId,
  }) =>
      parseChatMessage(message: message, userId: userId);

  Future<List<ChatLogItem>> getChatHistory({
    String? status,
    int? limit,
    int? userId,
  }) async {
    final res = await _client.get(
      '/api/chat/history',
      queryParameters: {
        if (status != null) 'status': status,
        if (limit != null) 'limit': limit,
        if (userId != null) 'userId': userId,
      },
    );
    final rawList = res['data'] ?? res['logs'] ?? res['history'] ?? [];
    if (rawList is List) {
      return rawList
          .whereType<Map<String, dynamic>>()
          .map(ChatLogItem.fromJson)
          .toList();
    }
    return [];
  }

  Future<void> deleteChatLog(String id) async {
    final cleanId = _extractId(id);
    await _client.delete('/api/chat/history/$cleanId');
  }

  Future<ChatLogItem?> restoreChatLog(String id) async {
    final cleanId = _extractId(id);
    final res = await _client.post('/api/chat/history/$cleanId/restore');
    final data = res['data'] ?? res['chatLog'];
    if (data is Map<String, dynamic>) {
      return ChatLogItem.fromJson(data);
    }
    return null;
  }

  String _extractId(String raw) {
    final match = RegExp(r'\d+').firstMatch(raw);
    return match != null ? match.group(0)! : raw;
  }
}
