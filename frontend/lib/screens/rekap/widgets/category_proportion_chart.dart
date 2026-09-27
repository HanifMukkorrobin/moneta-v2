import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/monthly_rekap_data.dart';
import '../../../theme/app_theme.dart';
import 'category_nominal_persentase_list.dart';

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
        key: const Key('category_proportion_empty_message'),
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.pie_chart_outline_rounded,
              size: 40,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 10),
            Text(
              'Belum ada transaksi ${widget.type == 'expense' ? 'pengeluaran' : 'pemasukan'} untuk ditampilkan.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Catat transaksi melalui obrolan chat untuk melihat proporsi kategori.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ],
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

        // Detailed Category Breakdown Items (Daftar Kategori dengan Nominal dan Persentase)
        CategoryNominalPersentaseList(
          items: widget.items,
          type: widget.type,
          selectedCategory: widget.selectedCategory,
          onCategorySelected: widget.onCategorySelected,
        ),
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
            Flexible(
              child: Text(
                'Terbesar: ${widget.items.first.category} (${widget.items.first.formattedPercentage})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
