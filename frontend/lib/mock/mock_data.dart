import 'package:flutter/material.dart';
import '../models/category_item.dart';
import '../models/chat_log_item.dart';
import '../models/chat_message.dart';
import '../models/transaction_item.dart';

class MockData {
  static const List<String> expenseCategories = [
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

  static const List<String> incomeCategories = [
    'Gaji',
    'Freelance',
    'Bonus',
    'Investasi',
    'Transfer Masuk',
    'Lainnya',
  ];

  static List<CategoryItem> getInitialCategories() {
    return [
      // Default expense categories
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

      // Custom expense categories (created by user!)
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

      // Default income categories
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

  static List<ChatMessage> getInitialMessages() {
    final now = DateTime.now();
    return [
      ChatMessage(
        id: 'msg_welcome',
        text: 'Halo! Aku Moneta AI. 🤖✨\n\nCeritakan saja pengeluaran atau pemasukanmu seperti mengobrol biasa, contoh:\n• "Makan siang padang 25rb"\n• "Kopi latte 32rb"\n• "Gajian freelance 2.5jt"',
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
        text: 'AI mendeteksi pengeluaran baru. Silakan konfirmasi untuk menyimpan:',
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

  /// Returns parsed TransactionItem, or null if AI parser fails
  static TransactionItem? parseTextOrNull(String input) {
    final lower = input.toLowerCase().trim();

    // Trigger AI failure for keywords or when no amount is detectable
    if (lower.contains('gagal') ||
        lower.contains('error') ||
        lower.contains('rusak') ||
        lower == 'halo' ||
        lower == 'test' ||
        lower == 'bingung') {
      return null;
    }

    // Must have at least some digit or recognizable pattern
    final hasNumber = RegExp(r'\d').hasMatch(lower);
    if (!hasNumber) {
      return null;
    }

    return parseText(input);
  }

  /// Interactive mock parser for natural language inputs
  static TransactionItem parseText(String input) {
    final lower = input.toLowerCase();
    
    // Determine type
    bool isIncome = lower.contains('gaji') ||
        lower.contains('terima') ||
        lower.contains('bonus') ||
        lower.contains('freelance') ||
        lower.contains('transfer masuk') ||
        lower.contains('dapat');
    
    String type = isIncome ? 'income' : 'expense';

    // Determine category
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

    // Extract amount
    double amount = 20000; // default fallback
    
    // Check "jt" or "juta"
    final jtRegex = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:jt|juta)');
    final jtMatch = jtRegex.firstMatch(lower);
    if (jtMatch != null) {
      final numStr = jtMatch.group(1)!.replaceAll(',', '.');
      amount = (double.tryParse(numStr) ?? 1) * 1000000;
    } else {
      // Check "rb" or "ribu" or "k"
      final rbRegex = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:rb|ribu|k)');
      final rbMatch = rbRegex.firstMatch(lower);
      if (rbMatch != null) {
        final numStr = rbMatch.group(1)!.replaceAll(',', '.');
        amount = (double.tryParse(numStr) ?? 1) * 1000;
      } else {
        // Plain numbers
        final numRegex = RegExp(r'(\d{4,})');
        final numMatch = numRegex.firstMatch(lower.replaceAll('.', '').replaceAll(',', ''));
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

  static List<ChatLogItem> getMockChatLogs() {
    final now = DateTime.now();
    return [
      ChatLogItem(
        id: 'log_1',
        message: 'Makan siang ayam geprek 25rb',
        status: ChatLogStatus.confirmed,
        createdAt: now.subtract(const Duration(minutes: 45)),
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
      ChatLogItem(
        id: 'log_2',
        message: 'Bensin pertamax 50rb',
        status: ChatLogStatus.confirmed,
        createdAt: now.subtract(const Duration(minutes: 20)),
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
      ChatLogItem(
        id: 'log_3',
        message: 'Kopi americano 22rb',
        status: ChatLogStatus.pending,
        createdAt: now.subtract(const Duration(minutes: 5)),
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
      ChatLogItem(
        id: 'log_4',
        message: 'Gajian freelance 2.5jt',
        status: ChatLogStatus.confirmed,
        createdAt: now.subtract(const Duration(hours: 3)),
        transaction: TransactionItem(
          id: 'tx_4',
          note: 'Gajian freelance',
          amount: 2500000,
          type: 'income',
          category: 'Freelance',
          occurredAt: now.subtract(const Duration(hours: 3)),
          isConfirmed: true,
        ),
      ),
      ChatLogItem(
        id: 'log_5',
        message: 'Beli baju kemeja kerja 185rb',
        status: ChatLogStatus.deleted,
        createdAt: now.subtract(const Duration(hours: 6)),
        transaction: TransactionItem(
          id: 'tx_5',
          note: 'Beli baju kemeja kerja',
          amount: 185000,
          type: 'expense',
          category: 'Belanja',
          occurredAt: now.subtract(const Duration(hours: 6)),
          isConfirmed: false,
        ),
      ),
      ChatLogItem(
        id: 'log_6',
        message: 'error tidak jelas',
        status: ChatLogStatus.failed,
        createdAt: now.subtract(const Duration(hours: 12)),
      ),
    ];
  }
}
