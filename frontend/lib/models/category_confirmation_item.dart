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

  factory CategoryConfirmationItem.fromJson(Map<String, dynamic> json) {
    final rawOccurred = json['occurredAt'] ??
        json['occurred_at'] ??
        json['createdAt'] ??
        json['created_at'];
    final parsedDate = rawOccurred != null
        ? (DateTime.tryParse(rawOccurred.toString()) ?? DateTime.now())
        : DateTime.now();

    final rawType = (json['type'] ?? 'expense').toString().toLowerCase() == 'income'
        ? 'income'
        : 'expense';

    final rawConfidence = json['confidenceScore'] ??
        json['confidence_score'] ??
        json['confidence'] ??
        0.9;
    final confidence = rawConfidence is num
        ? rawConfidence.toDouble()
        : (double.tryParse(rawConfidence.toString()) ?? 0.9);

    final rawAmount = json['amount'] ?? 0;
    final amountVal = rawAmount is num
        ? rawAmount.toDouble()
        : (double.tryParse(rawAmount.toString()) ?? 0.0);

    final rawConfirmed = json['isConfirmed'] ?? json['is_confirmed'];
    final isConfirmedVal = rawConfirmed == true || rawConfirmed == 1 || rawConfirmed == '1';

    final rawCustom = json['isCustomCategory'] ?? json['isCustom'] ?? json['is_custom'];
    final isCustomVal = rawCustom == true || rawCustom == 1 || rawCustom == '1';

    final rawAlts = json['alternativeCategories'] ?? json['alternative_categories'];
    final alts = rawAlts is List
        ? rawAlts.map((e) => e.toString()).toList()
        : (rawType == 'income'
            ? <String>['Gaji', 'Freelance', 'Bonus', 'Transfer Masuk']
            : <String>['Makan & Minuman', 'Transportasi', 'Belanja', 'Hiburan']);

    return CategoryConfirmationItem(
      id: (json['id'] ?? json['transactionId'] ?? '').toString(),
      rawSentence: (json['rawSentence'] ??
              json['raw_sentence'] ??
              json['rawText'] ??
              json['note'] ??
              '')
          .toString(),
      detectedCategory: (json['detectedCategory'] ??
              json['category'] ??
              json['category_name'] ??
              'Lainnya')
          .toString(),
      confidenceScore: confidence,
      aiReasoning: (json['aiReasoning'] ??
              json['ai_reasoning'] ??
              json['reasoning'] ??
              'Kategori hasil analisis AI')
          .toString(),
      type: rawType,
      typeReasoning: (json['typeReasoning'] ??
              json['type_reasoning'] ??
              (rawType == 'income'
                  ? 'Penerimaan dana pemasukan'
                  : 'Pengeluaran konsumsi/pembelian'))
          .toString(),
      amount: amountVal,
      occurredAt: parsedDate,
      isConfirmed: isConfirmedVal,
      isCustomCategory: isCustomVal,
      alternativeCategories: alts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rawSentence': rawSentence,
      'detectedCategory': detectedCategory,
      'confidenceScore': confidenceScore,
      'aiReasoning': aiReasoning,
      'type': type,
      'typeReasoning': typeReasoning,
      'amount': amount,
      'occurredAt': occurredAt.toIso8601String(),
      'isConfirmed': isConfirmed,
      'isCustomCategory': isCustomCategory,
      'alternativeCategories': alternativeCategories,
    };
  }

  static List<CategoryConfirmationItem> getInitialItems() {
    final now = DateTime.now();
    return [
      CategoryConfirmationItem(
        id: 'conf_1',
        rawSentence: 'Kopi kenangan mantan large 24rb',
        detectedCategory: 'Makan & Minuman',
        confidenceScore: 0.98,
        aiReasoning: 'Kata kunci "kopi kenangan" terdeteksi otomatis sebagai kategori konsumsi',
        type: 'expense',
        typeReasoning: 'Pembelian minuman konsumsi sehari-hari',
        amount: 24000,
        occurredAt: now.subtract(const Duration(minutes: 15)),
        isConfirmed: false,
        alternativeCategories: ['Jajan & Camilan', 'Kebutuhan Pribadi', 'Hiburan'],
      ),
      CategoryConfirmationItem(
        id: 'conf_2',
        rawSentence: 'Transfer gaji kantor PT Maju Jaya 8.500.000',
        detectedCategory: 'Gaji',
        confidenceScore: 0.99,
        aiReasoning: 'Kata "transfer gaji kantor" cocok dengan kategori pendapatan utama',
        type: 'income',
        typeReasoning: 'Penerimaan upah bulanan dari perusahaan',
        amount: 8500000,
        occurredAt: now.subtract(const Duration(hours: 2)),
        isConfirmed: false,
        alternativeCategories: ['Bonus', 'Transfer Masuk', 'Investasi'],
      ),
      CategoryConfirmationItem(
        id: 'conf_3',
        rawSentence: 'Bensin Shell Super isi motor 45rb',
        detectedCategory: 'Transportasi',
        confidenceScore: 0.96,
        aiReasoning: 'Kata "bensin shell" dan "motor" terdeteksi sebagai biaya transportasi',
        type: 'expense',
        typeReasoning: 'Pembelian bahan bakar kendaraan',
        amount: 45000,
        occurredAt: now.subtract(const Duration(hours: 4)),
        isConfirmed: false,
        alternativeCategories: ['Perawatan Kendaraan', 'Kebutuhan Rumah'],
      ),
      CategoryConfirmationItem(
        id: 'conf_4',
        rawSentence: 'Langganan Netflix Premium bulanan 186rb',
        detectedCategory: 'Hiburan',
        confidenceScore: 0.93,
        aiReasoning: 'Layanan streaming digital "Netflix" tergolong hiburan rekreatif',
        type: 'expense',
        typeReasoning: 'Biaya langganan platform hiburan',
        amount: 186000,
        occurredAt: now.subtract(const Duration(days: 1)),
        isConfirmed: true,
        alternativeCategories: ['Tagihan & Utilitas', 'Langganan Digital'],
      ),
      CategoryConfirmationItem(
        id: 'conf_5',
        rawSentence: 'Bayar tagihan listrik PLN rumah 210rb',
        detectedCategory: 'Tagihan & Utilitas',
        confidenceScore: 0.97,
        aiReasoning: 'Kata "tagihan listrik PLN" merupakan utilitas wajib rumah tangga',
        type: 'expense',
        typeReasoning: 'Pembayaran rutin fasilitas rumah',
        amount: 210000,
        occurredAt: now.subtract(const Duration(days: 1, hours: 3)),
        isConfirmed: true,
        alternativeCategories: ['Kebutuhan Rumah', 'Operasional'],
      ),
      CategoryConfirmationItem(
        id: 'conf_6',
        rawSentence: 'Fee freelance project redesign UI 1.250.000',
        detectedCategory: 'Freelance',
        confidenceScore: 0.94,
        aiReasoning: 'Kata "fee freelance" teridentifikasi sebagai penghasilan lepas',
        type: 'income',
        typeReasoning: 'Penerimaan upah proyek sampingan',
        amount: 1250000,
        occurredAt: now.subtract(const Duration(days: 2)),
        isConfirmed: false,
        alternativeCategories: ['Bonus', 'Bisnis Sampingan', 'Transfer Masuk'],
      ),
      CategoryConfirmationItem(
        id: 'conf_7',
        rawSentence: 'Transfer bayar urusan tadi siang 75rb',
        detectedCategory: 'Belum Dikategorikan',
        confidenceScore: 0.35,
        aiReasoning: 'Tebakan kategori gagal: kalimat tidak mengandung kata kunci yang spesifik',
        type: 'expense',
        typeReasoning: 'Kata "transfer bayar" terdeteksi sebagai pengeluaran',
        amount: 75000,
        occurredAt: now.subtract(const Duration(hours: 5)),
        isConfirmed: false,
        alternativeCategories: ['Belanja', 'Kebutuhan Rumah', 'Hiburan', 'Lainnya'],
      ),
    ];
  }
}
