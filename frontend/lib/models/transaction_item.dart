import 'package:intl/intl.dart';

class TransactionItem {
  final String id;
  final String note;
  final double amount;
  String type; // 'income' | 'expense'
  String category;
  final DateTime occurredAt;
  bool isConfirmed;

  TransactionItem({
    required this.id,
    required this.note,
    required this.amount,
    required this.type,
    required this.category,
    required this.occurredAt,
    this.isConfirmed = false,
  });

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';

  String get formattedAmount {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final prefix = isIncome ? '+ ' : '- ';
    return '$prefix${formatter.format(amount)}';
  }

  String get timeFormatted {
    return DateFormat('HH:mm').format(occurredAt);
  }

  TransactionItem copyWith({
    String? id,
    String? note,
    double? amount,
    String? type,
    String? category,
    DateTime? occurredAt,
    bool? isConfirmed,
  }) {
    return TransactionItem(
      id: id ?? this.id,
      note: note ?? this.note,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      occurredAt: occurredAt ?? this.occurredAt,
      isConfirmed: isConfirmed ?? this.isConfirmed,
    );
  }
}
