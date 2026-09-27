import 'package:flutter/material.dart';
import '../models/saving_tip_item.dart';

class SavingTipsMockData {
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
}
