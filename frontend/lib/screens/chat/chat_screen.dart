import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../mock/mock_data.dart';
import '../../models/chat_message.dart';
import '../../models/transaction_item.dart';
import '../../theme/app_theme.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/edit_transaction_sheet.dart';
import 'widgets/quick_suggestion_chips.dart';
import 'widgets/transaction_card.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late List<ChatMessage> _messages;
  bool _isAiTyping = false;

  @override
  void initState() {
    super.initState();
    _messages = MockData.getInitialMessages();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final userMessage = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: trimmed,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isAiTyping = true;
    });
    _textController.clear();
    _scrollToBottom();

    // Simulate AI parsing delay (9Router mock)
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      final parsed = MockData.parseText(trimmed);

      final aiMessage = ChatMessage(
        id: 'msg_ai_${DateTime.now().millisecondsSinceEpoch}',
        text: 'AI berhasil mengenali transaksi. Konfirmasi untuk mencatat:',
        isUser: false,
        timestamp: DateTime.now(),
        isAi: true,
        transaction: parsed,
      );

      setState(() {
        _isAiTyping = false;
        _messages.add(aiMessage);
      });
      _scrollToBottom();
    });
  }

  void _handleConfirmTransaction(TransactionItem tx) {
    setState(() {
      tx.isConfirmed = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('Transaksi ${tx.formattedAmount} berhasil disimpan!'),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleChangeCategory(TransactionItem tx) {
    EditTransactionSheet.show(
      context,
      transaction: tx,
      onSave: (updated) {
        setState(() {
          tx.amount = updated.amount;
          tx.note = updated.note;
          tx.category = updated.category;
          tx.type = updated.type;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Data transaksi diperbarui: ${updated.formattedAmount} (${updated.category})'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }

  void _handleDeleteTransaction(ChatMessage message) {
    setState(() {
      _messages.remove(message);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transaksi dibatalkan'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _handleToggleType(TransactionItem tx) {
    setState(() {
      final newType = tx.isExpense ? 'income' : 'expense';
      tx.type = newType;
      tx.category = newType == 'income'
          ? MockData.incomeCategories.first
          : MockData.expenseCategories.first;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Diubah menjadi ${tx.isExpense ? 'Pengeluaran' : 'Pemasukan'}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  double get _todayTotalExpense {
    double total = 0;
    for (var m in _messages) {
      if (m.transaction != null &&
          m.transaction!.isConfirmed &&
          m.transaction!.isExpense) {
        total += m.transaction!.amount;
      }
    }
    return total;
  }

  double get _todayTotalIncome {
    double total = 0;
    for (var m in _messages) {
      if (m.transaction != null &&
          m.transaction!.isConfirmed &&
          m.transaction!.isIncome) {
        total += m.transaction!.amount;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Moneta AI',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '9Router AI Siap',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Reset Percakapan',
            onPressed: () {
              setState(() {
                _messages = MockData.getInitialMessages();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Daily Mini Summary Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(
                bottom: BorderSide(color: AppTheme.borderSubtle),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.trending_down,
                        color: AppTheme.expenseColor, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Keluar: ${currencyFormatter.format(_todayTotalExpense)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(height: 12, width: 1, color: AppTheme.borderSubtle),
                Row(
                  children: [
                    const Icon(Icons.trending_up,
                        color: AppTheme.incomeColor, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Masuk: ${currencyFormatter.format(_todayTotalIncome)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Message list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: _messages.length + (_isAiTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isAiTyping && index == _messages.length) {
                  return Container(
                    margin: const EdgeInsets.only(left: 16, bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.primaryColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '9Router AI sedang menganalisa...',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final message = _messages[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ChatBubble(message: message),
                    if (message.transaction != null)
                      TransactionCard(
                        transaction: message.transaction!,
                        onConfirm: () =>
                            _handleConfirmTransaction(message.transaction!),
                        onChangeCategory: () =>
                            _handleChangeCategory(message.transaction!),
                        onDelete: () => _handleDeleteTransaction(message),
                        onToggleType: () =>
                            _handleToggleType(message.transaction!),
                      ),
                  ],
                );
              },
            ),
          ),

          // Quick Suggestion Chips
          QuickSuggestionChips(
            onSelectSuggestion: (prompt) {
              _textController.text = prompt;
              _handleSendMessage(prompt);
            },
          ),

          // Freeform Chat Input Bar Component
          ChatInputBar(
            controller: _textController,
            isAiTyping: _isAiTyping,
            onSendMessage: _handleSendMessage,
          ),
        ],
      ),
    );
  }
}
