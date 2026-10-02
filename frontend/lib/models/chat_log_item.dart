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

  factory ChatLogItem.fromJson(Map<String, dynamic> json) {
    final rawCreatedAt = json['createdAt'] ?? json['created_at'];
    final parsedDate = rawCreatedAt != null
        ? (DateTime.tryParse(rawCreatedAt.toString()) ?? DateTime.now())
        : DateTime.now();

    final statusStr = (json['status'] ?? 'confirmed').toString();
    final statusEnum = ChatLogStatus.fromString(statusStr);

    TransactionItem? tx;
    if (json['transaction'] is Map<String, dynamic>) {
      tx = TransactionItem.fromJson(json['transaction'] as Map<String, dynamic>);
    } else if (json['transaction_id'] != null || json['amount'] != null) {
      final amountVal = json['amount'];
      if (amountVal != null) {
        tx = TransactionItem.fromJson({
          'id': json['transaction_id'] ?? json['transactionId'] ?? json['id'],
          'note': json['note'] ?? json['raw_text'] ?? json['message'] ?? '',
          'amount': amountVal,
          'type': json['type'] ?? 'expense',
          'category': json['category_name'] ?? json['category'] ?? 'Lainnya',
          'occurredAt': json['occurred_at'] ?? rawCreatedAt,
          'isConfirmed': statusEnum == ChatLogStatus.confirmed,
        });
      }
    }

    String? parsedJsonStr;
    final rawParsed = json['parsedJson'] ?? json['parsed_json'];
    if (rawParsed is String) {
      parsedJsonStr = rawParsed;
    } else if (rawParsed != null) {
      parsedJsonStr = rawParsed.toString();
    }

    return ChatLogItem(
      id: (json['id'] ?? '').toString(),
      message: (json['message'] ?? json['raw_text'] ?? json['rawText'] ?? '').toString(),
      parsedJson: parsedJsonStr,
      transaction: tx,
      status: statusEnum,
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message': message,
      'parsedJson': parsedJson,
      'transaction': transaction?.toJson(),
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static List<ChatLogItem> getInitialChatLogs() {
    final now = DateTime(2026, 9, 28, 12, 0);
    return [
      ChatLogItem(
        id: 'log_1',
        message: 'Makan siang ayam geprek 25rb',
        status: ChatLogStatus.confirmed,
        createdAt: now.subtract(const Duration(minutes: 45)),
        transaction: TransactionItem(
          id: 'tx_1',
          note: 'Makan siang ayam geprek',
          amount: 25000,
          type: 'expense',
          category: 'Makan & Minuman',
          occurredAt: now.subtract(const Duration(minutes: 45)),
          isConfirmed: true,
        ),
      ),
      ChatLogItem(
        id: 'log_2',
        message: 'Bensin pertamax 50rb',
        status: ChatLogStatus.confirmed,
        createdAt: now.subtract(const Duration(minutes: 20)),
        transaction: TransactionItem(
          id: 'tx_2',
          note: 'Bensin pertamax',
          amount: 50000,
          type: 'expense',
          category: 'Transportasi',
          occurredAt: now.subtract(const Duration(minutes: 20)),
          isConfirmed: true,
        ),
      ),
      ChatLogItem(
        id: 'log_3',
        message: 'Kopi americano 22rb',
        status: ChatLogStatus.pending,
        createdAt: now.subtract(const Duration(minutes: 5)),
        transaction: TransactionItem(
          id: 'tx_3',
          note: 'Kopi americano',
          amount: 22000,
          type: 'expense',
          category: 'Makan & Minuman',
          occurredAt: now.subtract(const Duration(minutes: 5)),
          isConfirmed: false,
        ),
      ),
      ChatLogItem(
        id: 'log_4',
        message: 'Gajian freelance 2.5jt',
        status: ChatLogStatus.confirmed,
        createdAt: now.subtract(const Duration(hours: 3)),
        transaction: TransactionItem(
          id: 'tx_4',
          note: 'Gajian freelance',
          amount: 2500000,
          type: 'income',
          category: 'Freelance',
          occurredAt: now.subtract(const Duration(hours: 3)),
          isConfirmed: true,
        ),
      ),
      ChatLogItem(
        id: 'log_5',
        message: 'Beli baju kemeja kerja 185rb',
        status: ChatLogStatus.deleted,
        createdAt: now.subtract(const Duration(hours: 6)),
        transaction: TransactionItem(
          id: 'tx_5',
          note: 'Beli baju kemeja kerja',
          amount: 185000,
          type: 'expense',
          category: 'Belanja',
          occurredAt: now.subtract(const Duration(hours: 6)),
          isConfirmed: false,
        ),
      ),
      ChatLogItem(
        id: 'log_6',
        message: 'error tidak jelas',
        status: ChatLogStatus.failed,
        createdAt: now.subtract(const Duration(hours: 12)),
      ),
    ];
  }
}
