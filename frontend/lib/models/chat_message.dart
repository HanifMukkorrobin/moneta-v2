import 'transaction_item.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  TransactionItem? transaction;
  final bool isAi;
  final bool isAiFailed;
  final String? failedRawText;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.transaction,
    this.isAi = false,
    this.isAiFailed = false,
    this.failedRawText,
  });
}
