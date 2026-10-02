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
  bool isCustomCategory;

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
    this.isCustomCategory = false,
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
    bool? isCustomCategory,
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
      isCustomCategory: isCustomCategory ?? this.isCustomCategory,
    );
  }

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['transactionId'] ?? json['transaction_id'] ?? '';
    final rawAmount = json['amount'] ?? 0;
    final rawType = (json['type'] ?? 'expense').toString().toLowerCase();
    final rawCategory = (json['category'] ??
            json['categoryName'] ??
            json['category_name'] ??
            'Lainnya')
        .toString();
    final rawOccurred = json['occurredAt'] ??
        json['occurred_at'] ??
        json['createdAt'] ??
        json['created_at'];
    final parsedDate = rawOccurred != null
        ? (DateTime.tryParse(rawOccurred.toString()) ?? DateTime.now())
        : DateTime.now();

    final rawConfirmed = json['isConfirmed'] ?? json['is_confirmed'];
    final isConfirmedVal = rawConfirmed is bool
        ? rawConfirmed
        : (rawConfirmed == 1 || rawConfirmed == '1' || rawConfirmed == 'true');

    final rawGuessed = json['isGuessedCategory'] ??
        json['isGuessed'] ??
        json['is_guessed'];
    final isGuessedVal = rawGuessed == null
        ? true
        : (rawGuessed is bool
            ? rawGuessed
            : (rawGuessed == 1 || rawGuessed == '1' || rawGuessed == 'true'));

    final rawCustom = json['isCustomCategory'] ??
        json['isCustom'] ??
        json['is_custom'];
    final isCustomVal = rawCustom is bool
        ? rawCustom
        : (rawCustom == 1 || rawCustom == '1' || rawCustom == 'true');

    final rawConfidence = json['confidenceScore'] ??
        json['confidence_score'] ??
        json['confidence'];

    return TransactionItem(
      id: rawId.toString(),
      note: (json['note'] ?? json['rawText'] ?? json['raw_text'] ?? '').toString(),
      amount: (rawAmount is num)
          ? rawAmount.toDouble()
          : (double.tryParse(rawAmount.toString()) ?? 0.0),
      type: rawType == 'income' ? 'income' : 'expense',
      category: rawCategory,
      occurredAt: parsedDate,
      isConfirmed: isConfirmedVal,
      confidenceScore: rawConfidence is num
          ? rawConfidence.toDouble()
          : (rawConfidence != null ? double.tryParse(rawConfidence.toString()) : null),
      aiReasoning: (json['aiReasoning'] ??
              json['ai_reasoning'] ??
              json['reasoning'])
          ?.toString(),
      isGuessedCategory: isGuessedVal,
      isCustomCategory: isCustomVal,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'note': note,
      'amount': amount,
      'type': type,
      'category': category,
      'occurredAt': occurredAt.toIso8601String(),
      'isConfirmed': isConfirmed,
      'confidenceScore': confidenceScore,
      'aiReasoning': aiReasoning,
      'isGuessedCategory': isGuessedCategory,
      'isCustomCategory': isCustomCategory,
    };
  }

  static TransactionItem? parseTextOrNull(String input) {
    final lower = input.toLowerCase().trim();
    if (lower.contains('gagal') ||
        lower.contains('error') ||
        lower.contains('rusak') ||
        lower == 'halo' ||
        lower == 'test' ||
        lower == 'bingung') {
      return null;
    }
    final hasNumber = RegExp(r'\d').hasMatch(lower);
    if (!hasNumber) {
      return null;
    }
    return parseText(input);
  }

  static TransactionItem parseText(String input) {
    final lower = input.toLowerCase();
    bool isIncome = lower.contains('gaji') ||
        lower.contains('terima') ||
        lower.contains('bonus') ||
        lower.contains('freelance') ||
        lower.contains('transfer masuk') ||
        lower.contains('dapat');

    String type = isIncome ? 'income' : 'expense';
    String category = 'Lainnya';
    if (isIncome) {
      if (lower.contains('gaji')) {
        category = 'Gaji';
      } else if (lower.contains('freelance')) {
        category = 'Freelance';
      } else if (lower.contains('bonus')) {
        category = 'Bonus';
      } else if (lower.contains('invest')) {
        category = 'Investasi';
      } else {
        category = 'Transfer Masuk';
      }
    } else {
      if (lower.contains('kopi') ||
          lower.contains('makan') ||
          lower.contains('minum') ||
          lower.contains('ayam') ||
          lower.contains('padang') ||
          lower.contains('bakso') ||
          lower.contains('mie') ||
          lower.contains('soto') ||
          lower.contains('sarapan') ||
          lower.contains('snack')) {
        category = 'Makan & Minuman';
      } else if (lower.contains('bensin') ||
          lower.contains('pertamax') ||
          lower.contains('ojol') ||
          lower.contains('grab') ||
          lower.contains('gojek') ||
          lower.contains('parkir') ||
          lower.contains('toll') ||
          lower.contains('kereta')) {
        category = 'Transportasi';
      } else if (lower.contains('baju') ||
          lower.contains('sepatu') ||
          lower.contains('beli') ||
          lower.contains('shopee') ||
          lower.contains('tokped')) {
        category = 'Belanja';
      } else if (lower.contains('nonton') ||
          lower.contains('bioskop') ||
          lower.contains('game') ||
          lower.contains('hiburan') ||
          lower.contains('steam')) {
        category = 'Hiburan';
      } else if (lower.contains('listrik') ||
          lower.contains('wifi') ||
          lower.contains('air') ||
          lower.contains('pulsa') ||
          lower.contains('kuota')) {
        category = 'Tagihan & Utilitas';
      } else if (lower.contains('hutang') ||
          lower.contains('paylater') ||
          lower.contains('spaylater') ||
          lower.contains('cicilan')) {
        category = 'Hutang & Paylater';
      } else if (lower.contains('obat') || lower.contains('dokter')) {
        category = 'Kesehatan';
      }
    }

    double amount = 20000;
    final jtRegex = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:jt|juta)');
    final jtMatch = jtRegex.firstMatch(lower);
    if (jtMatch != null) {
      final numStr = jtMatch.group(1)!.replaceAll(',', '.');
      amount = (double.tryParse(numStr) ?? 1) * 1000000;
    } else {
      final rbRegex = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:rb|ribu|k)');
      final rbMatch = rbRegex.firstMatch(lower);
      if (rbMatch != null) {
        final numStr = rbMatch.group(1)!.replaceAll(',', '.');
        amount = (double.tryParse(numStr) ?? 1) * 1000;
      } else {
        final numRegex = RegExp(r'(\d{4,})');
        final numMatch = numRegex.firstMatch(
          lower.replaceAll('.', '').replaceAll(',', ''),
        );
        if (numMatch != null) {
          amount = double.tryParse(numMatch.group(1)!) ?? 20000;
        }
      }
    }

    return TransactionItem(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      note: input.trim(),
      amount: amount,
      type: type,
      category: category,
      occurredAt: DateTime.now(),
      isConfirmed: false,
      confidenceScore: category != 'Lainnya' ? 0.96 : 0.72,
      aiReasoning: 'Kata kunci terdeteksi cocok dengan kategori $category',
    );
  }
}
