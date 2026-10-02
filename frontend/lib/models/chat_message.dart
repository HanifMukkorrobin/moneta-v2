import 'chat_log_item.dart';
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

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final rawTimestamp = json['timestamp'] ?? json['createdAt'] ?? json['created_at'];
    final parsedTimestamp = rawTimestamp != null
        ? (DateTime.tryParse(rawTimestamp.toString()) ?? DateTime.now())
        : DateTime.now();

    TransactionItem? tx;
    if (json['transaction'] is Map<String, dynamic>) {
      tx = TransactionItem.fromJson(json['transaction'] as Map<String, dynamic>);
    }

    return ChatMessage(
      id: (json['id'] ?? '').toString(),
      text: (json['text'] ?? json['message'] ?? '').toString(),
      isUser: json['isUser'] == true,
      timestamp: parsedTimestamp,
      transaction: tx,
      isAi: json['isAi'] == true || json['isUser'] == false,
      isAiFailed: json['isAiFailed'] == true || json['status'] == 'failed',
      failedRawText: json['failedRawText']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'transaction': transaction?.toJson(),
      'isAi': isAi,
      'isAiFailed': isAiFailed,
      'failedRawText': failedRawText,
    };
  }

  static ChatMessage createInitialWelcomeOnly() {
    return ChatMessage(
      id: 'msg_welcome',
      text:
          'Halo! Aku Moneta AI. 🤖✨\n\nCeritakan saja pengeluaran atau pemasukanmu seperti mengobrol biasa, contoh:\n• "Makan siang padang 25rb"\n• "Kopi latte 32rb"\n• "Gajian freelance 2.5jt"',
      isUser: false,
      timestamp: DateTime.now(),
      isAi: true,
    );
  }

  static List<ChatMessage> fromChatLog(ChatLogItem log) {
    final userMsg = ChatMessage(
      id: 'msg_user_${log.id}',
      text: log.message,
      isUser: true,
      timestamp: log.createdAt,
    );

    if (log.transaction != null) {
      final aiMsg = ChatMessage(
        id: 'msg_ai_${log.id}',
        text: log.status == ChatLogStatus.confirmed
            ? 'Transaksi sudah dicatat dan terkonfirmasi:'
            : 'AI berhasil mengenali transaksi. Konfirmasi untuk mencatat:',
        isUser: false,
        timestamp: log.createdAt.add(const Duration(milliseconds: 200)),
        isAi: true,
        transaction: log.transaction,
      );
      return [userMsg, aiMsg];
    } else if (log.status == ChatLogStatus.failed) {
      final aiFailMsg = ChatMessage(
        id: 'msg_ai_fail_${log.id}',
        text: 'AI belum dapat membaca format transaksi dari pesanmu.',
        isUser: false,
        timestamp: log.createdAt.add(const Duration(milliseconds: 200)),
        isAi: true,
        isAiFailed: true,
        failedRawText: log.message,
      );
      return [userMsg, aiFailMsg];
    }
    return [userMsg];
  }

  static List<ChatMessage> getInitialMessages() {
    final now = DateTime(2026, 9, 28, 12, 0);
    return [
      ChatMessage(
        id: 'msg_welcome',
        text:
            'Halo! Aku Moneta AI. 🤖✨\n\nCeritakan saja pengeluaran atau pemasukanmu seperti mengobrol biasa, contoh:\n• "Makan siang padang 25rb"\n• "Kopi latte 32rb"\n• "Gajian freelance 2.5jt"',
        isUser: false,
        timestamp: now.subtract(const Duration(minutes: 60)),
        isAi: true,
      ),
      ChatMessage(
        id: 'msg_u1',
        text: 'Makan siang ayam geprek 25rb',
        isUser: true,
        timestamp: now.subtract(const Duration(minutes: 45)),
      ),
      ChatMessage(
        id: 'msg_ai1',
        text: 'Siap! Transaksi sudah otomatis diparsing dan tersimpan:',
        isUser: false,
        timestamp: now.subtract(const Duration(minutes: 45)),
        isAi: true,
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
      ChatMessage(
        id: 'msg_u2',
        text: 'Bensin pertamax 50rb',
        isUser: true,
        timestamp: now.subtract(const Duration(minutes: 20)),
      ),
      ChatMessage(
        id: 'msg_ai2',
        text: 'Tercatat! Pengeluaran transportasi berhasil disimpan:',
        isUser: false,
        timestamp: now.subtract(const Duration(minutes: 20)),
        isAi: true,
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
      ChatMessage(
        id: 'msg_u3',
        text: 'Kopi americano 22rb',
        isUser: true,
        timestamp: now.subtract(const Duration(minutes: 5)),
      ),
      ChatMessage(
        id: 'msg_ai3',
        text:
            'AI mendeteksi pengeluaran baru. Silakan konfirmasi untuk menyimpan:',
        isUser: false,
        timestamp: now.subtract(const Duration(minutes: 5)),
        isAi: true,
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
    ];
  }
}
