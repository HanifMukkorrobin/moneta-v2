import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';

class AdjustAllocationPercentagesSheet extends StatefulWidget {
  final double totalBudget;
  final double initialNeedsPct;
  final double initialSavingsPct;
  final double initialFunPct;
  final void Function(double needsPct, double savingsPct, double funPct) onSave;

  const AdjustAllocationPercentagesSheet({
    super.key,
    required this.totalBudget,
    required this.initialNeedsPct,
    required this.initialSavingsPct,
    required this.initialFunPct,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required double totalBudget,
    required double initialNeedsPct,
    required double initialSavingsPct,
    required double initialFunPct,
    required void Function(double needsPct, double savingsPct, double funPct) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AdjustAllocationPercentagesSheet(
        totalBudget: totalBudget,
        initialNeedsPct: initialNeedsPct,
        initialSavingsPct: initialSavingsPct,
        initialFunPct: initialFunPct,
        onSave: onSave,
      ),
    );
  }

  @override
  State<AdjustAllocationPercentagesSheet> createState() => _AdjustAllocationPercentagesSheetState();
}

class _AdjustAllocationPercentagesSheetState extends State<AdjustAllocationPercentagesSheet> {
  late double _needsPct;
  late double _savingsPct;
  late double _funPct;

  @override
  void initState() {
    super.initState();
    _needsPct = widget.initialNeedsPct;
    _savingsPct = widget.initialSavingsPct;
    _funPct = widget.initialFunPct;
  }

  double get _totalPct => _needsPct + _savingsPct + _funPct;
  bool get _isValid => (_totalPct - 100.0).abs() < 0.01;

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  void _applyPreset(double needs, double savings, double fun) {
    setState(() {
      _needsPct = needs;
      _savingsPct = savings;
      _funPct = fun;
    });
  }

  void _adjustNeeds(double delta) {
    setState(() {
      _needsPct = (_needsPct + delta).clamp(0.0, 100.0);
    });
  }

  void _adjustSavings(double delta) {
    setState(() {
      _savingsPct = (_savingsPct + delta).clamp(0.0, 100.0);
    });
  }

  void _adjustFun(double delta) {
    setState(() {
      _funPct = (_funPct + delta).clamp(0.0, 100.0);
    });
  }

  void _handleSave() {
    if (!_isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _totalPct < 100
                ? 'Total persentase harus 100%. Masih kurang ${(100 - _totalPct).toStringAsFixed(0)}%.'
                : 'Total persentase harus 100%. Melebihi batas sebesar ${(_totalPct - 100).toStringAsFixed(0)}%.',
          ),
          backgroundColor: AppTheme.expenseColor,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    widget.onSave(_needsPct, _savingsPct, _funPct);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final total = _totalPct;
    final isValid = _isValid;

    Color validationColor;
    String validationMessage;
    IconData validationIcon;

    if (isValid) {
      validationColor = AppTheme.incomeColor;
      validationMessage = 'Total Alokasi 100% (Sempurna & Siap Digunakan)';
      validationIcon = Icons.check_circle_rounded;
    } else if (total < 100) {
      validationColor = Colors.amber.shade800;
      validationMessage = 'Total alokasi ${total.toStringAsFixed(0)}%. Kurang ${(100 - total).toStringAsFixed(0)}% lagi untuk mencapai 100%.';
      validationIcon = Icons.info_outline_rounded;
    } else {
      validationColor = AppTheme.expenseColor;
      validationMessage = 'Total alokasi ${total.toStringAsFixed(0)}%. Kelebihan ${(total - 100).toStringAsFixed(0)}% dari batas 100%.';
      validationIcon = Icons.error_outline_rounded;
    }

    return Container(
      key: const Key('adjust_allocation_sheet'),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: 20 + bottomInset,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Sheet Title & Close
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Atur Persentase Alokasi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Plafon Budget: ${_formatCurrency(widget.totalBudget)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Presets Selector
            const Text(
              'Pilihan Template Populer:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPresetChip(
                  key: 'preset_allocation_50_30_20',
                  label: 'Klasik (50/30/20)',
                  needs: 50,
                  savings: 30,
                  fun: 20,
                ),
                _buildPresetChip(
                  key: 'preset_allocation_40_40_20',
                  label: 'Hemat & Invest (40/40/20)',
                  needs: 40,
                  savings: 40,
                  fun: 20,
                ),
                _buildPresetChip(
                  key: 'preset_allocation_60_25_15',
                  label: 'Kebutuhan Tinggi (60/25/15)',
                  needs: 60,
                  savings: 25,
                  fun: 15,
                ),
                _buildPresetChip(
                  key: 'preset_allocation_35_50_15',
                  label: 'Agresif Nabung (35/50/15)',
                  needs: 35,
                  savings: 50,
                  fun: 15,
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Live Proportion Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    if (_needsPct > 0)
                      Expanded(
                        flex: _needsPct.round(),
                        child: Container(color: const Color(0xFF2563EB)),
                      ),
                    if (_savingsPct > 0)
                      Expanded(
                        flex: _savingsPct.round(),
                        child: Container(color: const Color(0xFF10B981)),
                      ),
                    if (_funPct > 0)
                      Expanded(
                        flex: _funPct.round(),
                        child: Container(color: const Color(0xFF8B5CF6)),
                      ),
                    if (total < 100)
                      Expanded(
                        flex: (100 - total).round(),
                        child: Container(color: Colors.grey.shade300),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Validation Status Box
            Container(
              key: const Key('allocation_validation_box'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: validationColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: validationColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(validationIcon, size: 16, color: validationColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      validationMessage,
                      key: const Key('allocation_total_percentage_text'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: validationColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Bucket 1: Kebutuhan Pokok
            _buildBucketControl(
              title: 'Kebutuhan Pokok',
              icon: Icons.home_work_rounded,
              color: const Color(0xFF2563EB),
              percentage: _needsPct,
              nominal: widget.totalBudget * (_needsPct / 100),
              stepperMinusKey: 'stepper_minus_needs',
              stepperPlusKey: 'stepper_plus_needs',
              sliderKey: 'slider_needs',
              onChanged: (val) => setState(() => _needsPct = val),
              onAdjust: _adjustNeeds,
            ),

            const SizedBox(height: 12),

            // Bucket 2: Tabungan & Investasi
            _buildBucketControl(
              title: 'Tabungan & Investasi',
              icon: Icons.savings_rounded,
              color: const Color(0xFF10B981),
              percentage: _savingsPct,
              nominal: widget.totalBudget * (_savingsPct / 100),
              stepperMinusKey: 'stepper_minus_savings',
              stepperPlusKey: 'stepper_plus_savings',
              sliderKey: 'slider_savings',
              onChanged: (val) => setState(() => _savingsPct = val),
              onAdjust: _adjustSavings,
            ),

            const SizedBox(height: 12),

            // Bucket 3: Hiburan & Keinginan
            _buildBucketControl(
              title: 'Hiburan & Keinginan',
              icon: Icons.celebration_rounded,
              color: const Color(0xFF8B5CF6),
              percentage: _funPct,
              nominal: widget.totalBudget * (_funPct / 100),
              stepperMinusKey: 'stepper_minus_fun',
              stepperPlusKey: 'stepper_plus_fun',
              sliderKey: 'slider_fun',
              onChanged: (val) => setState(() => _funPct = val),
              onAdjust: _adjustFun,
            ),

            const SizedBox(height: 24),

            // Action Buttons (Save & Reset)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('reset_allocation_button'),
                    onPressed: () => _applyPreset(50, 30, 20),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: const BorderSide(color: AppTheme.borderSubtle),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Reset 50/30/20', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    key: const Key('save_allocation_button'),
                    onPressed: isValid ? _handleSave : () => _handleSave(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isValid ? AppTheme.primaryColor : Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: isValid ? 2 : 0,
                    ),
                    child: const Text(
                      'Simpan Alokasi',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip({
    required String key,
    required String label,
    required double needs,
    required double savings,
    required double fun,
  }) {
    final isSelected = (_needsPct == needs && _savingsPct == savings && _funPct == fun);

    return InkWell(
      key: Key(key),
      onTap: () => _applyPreset(needs, savings, fun),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildBucketControl({
    required String title,
    required IconData icon,
    required Color color,
    required double percentage,
    required double nominal,
    required String stepperMinusKey,
    required String stepperPlusKey,
    required String sliderKey,
    required ValueChanged<double> onChanged,
    required void Function(double delta) onAdjust,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      _formatCurrency(nominal),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              // Stepper buttons & percentage badge
              Row(
                children: [
                  IconButton(
                    key: Key(stepperMinusKey),
                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                    color: AppTheme.textSecondary,
                    visualDensity: VisualDensity.compact,
                    onPressed: percentage > 0 ? () => onAdjust(-5) : null,
                  ),
                  Container(
                    width: 44,
                    alignment: Alignment.center,
                    child: Text(
                      '${percentage.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    key: Key(stepperPlusKey),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                    color: AppTheme.primaryColor,
                    visualDensity: VisualDensity.compact,
                    onPressed: percentage < 100 ? () => onAdjust(5) : null,
                  ),
                ],
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              activeTrackColor: color,
              thumbColor: color,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              key: Key(sliderKey),
              value: percentage.clamp(0.0, 100.0),
              min: 0,
              max: 100,
              divisions: 20,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
