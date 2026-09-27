import 'transaction_item.dart';

enum ChatLogStatus {
  confirmed,
  pending,
  deleted,
  failed;

  String get label {
    switch (this) {
      case ChatLogStatus.confirmed:
        return 'Tersimpan';
      case ChatLogStatus.pending:
        return 'Menunggu';
      case ChatLogStatus.deleted:
        return 'Dibatalkan';
      case ChatLogStatus.failed:
        return 'Gagal';
    }
  }

  static ChatLogStatus fromString(String val) {
    switch (val.toLowerCase()) {
      case 'confirmed':
        return ChatLogStatus.confirmed;
      case 'pending':
        return ChatLogStatus.pending;
      case 'deleted':
        return ChatLogStatus.deleted;
      case 'failed':
        return ChatLogStatus.failed;
      default:
        return ChatLogStatus.confirmed;
    }
  }
}

class ChatLogItem {
  final String id;
  final String message;
  final String? parsedJson;
  final TransactionItem? transaction;
  ChatLogStatus status;
  final DateTime createdAt;

  ChatLogItem({
    required this.id,
    required this.message,
    this.parsedJson,
    this.transaction,
    required this.status,
    required this.createdAt,
  });

  bool get isConfirmed => status == ChatLogStatus.confirmed;
  bool get isPending => status == ChatLogStatus.pending;
  bool get isDeleted => status == ChatLogStatus.deleted;
  bool get isFailed => status == ChatLogStatus.failed;
}
