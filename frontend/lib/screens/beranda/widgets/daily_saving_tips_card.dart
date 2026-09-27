import 'package:flutter/material.dart';
import '../../../mock/saving_tips_mock_data.dart';
import '../../../models/saving_tip_item.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/currency_format.dart';

class DailySavingTipsCard extends StatefulWidget {
  final List<SavingTipItem>? initialTips;
  final Function(SavingTipItem, bool)? onToggleTip;

  const DailySavingTipsCard({
    super.key,
    this.initialTips,
    this.onToggleTip,
  });

  @override
  State<DailySavingTipsCard> createState() => _DailySavingTipsCardState();
}

class _DailySavingTipsCardState extends State<DailySavingTipsCard> {
  late List<SavingTipItem> _tips;
  String _selectedCategory = 'Semua';

  @override
  void initState() {
    super.initState();
    _tips = List.of(widget.initialTips ?? SavingTipsMockData.getDailyTips());
  }

  @override
  void didUpdateWidget(covariant DailySavingTipsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTips != null && widget.initialTips != oldWidget.initialTips) {
      _tips = List.of(widget.initialTips!);
    }
  }

  List<SavingTipItem> get _filteredTips {
    if (_selectedCategory == 'Semua') return _tips;
    return _tips.where((t) => t.category == _selectedCategory).toList();
  }

  int get _appliedCount => _tips.where((t) => t.isApplied).length;

  double get _totalPotentialSavings {
    double total = 0;
    for (var tip in _tips) {
      total += tip.potentialSaving;
    }
    return total;
  }

  void _toggleApply(SavingTipItem tip) {
    final newStatus = !tip.isApplied;
    final index = _tips.indexWhere((t) => t.id == tip.id);
    if (index != -1) {
      setState(() {
        _tips[index] = tip.copyWith(isApplied: newStatus);
      });
      widget.onToggleTip?.call(_tips[index], newStatus);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus
                ? 'Tip diterapkan: "${tip.title}". Pertahankan konsistensi!'
                : 'Tip dibatalkan dari daftar penerapan.',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['Semua', 'Makan & Minuman', 'Belanja', 'Tagihan & Utilitas', 'Transportasi'];

    return Container(
      key: const Key('daily_saving_tips_card'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title & Counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lightbulb_rounded,
                      size: 18,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Tips Hemat Harian',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                key: const Key('tips_applied_counter_badge'),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  '$_appliedCount/${_tips.length} Diterapkan',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Category filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryColor,
                    backgroundColor: AppTheme.surfaceColor,
                    visualDensity: VisualDensity.compact,
                    showCheckmark: false,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : AppTheme.borderSubtle,
                      ),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // Tips List
          if (_filteredTips.isEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: const Text(
                'Tidak ada tips untuk kategori ini.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
          ] else ...[
            ..._filteredTips.map((tip) => _TipItemTile(
                  key: Key('tip_tile_${tip.id}'),
                  tip: tip,
                  onToggle: () => _toggleApply(tip),
                )),
          ],

          const SizedBox(height: 8),

          // Footer: Total Potential Savings Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.trending_up_rounded,
                  size: 16,
                  color: Color(0xFF10B981),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Potensi hemat kolektif: ${CurrencyFormat.formatRupiah(_totalPotentialSavings)}',
                    key: const Key('total_potential_savings_text'),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF047857),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TipItemTile extends StatelessWidget {
  final SavingTipItem tip;
  final VoidCallback onToggle;

  const _TipItemTile({
    super.key,
    required this.tip,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isApplied = tip.isApplied;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isApplied
            ? const Color(0xFF10B981).withValues(alpha: 0.05)
            : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isApplied
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : AppTheme.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isApplied
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isApplied ? Icons.check_circle_rounded : tip.icon,
                  size: 16,
                  color: isApplied
                      ? const Color(0xFF10B981)
                      : AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tip.title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isApplied
                        ? const Color(0xFF047857)
                        : AppTheme.textPrimary,
                    decoration: isApplied ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: tip.impactColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Hemat ${tip.formattedPotentialSaving}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: tip.impactColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(
              tip.description,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: InkWell(
              key: Key('btn_apply_tip_${tip.id}'),
              onTap: onToggle,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isApplied
                      ? const Color(0xFF10B981)
                      : AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isApplied ? Icons.check_rounded : Icons.add_task_rounded,
                      size: 13,
                      color: isApplied ? Colors.white : AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isApplied ? 'Sudah Diterapkan' : tip.actionText,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isApplied ? Colors.white : AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
