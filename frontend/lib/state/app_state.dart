import 'package:flutter/material.dart';
import '../mock/mock_data.dart';
import '../models/chat_log_item.dart';
import '../models/chat_message.dart';
import '../models/transaction_item.dart';

class AppState extends ChangeNotifier {
  static AppState? _instance;
  static AppState get instance => _instance ??= AppState._();

  AppState._() {
    _initDefaultState();
  }

  factory AppState() => instance;

  List<ChatMessage> _messages = [];
  List<ChatLogItem> _chatLogs = [];
  bool _isAiTyping = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<ChatLogItem> get chatLogs => List.unmodifiable(_chatLogs);
  bool get isAiTyping => _isAiTyping;

  List<TransactionItem> get confirmedTransactions {
    final list = <TransactionItem>[];
    for (var m in _messages) {
      if (m.transaction != null && m.transaction!.isConfirmed) {
        list.add(m.transaction!);
      }
    }
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
    _isAiTyping = false;
  }

  void resetToDefault() {
    _initDefaultState();
    notifyListeners();
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
      }
    }

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
