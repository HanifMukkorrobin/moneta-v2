import 'package:intl/intl.dart';

class TransactionItem {
  final String id;
  String note;
  double amount;
  String type; // 'income' | 'expense'
  String category;
  DateTime occurredAt;
  bool isConfirmed;
  final double? confidenceScore;
  final String? aiReasoning;
  final bool isGuessedCategory;

  TransactionItem({
    required this.id,
    required this.note,
    required this.amount,
    required this.type,
    required this.category,
    required this.occurredAt,
    this.isConfirmed = false,
    this.confidenceScore,
    this.aiReasoning,
    this.isGuessedCategory = true,
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

  String get formattedConfidence {
    final score = confidenceScore ?? 0.95;
    return '${(score * 100).round()}% Akurat';
  }

  TransactionItem copyWith({
    String? id,
    String? note,
    double? amount,
    String? type,
    String? category,
    DateTime? occurredAt,
    bool? isConfirmed,
    double? confidenceScore,
    String? aiReasoning,
    bool? isGuessedCategory,
  }) {
    return TransactionItem(
      id: id ?? this.id,
      note: note ?? this.note,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      occurredAt: occurredAt ?? this.occurredAt,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      aiReasoning: aiReasoning ?? this.aiReasoning,
      isGuessedCategory: isGuessedCategory ?? this.isGuessedCategory,
    );
  }
}
