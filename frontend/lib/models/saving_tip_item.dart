import 'package:flutter/material.dart';
import '../utils/category_icon_mapper.dart';
import '../utils/currency_format.dart';

class SavingTipItem {
  final String id;
  final String title;
  final String category;
  final String description;
  final double potentialSaving;
  final String impactLevel; // 'Tinggi', 'Sedang', 'Ringan'
  final IconData icon;
  final bool isApplied;
  final String actionText;

  final String? date;
  final DateTime? appliedAt;

  const SavingTipItem({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.potentialSaving,
    this.impactLevel = 'Sedang',
    this.icon = Icons.lightbulb_outline_rounded,
    this.isApplied = false,
    this.actionText = 'Terapkan Hari Ini',
    this.date,
    this.appliedAt,
  });

  String get formattedPotentialSaving =>
      CurrencyFormat.formatRupiah(potentialSaving);

  Color get impactColor {
    switch (impactLevel.toLowerCase()) {
      case 'tinggi':
        return const Color(0xFF10B981); // Emerald Green
      case 'sedang':
        return const Color(0xFF3B82F6); // Blue
      case 'ringan':
      default:
        return const Color(0xFF8B5CF6); // Purple
    }
  }

  SavingTipItem copyWith({
    String? id,
    String? title,
    String? category,
    String? description,
    double? potentialSaving,
    String? impactLevel,
    IconData? icon,
    bool? isApplied,
    String? actionText,
    String? date,
    DateTime? appliedAt,
  }) {
    return SavingTipItem(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      description: description ?? this.description,
      potentialSaving: potentialSaving ?? this.potentialSaving,
      impactLevel: impactLevel ?? this.impactLevel,
      icon: icon ?? this.icon,
      isApplied: isApplied ?? this.isApplied,
      actionText: actionText ?? this.actionText,
      date: date ?? this.date,
      appliedAt: appliedAt ?? this.appliedAt,
    );
  }

  factory SavingTipItem.fromJson(Map<String, dynamic> json) {
    final cat = (json['category'] ?? 'Umum').toString();
    final rawSaving = json['potentialSaving'] ?? json['potential_saving'] ?? 50000;
    final savingVal = rawSaving is num
        ? rawSaving.toDouble()
        : (double.tryParse(rawSaving.toString()) ?? 50000.0);

    final rawApplied = json['isApplied'] ?? json['is_applied'];
    final isAppliedVal = rawApplied == true || rawApplied == 1 || rawApplied == '1';

    final rawAppliedAt = json['appliedAt'] ?? json['applied_at'];
    final parsedAppliedAt = rawAppliedAt != null
        ? DateTime.tryParse(rawAppliedAt.toString())
        : null;

    return SavingTipItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      category: cat,
      description: (json['description'] ?? json['content'] ?? '').toString(),
      potentialSaving: savingVal,
      impactLevel: (json['impactLevel'] ?? json['impact_level'] ?? 'Sedang').toString(),
      icon: CategoryIconMapper.getTipIcon(
        json['icon']?.toString(),
        category: cat,
      ),
      isApplied: isAppliedVal,
      actionText: (json['actionText'] ?? json['action_text'] ?? 'Terapkan Hari Ini').toString(),
      date: (json['date'] ?? json['formattedDate'] ?? json['formatted_date'])?.toString(),
      appliedAt: parsedAppliedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'description': description,
      'potentialSaving': potentialSaving,
      'impactLevel': impactLevel,
      'isApplied': isApplied,
      'actionText': actionText,
      'date': date,
      'appliedAt': appliedAt?.toIso8601String(),
    };
  }

  static List<SavingTipItem> getDailyTips() {
    return const [
      SavingTipItem(
        id: 'tip_1',
        title: 'Bawa Bekal Makan Siang 2x Sepekan',
        category: 'Makan & Minuman',
        description:
            'Mengganti makan siang luar dengan bekal rumahan 2 kali seminggu dapat menghemat hingga Rp 150.000 per pekan.',
        potentialSaving: 150000,
        impactLevel: 'Tinggi',
        icon: Icons.restaurant_rounded,
        actionText: 'Rencanakan Menu Bekal',
      ),
      SavingTipItem(
        id: 'tip_2',
        title: 'Aturan Tunda 24 Jam Belanja Online',
        category: 'Belanja',
        description:
            'Masukkan barang non-pokok ke keranjang belanja dan tunggu 24 jam sebelum bayar untuk meredam belanja impulsif.',
        potentialSaving: 250000,
        impactLevel: 'Tinggi',
        icon: Icons.shopping_bag_rounded,
        actionText: 'Terapkan Aturan 24 Jam',
      ),
      SavingTipItem(
        id: 'tip_3',
        title: 'Audit Langganan Aplikasi Digital',
        category: 'Tagihan & Utilitas',
        description:
            'Cek aplikasi streaming atau cloud yang jarang dipakai bulan ini. Nonaktifkan tagihan otomatis untuk pos yang tidak aktif.',
        potentialSaving: 89000,
        impactLevel: 'Sedang',
        icon: Icons.subscriptions_rounded,
        actionText: 'Cek Langganan Aktif',
      ),
      SavingTipItem(
        id: 'tip_4',
        title: 'Seduh Kopi Sendiri di Pagi Hari',
        category: 'Makan & Minuman',
        description:
            'Beli bubuk kopi favorit dan seduh sendiri sebelum berangkat kerja. Mengurangi frekuensi jajan kopi susu kekinian.',
        potentialSaving: 120000,
        impactLevel: 'Sedang',
        icon: Icons.coffee_rounded,
        actionText: 'Seduh Kopi Rumah',
      ),
      SavingTipItem(
        id: 'tip_5',
        title: 'Manfaatkan Promo Transportasi Terpadu',
        category: 'Transportasi',
        description:
            'Gunakan kartu langganan bulanan atau tiket komuter terusan saat jam kerja untuk menghemat biaya ojek harian.',
        potentialSaving: 75000,
        impactLevel: 'Ringan',
        icon: Icons.directions_bus_rounded,
        actionText: 'Cek Jalur Transit',
      ),
    ];
  }

  static List<SavingTipItem> getHistoryTips() {
    return const [
      SavingTipItem(
        id: 'tip_hist_1',
        title: 'Bawa Bekal Makan Siang 2x Sepekan',
        category: 'Makan & Minuman',
        description:
            'Mengganti makan siang luar dengan bekal rumahan 2 kali seminggu dapat menghemat hingga Rp 150.000 per pekan.',
        potentialSaving: 150000,
        impactLevel: 'Tinggi',
        icon: Icons.restaurant_rounded,
        actionText: 'Rencanakan Menu Bekal',
        isApplied: true,
        date: 'Hari Ini, 27 Sep 2026',
      ),
      SavingTipItem(
        id: 'tip_hist_2',
        title: 'Aturan Tunda 24 Jam Belanja Online',
        category: 'Belanja',
        description:
            'Masukkan barang non-pokok ke keranjang belanja dan tunggu 24 jam sebelum bayar untuk meredam belanja impulsif.',
        potentialSaving: 250000,
        impactLevel: 'Tinggi',
        icon: Icons.shopping_bag_rounded,
        actionText: 'Terapkan Aturan 24 Jam',
        isApplied: false,
        date: 'Hari Ini, 27 Sep 2026',
      ),
      SavingTipItem(
        id: 'tip_hist_3',
        title: 'Matikan Saklar Colokan Listrik Malam Hari',
        category: 'Tagihan & Utilitas',
        description:
            'Mematikan colokan TV, dispenser, dan charger saat tidur dapat menurunkan tagihan listrik bulanan.',
        potentialSaving: 45000,
        impactLevel: 'Ringan',
        icon: Icons.power_rounded,
        actionText: 'Cabut Saklar Malam',
        isApplied: true,
        date: 'Kemarin, 26 Sep 2026',
      ),
      SavingTipItem(
        id: 'tip_hist_4',
        title: 'Beralih ke Paket Data Bulanan Promo',
        category: 'Tagihan & Utilitas',
        description:
            'Beli paket data kuota besar per 30 hari daripada membeli paket harian atau mingguan yang berulang kali lebih mahal.',
        potentialSaving: 60000,
        impactLevel: 'Sedang',
        icon: Icons.wifi_rounded,
        actionText: 'Cek Paket Bulanan',
        isApplied: true,
        date: 'Kemarin, 26 Sep 2026',
      ),
      SavingTipItem(
        id: 'tip_hist_5',
        title: 'Pilih Berjalan Kaki untuk Jarak < 1 KM',
        category: 'Transportasi',
        description:
            'Mengurangi pesanan ojek online untuk rute dekat selain menyehatkan tubuh juga menghemat pengeluaran transportasi mikro.',
        potentialSaving: 50000,
        impactLevel: 'Ringan',
        icon: Icons.directions_walk_rounded,
        actionText: 'Mulai Jalan Kaki',
        isApplied: true,
        date: '24 Sep 2026',
      ),
      SavingTipItem(
        id: 'tip_hist_6',
        title: 'Beli Kebutuhan Dapur Kemasan Grosir',
        category: 'Belanja',
        description:
            'Beli beras, minyak goreng, dan deterjen dalam ukuran isi ulang besar untuk mendapatkan potongan harga per liter/kg.',
        potentialSaving: 180000,
        impactLevel: 'Tinggi',
        icon: Icons.storefront_rounded,
        actionText: 'Beli Kemasan Grosir',
        isApplied: true,
        date: '22 Sep 2026',
      ),
      SavingTipItem(
        id: 'tip_hist_7',
        title: 'Audit Langganan Aplikasi Digital',
        category: 'Tagihan & Utilitas',
        description:
            'Cek aplikasi streaming atau cloud yang jarang dipakai bulan ini. Nonaktifkan tagihan otomatis untuk pos yang tidak aktif.',
        potentialSaving: 89000,
        impactLevel: 'Sedang',
        icon: Icons.subscriptions_rounded,
        actionText: 'Cek Langganan Aktif',
        isApplied: false,
        date: '18 Sep 2026',
      ),
      SavingTipItem(
        id: 'tip_hist_8',
        title: 'Seduh Kopi Sendiri di Pagi Hari',
        category: 'Makan & Minuman',
        description:
            'Beli bubuk kopi favorit dan seduh sendiri sebelum berangkat kerja. Mengurangi frekuensi jajan kopi susu kekinian.',
        potentialSaving: 120000,
        impactLevel: 'Sedang',
        icon: Icons.coffee_rounded,
        actionText: 'Seduh Kopi Rumah',
        isApplied: true,
        date: '15 Sep 2026',
      ),
    ];
  }
}

