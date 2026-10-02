import 'package:flutter/material.dart';
import '../utils/currency_format.dart';

enum DebtType {
  paylater,
  cicilan,
  kartuKredit,
  pinjamanPribadi,
  lainnya;

  static DebtType fromString(String? value) {
    final lower = (value ?? '').trim().toLowerCase();
    switch (lower) {
      case 'cicilan':
        return DebtType.cicilan;
      case 'kartu_kredit':
      case 'kartukredit':
      case 'credit_card':
        return DebtType.kartuKredit;
      case 'pinjaman_pribadi':
      case 'pinjamanpribadi':
      case 'personal':
        return DebtType.pinjamanPribadi;
      case 'lainnya':
        return DebtType.lainnya;
      case 'paylater':
      default:
        return DebtType.paylater;
    }
  }

  String get apiValue {
    switch (this) {
      case DebtType.paylater:
        return 'paylater';
      case DebtType.cicilan:
        return 'cicilan';
      case DebtType.kartuKredit:
        return 'kartu_kredit';
      case DebtType.pinjamanPribadi:
        return 'pinjaman_pribadi';
      case DebtType.lainnya:
        return 'lainnya';
    }
  }

  String get label {
    switch (this) {
      case DebtType.paylater:
        return 'Paylater';
      case DebtType.cicilan:
        return 'Cicilan';
      case DebtType.kartuKredit:
        return 'Kartu Kredit';
      case DebtType.pinjamanPribadi:
        return 'Pinjaman Pribadi';
      case DebtType.lainnya:
        return 'Lainnya';
    }
  }

  IconData get icon {
    switch (this) {
      case DebtType.paylater:
        return Icons.shopping_cart_checkout_rounded;
      case DebtType.cicilan:
        return Icons.devices_rounded;
      case DebtType.kartuKredit:
        return Icons.credit_card_rounded;
      case DebtType.pinjamanPribadi:
        return Icons.handshake_rounded;
      case DebtType.lainnya:
        return Icons.receipt_long_rounded;
    }
  }

  Color get color {
    switch (this) {
      case DebtType.paylater:
        return const Color(0xFFF97316); // Orange
      case DebtType.cicilan:
        return const Color(0xFF0284C7); // Blue
      case DebtType.kartuKredit:
        return const Color(0xFF8B5CF6); // Purple
      case DebtType.pinjamanPribadi:
        return const Color(0xFF10B981); // Green
      case DebtType.lainnya:
        return const Color(0xFF64748B); // Slate
    }
  }
}

class DebtItem {
  final String id;
  final String name;
  final double totalAmount;
  final double remainingAmount;
  final DateTime dueDate;
  final String status; // 'active' / 'paid'
  final DebtType type;
  final String? notes;

  const DebtItem({
    required this.id,
    required this.name,
    required this.totalAmount,
    required this.remainingAmount,
    required this.dueDate,
    this.status = 'active',
    this.type = DebtType.paylater,
    this.notes,
  });

  bool get isPaid => status == 'paid' || remainingAmount <= 0;

  int get daysUntilDue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.difference(today).inDays;
  }

  bool get isDueSoon => !isPaid && daysUntilDue >= 0 && daysUntilDue <= 3;
  bool get isOverdue => !isPaid && daysUntilDue < 0;

  String get dueStatusLabel {
    if (isPaid) return 'Lunas';
    if (isOverdue) return 'Lewat Jatuh Tempo (${(-daysUntilDue)} hari)';
    if (daysUntilDue == 0) return 'Jatuh Tempo Hari Ini';
    if (daysUntilDue == 1) return 'Jatuh Tempo Besok';
    return '$daysUntilDue hari lagi';
  }

  Color get statusBadgeColor {
    if (isPaid) return const Color(0xFF10B981); // Emerald
    if (isOverdue) return const Color(0xFFEF4444); // Red
    if (isDueSoon) return const Color(0xFFF59E0B); // Amber
    return const Color(0xFF3B82F6); // Blue
  }

  String get formattedTotalAmount => CurrencyFormat.formatRupiah(totalAmount);
  String get formattedRemainingAmount =>
      CurrencyFormat.formatRupiah(remainingAmount);
  double get paidAmount => (totalAmount - remainingAmount).clamp(0, totalAmount);

  double get progressRatio =>
      totalAmount > 0 ? (paidAmount / totalAmount).clamp(0.0, 1.0) : 1.0;

  int get progressPercent => (progressRatio * 100).toInt();

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];

  String get formattedDueDate {
    final m = _monthNames[dueDate.month - 1];
    return '${dueDate.day} $m ${dueDate.year}';
  }

  DebtItem copyWith({
    String? id,
    String? name,
    double? totalAmount,
    double? remainingAmount,
    DateTime? dueDate,
    String? status,
    DebtType? type,
    String? notes,
  }) {
    return DebtItem(
      id: id ?? this.id,
      name: name ?? this.name,
      totalAmount: totalAmount ?? this.totalAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      type: type ?? this.type,
      notes: notes ?? this.notes,
    );
  }

  factory DebtItem.fromJson(Map<String, dynamic> json) {
    double toD(dynamic v) =>
        v is num ? v.toDouble() : (v != null ? (double.tryParse(v.toString()) ?? 0.0) : 0.0);

    final totalVal = toD(json['totalAmount'] ?? json['total_amount']);
    final remainingVal = json['remainingAmount'] != null || json['remaining_amount'] != null
        ? toD(json['remainingAmount'] ?? json['remaining_amount'])
        : totalVal;

    final rawDue = json['dueDate'] ?? json['due_date'];
    final parsedDue = rawDue != null
        ? (DateTime.tryParse(rawDue.toString()) ?? DateTime.now())
        : DateTime.now();

    final rawStatus = (json['status'] ?? 'active').toString().toLowerCase();
    final statusVal = (rawStatus == 'paid' || rawStatus == 'lunas' || remainingVal <= 0)
        ? 'paid'
        : 'active';

    return DebtItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      totalAmount: totalVal,
      remainingAmount: remainingVal,
      dueDate: parsedDue,
      status: statusVal,
      type: DebtType.fromString(json['type']?.toString()),
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    final dueStr =
        '${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';
    return {
      'id': id,
      'name': name,
      'totalAmount': totalAmount,
      'remainingAmount': remainingAmount,
      'dueDate': dueStr,
      'status': status,
      'type': type.apiValue,
      'notes': notes,
    };
  }

  static List<DebtItem> getInitialDebts() {
    final now = DateTime.now();
    return [
      DebtItem(
        id: 'debt_1',
        name: 'Paylater Belanja Online (Spay)',
        totalAmount: 1250000,
        remainingAmount: 450000,
        dueDate: now.add(const Duration(days: 2)),
        status: 'active',
        type: DebtType.paylater,
        notes: 'Belanja perlengkapan rumah & elektronik ringan',
      ),
      DebtItem(
        id: 'debt_2',
        name: 'Cicilan Laptop Kerja (Bulan 3/6)',
        totalAmount: 6000000,
        remainingAmount: 3000000,
        dueDate: now.add(const Duration(days: 12)),
        status: 'active',
        type: DebtType.cicilan,
        notes: 'Tenor 6 bulan cicilan 0% keperluan kantor',
      ),
      DebtItem(
        id: 'debt_3',
        name: 'Tagihan Kartu Kredit Bank BCA',
        totalAmount: 850000,
        remainingAmount: 850000,
        dueDate: now.add(const Duration(days: 1)),
        status: 'active',
        type: DebtType.kartuKredit,
        notes: 'Transaksi groceries & bensin pertengahan bulan',
      ),
      DebtItem(
        id: 'debt_4',
        name: 'Pinjaman Teman (Budi - Talangan)',
        totalAmount: 300000,
        remainingAmount: 0,
        dueDate: now.subtract(const Duration(days: 5)),
        status: 'paid',
        type: DebtType.pinjamanPribadi,
        notes: 'Talangan beli tiket kereta pulang kampung',
      ),
      DebtItem(
        id: 'debt_5',
        name: 'Paylater Tagihan Listrik (Kredivo)',
        totalAmount: 275000,
        remainingAmount: 0,
        dueDate: now.subtract(const Duration(days: 7)),
        status: 'paid',
        type: DebtType.paylater,
        notes: 'Token listrik PLN 500rb awal bulan',
      ),
    ];
  }
}
