import 'package:flutter/material.dart';
import '../models/category_item.dart';

class CategoryIconMapper {
  static const List<String> availableMonths = [
    '2026-09',
    '2026-08',
    '2026-07',
  ];

  static const List<String> defaultExpenseCategories = [
    'Makan & Minuman',
    'Transportasi',
    'Belanja',
    'Hiburan',
    'Tagihan & Utilitas',
    'Hutang & Paylater',
    'Kebutuhan Rumah',
    'Kesehatan',
    'Lainnya',
  ];

  static const List<String> defaultIncomeCategories = [
    'Gaji',
    'Freelance',
    'Bonus',
    'Investasi',
    'Transfer Masuk',
    'Lainnya',
  ];

  static String getMonthLabel(String monthKey) {
    const months = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final parts = monthKey.split('-');
    if (parts.length == 2) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      if (year != null && month != null && month >= 1 && month <= 12) {
        return '${months[month]} $year';
      }
    }
    return monthKey;
  }

  static IconData getCategoryIcon(
    String categoryName, {
    String? iconKey,
    String? type,
  }) {
    if (iconKey != null && iconKey.isNotEmpty) {
      final mapped = _mapIconKey(iconKey);
      if (mapped != null) return mapped;
    }

    final lower = categoryName.toLowerCase();
    if (lower.contains('makan') ||
        lower.contains('minum') ||
        lower.contains('kopi') ||
        lower.contains('jajan')) {
      return Icons.restaurant_rounded;
    }
    if (lower.contains('trans') ||
        lower.contains('bensin') ||
        lower.contains('ojol') ||
        lower.contains('parkir')) {
      return Icons.directions_car_rounded;
    }
    if (lower.contains('belanja') || lower.contains('baju')) {
      return Icons.shopping_bag_rounded;
    }
    if (lower.contains('hiburan') ||
        lower.contains('bioskop') ||
        lower.contains('game') ||
        lower.contains('nongkrong')) {
      return Icons.sports_esports_rounded;
    }
    if (lower.contains('tagihan') ||
        lower.contains('listrik') ||
        lower.contains('wifi') ||
        lower.contains('utilitas')) {
      return Icons.receipt_long_rounded;
    }
    if (lower.contains('hutang') ||
        lower.contains('paylater') ||
        lower.contains('cicilan')) {
      return Icons.credit_card_rounded;
    }
    if (lower.contains('rumah') || lower.contains('kos') || lower.contains('sewa')) {
      return Icons.home_rounded;
    }
    if (lower.contains('sehat') || lower.contains('obat') || lower.contains('dokter')) {
      return Icons.local_hospital_rounded;
    }
    if (lower.contains('gym') || lower.contains('fit') || lower.contains('olahraga')) {
      return Icons.fitness_center_rounded;
    }
    if (lower.contains('skin') || lower.contains('rawat')) {
      return Icons.face_retouching_natural_rounded;
    }
    if (lower.contains('ai') ||
        lower.contains('software') ||
        lower.contains('langganan')) {
      return Icons.auto_awesome_rounded;
    }
    if (lower.contains('gaji')) {
      return Icons.account_balance_wallet_rounded;
    }
    if (lower.contains('freelance') || lower.contains('proyek')) {
      return Icons.laptop_mac_rounded;
    }
    if (lower.contains('bonus') || lower.contains('hadiah')) {
      return Icons.card_giftcard_rounded;
    }
    if (lower.contains('invest') ||
        lower.contains('reksadana') ||
        lower.contains('tabung')) {
      return Icons.trending_up_rounded;
    }
    if (lower.contains('masuk') || lower.contains('kirim') || lower.contains('transfer')) {
      return Icons.move_to_inbox_rounded;
    }
    if (lower == 'lainnya') {
      return type == 'income'
          ? Icons.attach_money_rounded
          : Icons.more_horiz_rounded;
    }
    return Icons.bookmark_border_rounded;
  }

  static Color getCategoryColor(
    String categoryName, {
    String? colorHex,
    String? type,
  }) {
    if (colorHex != null && colorHex.trim().isNotEmpty) {
      final parsed = _parseHexColor(colorHex);
      if (parsed != null) return parsed;
    }

    final lower = categoryName.toLowerCase();
    if (lower.contains('makan') || lower.contains('minum')) return Colors.orange;
    if (lower.contains('trans') || lower.contains('bensin')) return Colors.blue;
    if (lower.contains('belanja')) return Colors.pink;
    if (lower.contains('hiburan') || lower.contains('nongkrong')) return Colors.purple;
    if (lower.contains('tagihan') || lower.contains('listrik')) return Colors.indigo;
    if (lower.contains('hutang') || lower.contains('paylater')) return Colors.red;
    if (lower.contains('rumah') || lower.contains('kos')) return Colors.teal;
    if (lower.contains('sehat')) return Colors.green;
    if (lower.contains('gym') || lower.contains('fit')) return Colors.amber;
    if (lower.contains('skin') || lower.contains('rawat')) return Colors.deepPurple;
    if (lower.contains('ai') || lower.contains('software')) return Colors.cyan;
    if (lower.contains('gaji')) return Colors.green;
    if (lower.contains('freelance')) return Colors.blueAccent;
    if (lower.contains('bonus')) return Colors.amber;
    if (lower.contains('invest') || lower.contains('reksadana')) return Colors.teal;
    if (lower.contains('transfer') || lower.contains('masuk')) return Colors.cyan;
    if (lower == 'lainnya') return Colors.grey;
    return type == 'income' ? Colors.teal : Colors.blueGrey;
  }

  static IconData getTipIcon(String? iconName, {String? category}) {
    if (iconName != null && iconName.isNotEmpty) {
      final mapped = _mapIconKey(iconName);
      if (mapped != null) return mapped;
    }
    if (category != null && category.isNotEmpty) {
      return getCategoryIcon(category);
    }
    return Icons.lightbulb_outline_rounded;
  }

  static IconData? _mapIconKey(String key) {
    final k = key.trim().toLowerCase();
    switch (k) {
      case 'restaurant':
      case 'restaurant_rounded':
      case 'fastfood_rounded':
        return Icons.restaurant_rounded;
      case 'coffee':
      case 'coffee_rounded':
        return Icons.coffee_rounded;
      case 'shopping_bag':
      case 'shopping_bag_rounded':
        return Icons.shopping_bag_rounded;
      case 'storefront':
      case 'storefront_rounded':
        return Icons.storefront_rounded;
      case 'subscriptions':
      case 'subscriptions_rounded':
        return Icons.subscriptions_rounded;
      case 'bolt':
      case 'bolt_rounded':
        return Icons.bolt_rounded;
      case 'directions_bus':
      case 'directions_bus_rounded':
      case 'directions_car':
      case 'directions_car_rounded':
        return Icons.directions_car_rounded;
      case 'directions_bike_rounded':
        return Icons.directions_bike_rounded;
      case 'savings':
      case 'savings_rounded':
        return Icons.savings_rounded;
      case 'edit_note':
      case 'edit_note_rounded':
        return Icons.edit_note_rounded;
      case 'home':
      case 'home_rounded':
      case 'home_work_rounded':
        return Icons.home_rounded;
      case 'local_hospital':
      case 'local_hospital_rounded':
        return Icons.local_hospital_rounded;
      case 'sports_esports':
      case 'sports_esports_rounded':
      case 'movie_rounded':
      case 'celebration_rounded':
        return Icons.sports_esports_rounded;
      case 'receipt_long':
      case 'receipt_long_rounded':
        return Icons.receipt_long_rounded;
      case 'credit_card':
      case 'credit_card_rounded':
        return Icons.credit_card_rounded;
      case 'fitness_center':
      case 'fitness_center_rounded':
        return Icons.fitness_center_rounded;
      case 'face_retouching_natural':
      case 'face_retouching_natural_rounded':
        return Icons.face_retouching_natural_rounded;
      case 'auto_awesome':
      case 'auto_awesome_rounded':
        return Icons.auto_awesome_rounded;
      case 'account_balance_wallet':
      case 'account_balance_wallet_rounded':
      case 'account_balance_rounded':
        return Icons.account_balance_wallet_rounded;
      case 'laptop_mac':
      case 'laptop_mac_rounded':
        return Icons.laptop_mac_rounded;
      case 'card_giftcard':
      case 'card_giftcard_rounded':
        return Icons.card_giftcard_rounded;
      case 'trending_up':
      case 'trending_up_rounded':
        return Icons.trending_up_rounded;
      case 'move_to_inbox':
      case 'move_to_inbox_rounded':
        return Icons.move_to_inbox_rounded;
      case 'attach_money':
      case 'attach_money_rounded':
        return Icons.attach_money_rounded;
      case 'more_horiz':
      case 'more_horiz_rounded':
        return Icons.more_horiz_rounded;
      case 'lightbulb_outline':
      case 'lightbulb_outline_rounded':
        return Icons.lightbulb_outline_rounded;
      default:
        return null;
    }
  }

  static Color? _parseHexColor(String hexString) {
    var cleaned = hexString.trim().replaceAll('#', '');
    if (cleaned.startsWith('0x') || cleaned.startsWith('0X')) {
      cleaned = cleaned.substring(2);
    }
    if (cleaned.length == 6) {
      cleaned = 'FF$cleaned';
    }
    if (cleaned.length == 8) {
      final intVal = int.tryParse(cleaned, radix: 16);
      if (intVal != null) {
        return Color(intVal);
      }
    }
    return null;
  }

  static List<CategoryItem> getDefaultCategoryItems() {
    return [
      CategoryItem(
        id: 'cat_exp_1',
        name: 'Makan & Minuman',
        type: 'expense',
        isDefault: true,
        icon: Icons.restaurant_rounded,
        color: Colors.orange,
      ),
      CategoryItem(
        id: 'cat_exp_2',
        name: 'Transportasi',
        type: 'expense',
        isDefault: true,
        icon: Icons.directions_car_rounded,
        color: Colors.blue,
      ),
      CategoryItem(
        id: 'cat_exp_3',
        name: 'Belanja',
        type: 'expense',
        isDefault: true,
        icon: Icons.shopping_bag_rounded,
        color: Colors.pink,
      ),
      CategoryItem(
        id: 'cat_exp_4',
        name: 'Hiburan',
        type: 'expense',
        isDefault: true,
        icon: Icons.sports_esports_rounded,
        color: Colors.purple,
      ),
      CategoryItem(
        id: 'cat_exp_5',
        name: 'Tagihan & Utilitas',
        type: 'expense',
        isDefault: true,
        icon: Icons.receipt_long_rounded,
        color: Colors.indigo,
      ),
      CategoryItem(
        id: 'cat_exp_6',
        name: 'Hutang & Paylater',
        type: 'expense',
        isDefault: true,
        icon: Icons.credit_card_rounded,
        color: Colors.red,
      ),
      CategoryItem(
        id: 'cat_exp_7',
        name: 'Kebutuhan Rumah',
        type: 'expense',
        isDefault: true,
        icon: Icons.home_rounded,
        color: Colors.teal,
      ),
      CategoryItem(
        id: 'cat_exp_8',
        name: 'Kesehatan',
        type: 'expense',
        isDefault: true,
        icon: Icons.local_hospital_rounded,
        color: Colors.green,
      ),
      CategoryItem(
        id: 'cat_exp_9',
        name: 'Lainnya',
        type: 'expense',
        isDefault: true,
        icon: Icons.more_horiz_rounded,
        color: Colors.grey,
      ),
      CategoryItem(
        id: 'cat_custom_1',
        name: 'Gym & Fitness',
        type: 'expense',
        isDefault: false,
        icon: Icons.fitness_center_rounded,
        color: Colors.amber,
      ),
      CategoryItem(
        id: 'cat_custom_2',
        name: 'Skincare & Perawatan',
        type: 'expense',
        isDefault: false,
        icon: Icons.face_retouching_natural_rounded,
        color: Colors.deepPurple,
      ),
      CategoryItem(
        id: 'cat_custom_3',
        name: 'Langganan AI & Software',
        type: 'expense',
        isDefault: false,
        icon: Icons.auto_awesome_rounded,
        color: Colors.cyan,
      ),
      CategoryItem(
        id: 'cat_inc_1',
        name: 'Gaji',
        type: 'income',
        isDefault: true,
        icon: Icons.account_balance_wallet_rounded,
        color: Colors.green,
      ),
      CategoryItem(
        id: 'cat_inc_2',
        name: 'Freelance',
        type: 'income',
        isDefault: true,
        icon: Icons.laptop_mac_rounded,
        color: Colors.blueAccent,
      ),
      CategoryItem(
        id: 'cat_inc_3',
        name: 'Bonus',
        type: 'income',
        isDefault: true,
        icon: Icons.card_giftcard_rounded,
        color: Colors.amber,
      ),
      CategoryItem(
        id: 'cat_inc_4',
        name: 'Investasi',
        type: 'income',
        isDefault: true,
        icon: Icons.trending_up_rounded,
        color: Colors.teal,
      ),
      CategoryItem(
        id: 'cat_inc_5',
        name: 'Transfer Masuk',
        type: 'income',
        isDefault: true,
        icon: Icons.move_to_inbox_rounded,
        color: Colors.cyan,
      ),
      CategoryItem(
        id: 'cat_inc_6',
        name: 'Lainnya',
        type: 'income',
        isDefault: true,
        icon: Icons.attach_money_rounded,
        color: Colors.grey,
      ),
    ];
  }
}
