import 'package:intl/intl.dart';

class CategoryConfirmationItem {
  final String id;
  final String rawSentence;
  String detectedCategory;
  final double confidenceScore;
  final String aiReasoning;
  String type; // 'expense' or 'income'
  final String typeReasoning;
  double amount;
  final DateTime occurredAt;
  bool isConfirmed;
  bool isCustomCategory;
  final List<String> alternativeCategories;

  CategoryConfirmationItem({
    required this.id,
    required this.rawSentence,
    required this.detectedCategory,
    required this.confidenceScore,
    required this.aiReasoning,
    required this.type,
    required this.typeReasoning,
    required this.amount,
    required this.occurredAt,
    this.isConfirmed = false,
    this.isCustomCategory = false,
    this.alternativeCategories = const [],
  });

  bool get isExpense => type == 'expense';
  bool get isIncome => type == 'income';

  String get formattedAmount {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  String get formattedConfidence {
    final pct = (confidenceScore * 100).round();
    return '$pct% Akurat';
  }

  String get confidenceLevel {
    if (confidenceScore >= 0.85) return 'high';
    if (confidenceScore >= 0.70) return 'medium';
    return 'low';
  }

  CategoryConfirmationItem copyWith({
    String? id,
    String? rawSentence,
    String? detectedCategory,
    double? confidenceScore,
    String? aiReasoning,
    String? type,
    String? typeReasoning,
    double? amount,
    DateTime? occurredAt,
    bool? isConfirmed,
    bool? isCustomCategory,
    List<String>? alternativeCategories,
  }) {
    return CategoryConfirmationItem(
      id: id ?? this.id,
      rawSentence: rawSentence ?? this.rawSentence,
      detectedCategory: detectedCategory ?? this.detectedCategory,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      aiReasoning: aiReasoning ?? this.aiReasoning,
      type: type ?? this.type,
      typeReasoning: typeReasoning ?? this.typeReasoning,
      amount: amount ?? this.amount,
      occurredAt: occurredAt ?? this.occurredAt,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      isCustomCategory: isCustomCategory ?? this.isCustomCategory,
      alternativeCategories:
          alternativeCategories ?? this.alternativeCategories,
    );
  }
}
