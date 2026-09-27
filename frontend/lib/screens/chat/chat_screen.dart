import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/chat_message.dart';
import '../../models/transaction_item.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../category_confirmation/category_confirmation_screen.dart';
import '../history/transaction_history_screen.dart';
import 'chat_history_screen.dart';
import 'widgets/ai_fallback_card.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/edit_transaction_sheet.dart';
import 'widgets/manual_input_sheet.dart';
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

  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_onStateChange);
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onStateChange);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) setState(() {});
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

    AppState.instance.sendMessage(
      trimmed,
      onAiComplete: _scrollToBottom,
    );
    _textController.clear();
    _scrollToBottom();
  }

  void _openManualInput({String? initialNote, ChatMessage? failedMessage}) {
    ManualInputSheet.show(
      context,
      initialNote: initialNote,
      onSave: (tx) {
        AppState.instance.addManualTransaction(
          tx,
          failedMessage: failedMessage,
        );
        _scrollToBottom();
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
          ),
        );
      },
    );
  }

  void _handleConfirmTransaction(TransactionItem tx) {
    AppState.instance.confirmTransaction(tx.id);

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
        AppState.instance.updateTransaction(updated);
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

  Future<void> _handleDeleteTransaction(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Catatan Transaksi?'),
        content: Text(
          message.transaction != null
              ? 'Catatan "${message.transaction!.note}" senilai ${message.transaction!.formattedAmount} akan dihapus.'
              : 'Pesan transaksi ini akan dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final index = AppState.instance.deleteMessage(message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Transaksi berhasil dihapus'),
          action: SnackBarAction(
            label: 'Urungkan',
            textColor: Colors.amberAccent,
            onPressed: () {
              AppState.instance.restoreMessage(message, index);
            },
          ),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleToggleType(TransactionItem tx) {
    final newType = tx.isExpense ? 'income' : 'expense';
    final defaultCat = newType == 'income' ? 'Gaji' : 'Makan & Minuman';
    final updated = tx.copyWith(type: newType, category: defaultCat);
    AppState.instance.updateTransaction(updated);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Diubah menjadi ${updated.isExpense ? 'Pengeluaran' : 'Pemasukan'}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppState.instance;
    final messages = appState.messages;
    final isAiTyping = appState.isAiTyping;

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
            icon: const Icon(Icons.fact_check_outlined, size: 22),
            tooltip: 'Konfirmasi Kategori AI',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CategoryConfirmationScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_rounded, size: 22),
            tooltip: 'Riwayat Catatan Transaksi',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TransactionHistoryScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded, size: 22),
            tooltip: 'Riwayat Obrolan',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChatHistoryScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, size: 24),
            tooltip: 'Input Transaksi Manual',
            onPressed: () => _openManualInput(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Reset Percakapan',
            onPressed: () {
              appState.resetToDefault();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Daily Mini Summary Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
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
                      'Keluar: ${currencyFormatter.format(appState.todayTotalExpense)}',
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
                      'Masuk: ${currencyFormatter.format(appState.todayTotalIncome)}',
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

          // AI Confirmation Quick Strip
          Material(
            color: AppTheme.primaryLight.withValues(alpha: 0.08),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CategoryConfirmationScreen(),
                  ),
                );
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Review kartu konfirmasi & kategori otomatis AI',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Message list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: messages.length + (isAiTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (isAiTyping && index == messages.length) {
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

                final message = messages[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ChatBubble(message: message),
                    if (message.isAiFailed && message.failedRawText != null)
                      AiFallbackCard(
                        rawText: message.failedRawText!,
                        onManualInput: () => _openManualInput(
                          initialNote: message.failedRawText,
                          failedMessage: message,
                        ),
                        onRetry: () {
                          appState.deleteMessage(message);
                          _handleSendMessage(message.failedRawText!);
                        },
                      ),
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
            isAiTyping: isAiTyping,
            onSendMessage: _handleSendMessage,
          ),
        ],
      ),
    );
  }
}
