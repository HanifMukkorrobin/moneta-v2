import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class BudgetAlertSettingsCard extends StatelessWidget {
  final bool isAlertEnabled;
  final double alertThreshold;
  final bool isPushNotificationEnabled;
  final bool isOverBudgetAlertEnabled;
  final ValueChanged<bool> onToggleAlert;
  final ValueChanged<double>? onSelectThreshold;
  final ValueChanged<bool>? onTogglePushNotification;
  final ValueChanged<bool>? onToggleOverBudgetAlert;

  const BudgetAlertSettingsCard({
    super.key,
    required this.isAlertEnabled,
    this.alertThreshold = 80.0,
    this.isPushNotificationEnabled = true,
    this.isOverBudgetAlertEnabled = true,
    required this.onToggleAlert,
    this.onSelectThreshold,
    this.onTogglePushNotification,
    this.onToggleOverBudgetAlert,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('budget_alert_settings_card'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + Title + Master Switch
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isAlertEnabled
                      ? AppTheme.primaryColor.withValues(alpha: 0.1)
                      : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAlertEnabled
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_outlined,
                  size: 18,
                  color: isAlertEnabled ? AppTheme.primaryColor : Colors.grey.shade500,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Peringatan Budget',
                      key: Key('budget_alert_settings_title'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      isAlertEnabled
                          ? 'Notifikasi & peringatan batas aktif'
                          : 'Peringatan dinonaktifkan',
                      style: TextStyle(
                        fontSize: 11,
                        color: isAlertEnabled ? AppTheme.primaryColor : AppTheme.textSecondary,
                        fontWeight: isAlertEnabled ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                key: const Key('toggle_budget_warning_switch'),
                value: isAlertEnabled,
                activeColor: AppTheme.primaryColor,
                onChanged: onToggleAlert,
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (isAlertEnabled) ...[
            const Divider(color: AppTheme.borderSubtle, height: 1),
            const SizedBox(height: 14),

            // Threshold Selection Section
            const Text(
              'Ambang Batas Peringatan:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [80.0, 85.0, 90.0].map((t) {
                final isSelected = (alertThreshold - t).abs() < 0.1;
                final keyLabel = t.toStringAsFixed(0);

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    key: Key('threshold_chip_$keyLabel'),
                    onTap: onSelectThreshold != null ? () => onSelectThreshold!(t) : null,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.borderSubtle,
                        ),
                      ),
                      child: Text(
                        '$keyLabel%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 14),

            // Sub-options: Over Budget Alert & Push Notification
            _buildSubOptionRow(
              title: 'Peringatan Melewati Batas',
              subtitle: 'Munculkan peringatan darurat saat anggaran terlampaui',
              switchKey: 'toggle_overbudget_alert_switch',
              value: isOverBudgetAlertEnabled,
              onChanged: onToggleOverBudgetAlert,
            ),

            const SizedBox(height: 10),

            _buildSubOptionRow(
              title: 'Notifikasi Pengingat Harian',
              subtitle: 'Pengingat saran belanja harian sesuai sisa budget',
              switchKey: 'toggle_push_notification_switch',
              value: isPushNotificationEnabled,
              onChanged: onTogglePushNotification,
            ),

            const SizedBox(height: 12),

            // Information Status Container
            Container(
              key: const Key('budget_alert_status_box'),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 15, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Peringatan aktif: Anda akan diberi peringatan saat pengeluaran mencapai ${alertThreshold.toStringAsFixed(0)}% dari plafon.',
                      key: const Key('budget_alert_status_text'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Disabled State Banner
            Container(
              key: const Key('budget_alert_disabled_banner'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Peringatan budget sedang dinonaktifkan. Anda tidak akan menerima banner peringatan saat belanja mendekati batas.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubOptionRow({
    required String title,
    required String subtitle,
    required String switchKey,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          key: Key(switchKey),
          value: value,
          activeColor: AppTheme.primaryColor,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
