import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/chat_log_item.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../category_confirmation/widgets/category_picker_sheet.dart';
import '../history/transaction_history_screen.dart';
import 'widgets/transaction_card.dart';

class ChatHistoryScreen extends StatefulWidget {
  final List<ChatLogItem>? initialLogs;
  final Function(ChatLogItem)? onConfirmPending;

  const ChatHistoryScreen({
    super.key,
    this.initialLogs,
    this.onConfirmPending,
  });

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  String _selectedFilter = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_onStateChange);
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onStateChange);
    _searchController.dispose();
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  List<ChatLogItem> get _logs =>
      widget.initialLogs ?? AppState.instance.chatLogs;

  List<ChatLogItem> get _filteredLogs {
    return _logs.where((item) {
      // Filter status
      if (_selectedFilter == 'confirmed' && !item.isConfirmed) return false;
      if (_selectedFilter == 'pending' && !item.isPending) return false;
      if (_selectedFilter == 'deleted' && !item.isDeleted) return false;
      if (_selectedFilter == 'failed' && !item.isFailed) return false;

      // Filter search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesMsg = item.message.toLowerCase().contains(query);
        final matchesTx = item.transaction != null &&
            (item.transaction!.note.toLowerCase().contains(query) ||
                item.transaction!.category.toLowerCase().contains(query));
        return matchesMsg || matchesTx;
      }
      return true;
    }).toList();
  }

  Color _getStatusColor(ChatLogStatus status) {
    switch (status) {
      case ChatLogStatus.confirmed:
        return AppTheme.incomeColor;
      case ChatLogStatus.pending:
        return const Color(0xFFD97706); // Amber
      case ChatLogStatus.deleted:
        return AppTheme.textSecondary;
      case ChatLogStatus.failed:
        return AppTheme.expenseColor;
    }
  }

  Widget _buildStatusBadge(ChatLogStatus status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = _logs.length;
    final confirmedCount = _logs.where((l) => l.isConfirmed).length;
    final pendingCount = _logs.where((l) => l.isPending).length;
    final deletedCount = _logs.where((l) => l.isDeleted).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Obrolan'),
        actions: [
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
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Segarkan',
            onPressed: () {
              AppState.instance.resetToDefault();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner link to full transaction history
          Material(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TransactionHistoryScreen(),
                  ),
                );
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: const [
                    Icon(
                      Icons.category_rounded,
                      size: 15,
                      color: AppTheme.primaryColor,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Kelola & ganti kategori catatan transaksi lengkap →',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Quick Stats Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Semua', totalCount.toString(), AppTheme.textPrimary),
                _buildStatItem('Tersimpan', confirmedCount.toString(), AppTheme.incomeColor),
                _buildStatItem('Menunggu', pendingCount.toString(), const Color(0xFFD97706)),
                _buildStatItem('Dibatalkan', deletedCount.toString(), AppTheme.textSecondary),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderSubtle),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
              decoration: InputDecoration(
                hintText: 'Cari pesan obrolan atau transaksi...',
                prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                fillColor: Colors.white,
              ),
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('Semua', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Tersimpan', 'confirmed'),
                const SizedBox(width: 8),
                _buildFilterChip('Menunggu', 'pending'),
                const SizedBox(width: 8),
                _buildFilterChip('Dibatalkan', 'deleted'),
                const SizedBox(width: 8),
                _buildFilterChip('Gagal', 'failed'),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Log List
          Expanded(
            child: _filteredLogs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                        const SizedBox(height: 10),
                        const Text(
                          'Tidak ada riwayat obrolan ditemukan',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredLogs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _filteredLogs[index];
                      final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(item.createdAt);

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.borderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: Time and Status
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.chat_bubble_outline_rounded,
                                        size: 14, color: AppTheme.textSecondary),
                                    const SizedBox(width: 6),
                                    Text(
                                      dateStr,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                _buildStatusBadge(item.status),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Chat message text
                            Text(
                              item.message,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),

                            // Resulting transaction if any
                            if (item.transaction != null) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.borderSubtle),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          TransactionCard.getCategoryIcon(
                                            item.transaction!.category,
                                            item.transaction!.isExpense,
                                          ),
                                          size: 16,
                                          color: AppTheme.primaryColor,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${item.transaction!.category} • ${item.transaction!.formattedAmount}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: item.transaction!.isExpense
                                                  ? AppTheme.expenseColor
                                                  : AppTheme.incomeColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton(
                                          onPressed: () {
                                            CategoryPickerSheet.show(
                                              context,
                                              initialCategory:
                                                  item.transaction!.category,
                                              initialType:
                                                  item.transaction!.type,
                                              onSelected:
                                                  (newCat, newType, isCustom) {
                                                final oldCat =
                                                    item.transaction!.category;
                                                AppState.instance
                                                    .updateTransactionCategory(
                                                  item.transaction!.id,
                                                  newCat,
                                                  newType: newType,
                                                  isCustom: isCustom,
                                                );
                                                ScaffoldMessenger.of(context)
                                                    .hideCurrentSnackBar();
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                        'Kategori catatan diubah: $oldCat → $newCat'),
                                                    behavior:
                                                        SnackBarBehavior.floating,
                                                    duration:
                                                        const Duration(seconds: 2),
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                          style: TextButton.styleFrom(
                                            foregroundColor:
                                                AppTheme.primaryColor,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(Icons.edit_rounded, size: 13),
                                              SizedBox(width: 4),
                                              Text('Ganti Kategori',
                                                  style: TextStyle(fontSize: 11)),
                                            ],
                                          ),
                                        ),
                                        if (item.isPending) ...[
                                          const SizedBox(width: 8),
                                          TextButton(
                                            onPressed: () {
                                              if (item.transaction != null) {
                                                AppState.instance
                                                    .confirmTransaction(
                                                        item.transaction!.id);
                                              } else {
                                                setState(() {
                                                  item.status =
                                                      ChatLogStatus.confirmed;
                                                });
                                              }
                                              widget.onConfirmPending?.call(item);
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                      'Transaksi dikonfirmasi!'),
                                                  duration:
                                                      Duration(seconds: 1),
                                                ),
                                              );
                                            },
                                            style: TextButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8, vertical: 2),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize
                                                  .shrinkWrap,
                                            ),
                                            child: const Text('Simpan',
                                                style: TextStyle(fontSize: 12)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String count, Color color) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        fontSize: 12,
        color: isSelected ? Colors.white : AppTheme.textPrimary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = value;
          });
        }
      },
    );
  }
}
