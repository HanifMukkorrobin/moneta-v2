import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/monthly_rekap_data.dart';
import '../../../theme/app_theme.dart';

enum ChartViewMode {
  donut,
  bar,
}

class CategoryProportionChart extends StatefulWidget {
  final List<CategoryBreakdownItem> items;
  final double totalAmount;
  final String title;
  final String type; // 'expense' or 'income'
  final String? selectedCategory;
  final ValueChanged<String?> onCategorySelected;

  const CategoryProportionChart({
    super.key,
    required this.items,
    required this.totalAmount,
    this.title = 'Proporsi Pengeluaran per Kategori',
    this.type = 'expense',
    this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  State<CategoryProportionChart> createState() => _CategoryProportionChartState();
}

class _CategoryProportionChartState extends State<CategoryProportionChart> {
  ChartViewMode _viewMode = ChartViewMode.donut;

  CategoryBreakdownItem? get _selectedItem {
    if (widget.selectedCategory == null) return null;
    try {
      return widget.items.firstWhere(
        (i) => i.category.toLowerCase() == widget.selectedCategory!.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        alignment: Alignment.center,
        child: Text(
          'Belum ada transaksi ${widget.type == 'expense' ? 'pengeluaran' : 'pemasukan'} untuk ditampilkan.',
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chart Header & Mode Toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${widget.items.length} Kategori Tercatat',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            // Donut vs Bar switcher
            Container(
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildModeButton(
                    mode: ChartViewMode.donut,
                    icon: Icons.pie_chart_outline_rounded,
                    tooltip: 'Grafik Donat',
                    keyName: 'chart_mode_donut',
                  ),
                  _buildModeButton(
                    mode: ChartViewMode.bar,
                    icon: Icons.bar_chart_rounded,
                    tooltip: 'Grafik Batang Proporsi',
                    keyName: 'chart_mode_bar',
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Visual Graphic View
        if (_viewMode == ChartViewMode.donut)
          _buildDonutView()
        else
          _buildHorizontalBarView(),

        const SizedBox(height: 20),

        // Detailed Category Breakdown Items
        _buildCategoryProportionList(),
      ],
    );
  }

  Widget _buildModeButton({
    required ChartViewMode mode,
    required IconData icon,
    required String tooltip,
    required String keyName,
  }) {
    final isSelected = _viewMode == mode;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: Key(keyName),
        onTap: () {
          setState(() {
            _viewMode = mode;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildDonutView() {
    final selectedItem = _selectedItem;

    return Center(
      child: SizedBox(
        width: 220,
        height: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(220, 220),
              painter: CategoryDonutChartPainter(
                items: widget.items,
                selectedCategory: widget.selectedCategory,
              ),
            ),
            // Center Content
            Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    selectedItem != null ? selectedItem.category : 'Total',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    selectedItem != null
                        ? selectedItem.formattedPercentage
                        : '${widget.items.first.category} ${widget.items.first.formattedPercentage}',
                    style: TextStyle(
                      fontSize: selectedItem != null ? 18 : 13,
                      fontWeight: FontWeight.w800,
                      color: selectedItem?.color ?? AppTheme.primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    selectedItem != null
                        ? selectedItem.formattedTotal
                        : 'Top Kategori',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalBarView() {
    return Column(
      children: [
        // Multi-segment horizontal distribution bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 16,
            child: Row(
              children: widget.items.map((item) {
                final flex = (item.percentage * 10).round();
                if (flex <= 0) return const SizedBox.shrink();
                final isSelected = widget.selectedCategory?.toLowerCase() ==
                    item.category.toLowerCase();

                return Expanded(
                  flex: flex,
                  child: InkWell(
                    onTap: () {
                      if (isSelected) {
                        widget.onCategorySelected(null);
                      } else {
                        widget.onCategorySelected(item.category);
                      }
                    },
                    child: Container(
                      color: item.color ?? Colors.blueGrey,
                      decoration: isSelected
                          ? BoxDecoration(
                              border: Border.all(color: Colors.black, width: 2),
                            )
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Terbesar: ${widget.items.first.category} (${widget.items.first.formattedPercentage})',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
            if (widget.selectedCategory != null)
              InkWell(
                onTap: () => widget.onCategorySelected(null),
                child: const Text(
                  'Reset Filter',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryProportionList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.items.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderSubtle),
      itemBuilder: (context, index) {
        final item = widget.items[index];
        final isSelected = widget.selectedCategory?.toLowerCase() ==
            item.category.toLowerCase();

        return InkWell(
          key: Key('category_chart_item_${item.category}'),
          onTap: () {
            if (isSelected) {
              widget.onCategorySelected(null);
            } else {
              widget.onCategorySelected(item.category);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? (item.color ?? AppTheme.primaryColor).withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(
                      color: (item.color ?? AppTheme.primaryColor).withValues(alpha: 0.3),
                    )
                  : null,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Color pill & Icon
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: (item.color ?? Colors.grey).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        item.icon ?? Icons.bookmark_border_rounded,
                        size: 17,
                        color: item.color ?? AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Category name & transaction count
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  item.category,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (item.isCustom) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.purple.shade200),
                                  ),
                                  child: const Text(
                                    'Kustom',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.transactionCount} transaksi',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Amount and Percentage Badge
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          item.formattedTotal,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: widget.type == 'expense'
                                ? AppTheme.textPrimary
                                : AppTheme.incomeColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: (item.color ?? Colors.grey).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.formattedPercentage,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: item.color ?? AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Horizontal proportion progress bar for individual item
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (item.percentage.clamp(0.0, 100.0)) / 100,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      item.color ?? AppTheme.primaryColor,
                    ),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CategoryDonutChartPainter extends CustomPainter {
  final List<CategoryBreakdownItem> items;
  final String? selectedCategory;

  CategoryDonutChartPainter({
    required this.items,
    this.selectedCategory,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 16;
    double startAngle = -math.pi / 2; // Start from top (12 o'clock)

    final totalPercentage = items.fold<double>(0.0, (acc, item) => acc + item.percentage);
    final hasSingleItem = items.length == 1;

    for (final item in items) {
      if (item.percentage <= 0) continue;

      final isSelected = selectedCategory != null &&
          selectedCategory!.toLowerCase() == item.category.toLowerCase();

      final sliceFraction = totalPercentage > 0 ? (item.percentage / totalPercentage) : 0.0;
      final sweepAngle = sliceFraction * 2 * math.pi;

      final gap = hasSingleItem ? 0.0 : 0.03;
      final adjustedSweep = math.max(0.0, sweepAngle - gap);

      final paint = Paint()
        ..color = item.color ?? Colors.blueGrey
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 30.0 : 22.0
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + (gap / 2),
        adjustedSweep,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CategoryDonutChartPainter oldDelegate) {
    return oldDelegate.selectedCategory != selectedCategory ||
        oldDelegate.items != items;
  }
}
