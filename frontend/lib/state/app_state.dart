import 'package:flutter/material.dart';
import '../mock/ai_insight_mock_data.dart';
import '../mock/daily_spending_mock_data.dart';
import '../mock/mock_data.dart';
import '../models/ai_insight_item.dart';
import '../models/category_item.dart';
import '../models/category_usage.dart';
import '../models/chat_log_item.dart';
import '../models/chat_message.dart';
import '../models/daily_spending_item.dart';
import '../models/transaction_item.dart';
import '../utils/currency_format.dart';

class AppState extends ChangeNotifier {
  static AppState? _instance;
  static AppState get instance => _instance ??= AppState._();

  AppState._() {
    _initDefaultState();
  }

  factory AppState() => instance;

  List<ChatMessage> _messages = [];
  List<ChatLogItem> _chatLogs = [];
  List<CategoryItem> _categories = [];
  bool _isAiTyping = false;
  AiInsightItem _aiInsight = AiInsightMockData.getDefaultInsight();
  DailySpendingAnalysis _dailySpendingAnalysis =
      DailySpendingMockData.getDefaultDailyAnalysis();

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<ChatLogItem> get chatLogs => List.unmodifiable(_chatLogs);
  List<CategoryItem> get categories => List.unmodifiable(_categories);
  bool get isAiTyping => _isAiTyping;
  AiInsightItem get aiInsight => _aiInsight;
  DailySpendingAnalysis get dailySpendingAnalysis => _dailySpendingAnalysis;

  List<CategoryItem> get expenseCategories =>
      _categories.where((c) => c.isExpense).toList();
  List<CategoryItem> get incomeCategories =>
      _categories.where((c) => c.isIncome).toList();
  List<CategoryItem> get customExpenseCategories =>
      _categories.where((c) => c.isExpense && c.isCustom).toList();
  List<CategoryItem> get defaultExpenseCategories =>
      _categories.where((c) => c.isExpense && c.isDefault).toList();

  List<TransactionItem> get confirmedTransactions {
    final list = <TransactionItem>[];
    for (var m in _messages) {
      if (m.transaction != null && m.transaction!.isConfirmed) {
        list.add(m.transaction!);
      }
    }
    return list;
  }

  List<TransactionItem> get allTransactions {
    final Map<String, TransactionItem> map = {};
    for (var m in _messages) {
      if (m.transaction != null) {
        map[m.transaction!.id] = m.transaction!;
      }
    }
    for (var log in _chatLogs) {
      if (log.transaction != null) {
        map.putIfAbsent(log.transaction!.id, () => log.transaction!);
      }
    }
    final list = map.values.toList();
    list.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return list;
  }

  double get todayTotalExpense {
    double total = 0;
    for (var tx in confirmedTransactions) {
      if (tx.isExpense) {
        total += tx.amount;
      }
    }
    return total;
  }

  double get todayTotalIncome {
    double total = 0;
    for (var tx in confirmedTransactions) {
      if (tx.isIncome) {
        total += tx.amount;
      }
    }
    return total;
  }

  void _initDefaultState() {
    _messages = MockData.getInitialMessages();
    _chatLogs = MockData.getMockChatLogs();
    _categories = MockData.getInitialCategories();
    _isAiTyping = false;
    _aiInsight = AiInsightMockData.getDefaultInsight();
    _dailySpendingAnalysis = DailySpendingMockData.getDefaultDailyAnalysis();
  }

  void resetToDefault() {
    _initDefaultState();
    notifyListeners();
  }

  void setAiInsight(AiInsightItem insight) {
    _aiInsight = insight;
    notifyListeners();
  }

  void setDailySpendingAnalysis(DailySpendingAnalysis analysis) {
    _dailySpendingAnalysis = analysis;
    notifyListeners();
  }

  void cycleAiInsightPreset() {
    if (_aiInsight.warnLevel == AiWarnLevel.normal) {
      _aiInsight = AiInsightMockData.getWarningInsight();
    } else if (_aiInsight.warnLevel == AiWarnLevel.warning) {
      _aiInsight = AiInsightMockData.getCriticalInsight();
    } else {
      _aiInsight = AiInsightMockData.getDefaultInsight();
    }
    notifyListeners();
  }

  static String _fullDayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Senin';
      case DateTime.tuesday:
        return 'Selasa';
      case DateTime.wednesday:
        return 'Rabu';
      case DateTime.thursday:
        return 'Kamis';
      case DateTime.friday:
        return 'Jumat';
      case DateTime.saturday:
        return 'Sabtu';
      case DateTime.sunday:
        return 'Minggu';
      default:
        return 'Hari ini';
    }
  }

  /// Recalculates AI insight and daily spending analysis based on real confirmed transactions.
  void recalculateAnalysis({
    bool notify = true,
    double monthlyBudget = 6000000,
  }) {
    final expenseTxs =
        confirmedTransactions.where((t) => t.isExpense).toList();
    final now = DateTime.now();

    if (expenseTxs.isEmpty) {
      _aiInsight = _aiInsight.copyWith(
        totalSpent: 0,
        remainingBalance: monthlyBudget,
        avgDailySpend: 0,
        dailyAdvice:
            'Belum ada transaksi pengeluaran bulan ini. Catat transaksi pertamamu lewat chat!',
        warnLevel: AiWarnLevel.normal,
      );
      _dailySpendingAnalysis = DailySpendingAnalysis(
        avgDailySpend: 0,
        targetDailySpend: 65000,
        weekOverWeekPercent: 0,
        highestSpendAmount: 0,
        highestSpendDay: 'Belum Ada',
        lowestSpendAmount: 0,
        lowestSpendDay: 'Belum Ada',
        topCategoryName: 'Belum Ada',
        topCategoryPercentage: 0,
        dailyPoints: List.generate(7, (i) {
          final d = now.subtract(Duration(days: 6 - i));
          const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
          return DailySpendingPoint(
            dayLabel: days[(d.weekday - 1) % 7],
            date: d,
            amount: 0,
            isAboveAverage: false,
          );
        }),
      );
      if (notify) notifyListeners();
      return;
    }

    final today = DateTime(now.year, now.month, now.day);
    const dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    final List<DailySpendingPoint> rawPoints = [];
    double total7Days = 0;
    double highestSpend = 0;
    String highestDay = 'Senin';
    double lowestSpend = double.infinity;
    String lowestDay = 'Senin';

    final Map<String, double> categorySums = {};
    double totalExpenseAmount = 0;

    for (var tx in expenseTxs) {
      totalExpenseAmount += tx.amount;
      categorySums[tx.category] =
          (categorySums[tx.category] ?? 0) + tx.amount;
    }

    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      double daySum = 0;
      for (var tx in expenseTxs) {
        final txDate = DateTime(
            tx.occurredAt.year, tx.occurredAt.month, tx.occurredAt.day);
        if (txDate.isAtSameMomentAs(date)) {
          daySum += tx.amount;
        }
      }
      total7Days += daySum;
      final weekdayIdx = (date.weekday - 1) % 7;
      final label = dayNames[weekdayIdx];
      if (daySum > highestSpend) {
        highestSpend = daySum;
        highestDay = _fullDayName(date.weekday);
      }
      if (daySum < lowestSpend) {
        lowestSpend = daySum;
        lowestDay = _fullDayName(date.weekday);
      }
      rawPoints.add(DailySpendingPoint(
        dayLabel: label,
        date: date,
        amount: daySum,
        isAboveAverage: false,
      ));
    }

    if (lowestSpend == double.infinity) {
      lowestSpend = 0;
      lowestDay = 'Senin';
    }

    final avgDaily =
        total7Days > 0 ? (total7Days / 7.0) : (totalExpenseAmount / 7.0);

    final updatedPoints = rawPoints
        .map((p) => DailySpendingPoint(
              dayLabel: p.dayLabel,
              date: p.date,
              amount: p.amount,
              isAboveAverage: avgDaily > 0 && p.amount > avgDaily,
            ))
        .toList();

    String topCat = 'Lainnya';
    double topCatMax = 0;
    categorySums.forEach((cat, amt) {
      if (amt > topCatMax) {
        topCatMax = amt;
        topCat = cat;
      }
    });
    final topCatPct = totalExpenseAmount > 0
        ? ((topCatMax / totalExpenseAmount) * 100)
        : 0.0;

    _dailySpendingAnalysis = DailySpendingAnalysis(
      avgDailySpend: avgDaily,
      targetDailySpend: 65000,
      weekOverWeekPercent: 5.2,
      highestSpendAmount: highestSpend,
      highestSpendDay: highestDay,
      lowestSpendAmount: lowestSpend,
      lowestSpendDay: lowestDay,
      topCategoryName: topCat,
      topCategoryPercentage: topCatPct,
      dailyPoints: updatedPoints,
    );

    final remainingBalance =
        (monthlyBudget - totalExpenseAmount).clamp(0.0, double.infinity);

    final nextMonth = DateTime(now.year, now.month + 1, 1);
    final lastDay = nextMonth.subtract(const Duration(days: 1));
    final daysRemainingInMonth = (lastDay.day - now.day).clamp(1, 31);

    final recommendedDailyBudget =
        (remainingBalance / daysRemainingInMonth).roundToDouble();
    final estimatedDaysLeft = avgDaily > 0
        ? (remainingBalance / avgDaily).floor()
        : daysRemainingInMonth;

    final AiWarnLevel warnLevel;
    if (remainingBalance <= 0 ||
        estimatedDaysLeft <= 5 ||
        (estimatedDaysLeft < daysRemainingInMonth &&
            daysRemainingInMonth - estimatedDaysLeft > 10)) {
      warnLevel = AiWarnLevel.critical;
    } else if (estimatedDaysLeft < daysRemainingInMonth ||
        avgDaily > recommendedDailyBudget * 1.25) {
      warnLevel = AiWarnLevel.warning;
    } else {
      warnLevel = AiWarnLevel.normal;
    }

    final String dailyAdvice;
    if (warnLevel == AiWarnLevel.critical) {
      dailyAdvice =
          'Kritis: Sisa saldo menipis! Batasi pengeluaran maksimal ${CurrencyFormat.formatRupiah(recommendedDailyBudget)}/hari agar bertahan sampai akhir bulan.';
    } else if (warnLevel == AiWarnLevel.warning) {
      dailyAdvice =
          'Perhatian: Pengeluaran harian (${CurrencyFormat.formatRupiah(avgDaily)}) di atas target (${CurrencyFormat.formatRupiah(recommendedDailyBudget)}). Batasi pos jajan dan belanja non-esensial.';
    } else {
      dailyAdvice =
          'Pertahankan ritme belanja Anda. Batasi pos non-esensial maksimal ${CurrencyFormat.formatRupiah(recommendedDailyBudget)} hari ini agar saldo aman sampai akhir bulan.';
    }

    _aiInsight = _aiInsight.copyWith(
      date: now,
      avgDailySpend: avgDaily,
      estimatedDaysLeft: estimatedDaysLeft,
      recommendedDailyBudget: recommendedDailyBudget,
      dailyAdvice: dailyAdvice,
      warnLevel: warnLevel,
      totalMonthlyBudget: monthlyBudget,
      totalSpent: totalExpenseAmount,
      remainingBalance: remainingBalance,
    );

    if (notify) notifyListeners();
  }

  /// Add a custom category
  bool addCustomCategory(
    String name, {
    String type = 'expense',
    IconData? icon,
    Color? color,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;

    // Disallow duplicate names for same type
    final exists = _categories.any((c) =>
        c.type == type && c.name.toLowerCase() == trimmed.toLowerCase());
    if (exists) return false;

    final newCat = CategoryItem(
      id: 'cat_custom_${DateTime.now().millisecondsSinceEpoch}',
      name: trimmed,
      type: type,
      isDefault: false,
      icon: icon ?? Icons.bookmark_border_rounded,
      color: color ?? Colors.purple,
    );
    _categories.add(newCat);
    notifyListeners();
    return true;
  }

  /// Update an existing category's name and/or icon
  bool updateCategory(
    String id,
    String newName, {
    IconData? icon,
    Color? color,
  }) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return false;

    final index = _categories.indexWhere((c) => c.id == id);
    if (index == -1) return false;

    final oldCat = _categories[index];
    final oldName = oldCat.name;

    // Disallow collision with other category of same type
    final collision = _categories.any((c) =>
        c.id != id &&
        c.type == oldCat.type &&
        c.name.toLowerCase() == trimmed.toLowerCase());
    if (collision) return false;

    _categories[index] = oldCat.copyWith(
      name: trimmed,
      icon: icon ?? oldCat.icon,
      color: color ?? oldCat.color,
    );

    // Update occurrences in active messages and chat logs
    for (var m in _messages) {
      if (m.transaction != null && m.transaction!.category == oldName) {
        m.transaction!.category = trimmed;
      }
    }
    for (var log in _chatLogs) {
      if (log.transaction != null && log.transaction!.category == oldName) {
        log.transaction!.category = trimmed;
      }
    }

    notifyListeners();
    return true;
  }

  /// Delete a custom category and reassign transactions using it to 'Lainnya'
  bool deleteCategory(String id) {
    final index = _categories.indexWhere((c) => c.id == id);
    if (index == -1) return false;

    final cat = _categories[index];
    if (cat.isDefault) return false; // Default categories cannot be deleted

    _categories.removeAt(index);

    // Reassign transactions using this category to 'Lainnya'
    for (var m in _messages) {
      if (m.transaction != null && m.transaction!.category == cat.name) {
        m.transaction!.category = 'Lainnya';
      }
    }
    for (var log in _chatLogs) {
      if (log.transaction != null && log.transaction!.category == cat.name) {
        log.transaction!.category = 'Lainnya';
      }
    }

    notifyListeners();
    return true;
  }

  /// Count how many transactions use a category name
  int getTransactionCountForCategory(String categoryName) {
    int count = 0;
    for (var tx in allTransactions) {
      if (tx.category.toLowerCase() == categoryName.toLowerCase()) {
        count++;
      }
    }
    return count;
  }

  /// Get frequently used categories based on transaction history.
  /// Top frequently used categories appear first. If history has fewer than [limit]
  /// used categories, it fills the remainder with default categories.
  List<CategoryUsage> getFrequentlyUsedCategories({
    required String type,
    int limit = 5,
  }) {
    final Map<String, int> counts = {};
    for (var tx in allTransactions) {
      if (tx.type == type &&
          tx.category.isNotEmpty &&
          tx.category != 'Belum Dikategorikan' &&
          tx.category != 'Kategori Kosong') {
        counts[tx.category] = (counts[tx.category] ?? 0) + 1;
      }
    }

    final sortedUsedNames = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    final result = <CategoryUsage>[];

    for (var name in sortedUsedNames) {
      if (result.length >= limit) break;
      final catItem = _categories.cast<CategoryItem?>().firstWhere(
            (c) => c?.name.toLowerCase() == name.toLowerCase() && c?.type == type,
            orElse: () => null,
          );
      result.add(CategoryUsage(
        name: name,
        type: type,
        count: counts[name] ?? 0,
        icon: catItem?.icon,
        color: catItem?.color,
        isCustom: catItem?.isCustom ?? false,
      ));
    }

    if (result.length < limit) {
      final available = (type == 'expense' ? expenseCategories : incomeCategories);
      for (var cat in available) {
        if (result.length >= limit) break;
        if (!result.any((r) => r.name.toLowerCase() == cat.name.toLowerCase())) {
          result.add(CategoryUsage(
            name: cat.name,
            type: type,
            count: counts[cat.name] ?? 0,
            icon: cat.icon,
            color: cat.color,
            isCustom: cat.isCustom,
          ));
        }
      }
    }

    return result;
  }

  /// Get frequently used category names as a simple list of strings
  List<String> getFrequentCategoryNames({
    required String type,
    int limit = 5,
  }) {
    return getFrequentlyUsedCategories(type: type, limit: limit)
        .map((c) => c.name)
        .toList();
  }

  /// Send user message and simulate AI parsing to mock state
  void sendMessage(String text, {VoidCallback? onAiComplete}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final userMessage = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: trimmed,
      isUser: true,
      timestamp: DateTime.now(),
    );

    _messages.add(userMessage);
    _isAiTyping = true;
    notifyListeners();

    // Simulate 9Router AI delay
    Future.delayed(const Duration(milliseconds: 600), () {
      final parsed = MockData.parseTextOrNull(trimmed);

      final ChatMessage aiMessage;
      if (parsed != null) {
        aiMessage = ChatMessage(
          id: 'msg_ai_${DateTime.now().millisecondsSinceEpoch}',
          text: 'AI berhasil mengenali transaksi. Konfirmasi untuk mencatat:',
          isUser: false,
          timestamp: DateTime.now(),
          isAi: true,
          transaction: parsed,
        );

        // Also add to chat logs as pending
        _chatLogs.insert(
          0,
          ChatLogItem(
            id: 'log_${DateTime.now().millisecondsSinceEpoch}',
            message: trimmed,
            status: ChatLogStatus.pending,
            createdAt: DateTime.now(),
            transaction: parsed,
          ),
        );
      } else {
        aiMessage = ChatMessage(
          id: 'msg_ai_fail_${DateTime.now().millisecondsSinceEpoch}',
          text: 'AI belum dapat membaca format transaksi dari pesanmu.',
          isUser: false,
          timestamp: DateTime.now(),
          isAi: true,
          isAiFailed: true,
          failedRawText: trimmed,
        );

        _chatLogs.insert(
          0,
          ChatLogItem(
            id: 'log_${DateTime.now().millisecondsSinceEpoch}',
            message: trimmed,
            status: ChatLogStatus.failed,
            createdAt: DateTime.now(),
          ),
        );
      }

      _isAiTyping = false;
      _messages.add(aiMessage);
      notifyListeners();
      onAiComplete?.call();
    });
  }

  /// Confirm a transaction and update its status across messages and chat logs
  void confirmTransaction(String transactionId) {
    for (var m in _messages) {
      if (m.transaction != null && m.transaction!.id == transactionId) {
        m.transaction!.isConfirmed = true;
      }
    }

    for (var log in _chatLogs) {
      if (log.transaction != null && log.transaction!.id == transactionId) {
        log.status = ChatLogStatus.confirmed;
        log.transaction!.isConfirmed = true;
      }
    }

    recalculateAnalysis(notify: false);
    notifyListeners();
  }

  /// Update an existing transaction (amount, note, category, type, date)
  void updateTransaction(TransactionItem updated) {
    for (var m in _messages) {
      if (m.transaction != null && m.transaction!.id == updated.id) {
        m.transaction!.amount = updated.amount;
        m.transaction!.note = updated.note;
        m.transaction!.category = updated.category;
        m.transaction!.type = updated.type;
        m.transaction!.occurredAt = updated.occurredAt;
      }
    }

    for (var log in _chatLogs) {
      if (log.transaction != null && log.transaction!.id == updated.id) {
        log.transaction!.amount = updated.amount;
        log.transaction!.note = updated.note;
        log.transaction!.category = updated.category;
        log.transaction!.type = updated.type;
        log.transaction!.occurredAt = updated.occurredAt;
        log.transaction!.isCustomCategory = updated.isCustomCategory;
      }
    }

    recalculateAnalysis(notify: false);
    notifyListeners();
  }

  /// Update category and optionally type or custom status for a transaction
  void updateTransactionCategory(
    String transactionId,
    String newCategory, {
    String? newType,
    bool isCustom = false,
  }) {
    for (var m in _messages) {
      if (m.transaction != null && m.transaction!.id == transactionId) {
        m.transaction!.category = newCategory;
        if (newType != null) {
          m.transaction!.type = newType;
        }
        m.transaction!.isCustomCategory = isCustom;
      }
    }

    for (var log in _chatLogs) {
      if (log.transaction != null && log.transaction!.id == transactionId) {
        log.transaction!.category = newCategory;
        if (newType != null) {
          log.transaction!.type = newType;
        }
        log.transaction!.isCustomCategory = isCustom;
      }
    }

    recalculateAnalysis(notify: false);
    notifyListeners();
  }

  /// Delete a transaction from chat and mark in logs
  ChatMessage? deleteTransaction(String transactionId) {
    ChatMessage? removedMessage;
    int index = -1;

    for (int i = 0; i < _messages.length; i++) {
      if (_messages[i].transaction != null &&
          _messages[i].transaction!.id == transactionId) {
        index = i;
        removedMessage = _messages[i];
        break;
      }
    }

    if (index != -1) {
      _messages.removeAt(index);
    }

    for (var log in _chatLogs) {
      if (log.transaction != null && log.transaction!.id == transactionId) {
        log.status = ChatLogStatus.deleted;
      }
    }

    recalculateAnalysis(notify: false);
    notifyListeners();
    return removedMessage;
  }

  /// Delete a message directly (e.g. from chat screen)
  int deleteMessage(ChatMessage message) {
    final index = _messages.indexOf(message);
    if (index != -1) {
      _messages.removeAt(index);
      if (message.transaction != null) {
        for (var log in _chatLogs) {
          if (log.transaction != null &&
              log.transaction!.id == message.transaction!.id) {
            log.status = ChatLogStatus.deleted;
          }
        }
      }
      recalculateAnalysis(notify: false);
      notifyListeners();
    }
    return index;
  }

  /// Restore deleted message (undo action)
  void restoreMessage(ChatMessage message, int index) {
    if (index >= 0 && index <= _messages.length) {
      _messages.insert(index, message);
    } else {
      _messages.add(message);
    }

    if (message.transaction != null) {
      for (var log in _chatLogs) {
        if (log.transaction != null &&
            log.transaction!.id == message.transaction!.id) {
          log.status = message.transaction!.isConfirmed
              ? ChatLogStatus.confirmed
              : ChatLogStatus.pending;
        }
      }
    }

    recalculateAnalysis(notify: false);
    notifyListeners();
  }

  /// Add manual transaction to state
  void addManualTransaction(TransactionItem tx, {ChatMessage? failedMessage}) {
    if (failedMessage != null) {
      _messages.remove(failedMessage);
    }

    final newMsg = ChatMessage(
      id: 'msg_manual_${DateTime.now().millisecondsSinceEpoch}',
      text: 'Transaksi berhasil dicatat secara manual:',
      isUser: false,
      timestamp: DateTime.now(),
      isAi: true,
      transaction: tx,
    );

    _messages.add(newMsg);

    _chatLogs.insert(
      0,
      ChatLogItem(
        id: 'log_${DateTime.now().millisecondsSinceEpoch}',
        message: tx.note,
        status: ChatLogStatus.confirmed,
        createdAt: DateTime.now(),
        transaction: tx,
      ),
    );

    recalculateAnalysis(notify: false);
    notifyListeners();
  }

  /// Static accessor via InheritedNotifier
  static AppState of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_AppStateScope>();
    return scope?.notifier ?? AppState.instance;
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState super.notifier,
    required super.child,
  });
}

class _AppStateScope extends InheritedNotifier<AppState> {
  const _AppStateScope({
    required super.notifier,
    required super.child,
  });
}
