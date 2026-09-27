import 'package:flutter/material.dart';
import '../../models/daily_reminder_settings.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';

class PengaturanPengingatScreen extends StatefulWidget {
  final DailyReminderSettings? initialSettings;
  final Function(DailyReminderSettings)? onSave;

  const PengaturanPengingatScreen({
    super.key,
    this.initialSettings,
    this.onSave,
  });

  @override
  State<PengaturanPengingatScreen> createState() =>
      _PengaturanPengingatScreenState();
}

class _PengaturanPengingatScreenState extends State<PengaturanPengingatScreen> {
  late DailyReminderSettings _settings;
  bool _showMockNotificationPreview = false;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings ?? AppState.instance.reminderSettings;
  }

  void _saveSettings() {
    AppState.instance.updateReminderSettings(_settings);
    widget.onSave?.call(_settings);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pengaturan pengingat harian berhasil disimpan.'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.maybePop(context);
  }

  Future<void> _pickMorningTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _settings.morningReminderTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _settings = _settings.copyWith(morningReminderTime: picked);
      });
    }
  }

  Future<void> _pickEveningTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _settings.eveningReminderTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _settings = _settings.copyWith(eveningReminderTime: picked);
      });
    }
  }

  void _toggleDay(int day) {
    final updatedDays = List<int>.from(_settings.activeDays);
    if (updatedDays.contains(day)) {
      if (updatedDays.length > 1) {
        updatedDays.remove(day);
      } else {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Minimal harus ada 1 hari aktif pengingat.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    } else {
      updatedDays.add(day);
    }
    setState(() {
      _settings = _settings.copyWith(activeDays: updatedDays);
    });
  }

  void _triggerTestNotification() {
    setState(() {
      _showMockNotificationPreview = true;
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notifikasi percobaan berhasil disimulasikan.'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMasterEnabled = _settings.isEnabled;

    return Scaffold(
      key: const Key('pengaturan_pengingat_screen'),
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Pengingat Harian',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        actions: [
          TextButton(
            key: const Key('btn_save_reminder_settings'),
            onPressed: _saveSettings,
            child: const Text(
              'Simpan',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview Notifikasi jika di-trigger
            if (_showMockNotificationPreview) _buildNotificationMockBanner(),

            // Master Toggle Card
            _buildMasterToggleCard(),

            // Section 1: Jadwal Jam Pengingat
            _buildSectionHeader('Jadwal Pengingat'),
            _buildScheduleCard(
              cardKey: 'card_morning_reminder',
              switchKey: 'switch_morning_reminder',
              timeBtnKey: 'btn_change_morning_reminder_time',
              timeTextKey: 'text_morning_reminder_time',
              icon: Icons.wb_sunny_rounded,
              iconColor: Colors.amber,
              title: 'Saran Harian Pagi',
              subtitle:
                  'Saran batas belanja harian & perkiraan ketahanan uang.',
              timeFormatted: _settings.morningTimeFormatted,
              isEnabled: isMasterEnabled && _settings.isMorningReminderEnabled,
              onToggleSwitch: (val) {
                if (!isMasterEnabled) return;
                setState(() {
                  _settings = _settings.copyWith(isMorningReminderEnabled: val);
                });
              },
              onTapTime: isMasterEnabled && _settings.isMorningReminderEnabled
                  ? _pickMorningTime
                  : null,
            ),
            _buildScheduleCard(
              cardKey: 'card_evening_reminder',
              switchKey: 'switch_evening_reminder',
              timeBtnKey: 'btn_change_evening_reminder_time',
              timeTextKey: 'text_evening_reminder_time',
              icon: Icons.nights_stay_rounded,
              iconColor: const Color(0xFF6366F1),
              title: 'Evaluasi Catatan Malam',
              subtitle: 'Pengingat untuk mencatat pengeluaran sebelum istirahat.',
              timeFormatted: _settings.eveningTimeFormatted,
              isEnabled: isMasterEnabled && _settings.isEveningReminderEnabled,
              onToggleSwitch: (val) {
                if (!isMasterEnabled) return;
                setState(() {
                  _settings = _settings.copyWith(isEveningReminderEnabled: val);
                });
              },
              onTapTime: isMasterEnabled && _settings.isEveningReminderEnabled
                  ? _pickEveningTime
                  : null,
            ),

            // Section 2: Hari Aktif
            _buildSectionHeader('Hari Aktif'),
            _buildActiveDaysCard(isMasterEnabled),

            // Section 3: Peringatan Cerdas AI
            _buildSectionHeader('Peringatan Cerdas AI'),
            _buildSmartAlertsCard(isMasterEnabled),

            // Section 4: Preferensi Sistem
            _buildSectionHeader('Preferensi Notifikasi'),
            _buildPreferencesCard(isMasterEnabled),

            // Section 5: Uji Coba Notifikasi
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                key: const Key('btn_test_notification'),
                onPressed: _triggerTestNotification,
                icon: const Icon(Icons.notifications_active_outlined, size: 18),
                label: const Text('Kirim Notifikasi Percobaan (Simulasi)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),

            const SizedBox(height: 20),
            // Tombol Simpan Utama di Bawah
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                key: const Key('btn_bottom_save_settings'),
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text(
                  'Simpan Pengaturan',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationMockBanner() {
    return Container(
      key: const Key('notification_mock_preview'),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 13,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Moneta AI • Saran Pagi Ini',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  setState(() {
                    _showMockNotificationPreview = false;
                  });
                },
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Batas Belanja Aman: Rp 65.000 / Hari',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Hari ini sisakan porsi hemat untuk kategori makanan. Bawa bekal siang dapat menghemat hingga Rp 150.000 pekan ini!',
            style: TextStyle(
              fontSize: 11.5,
              color: Color(0xFFCBD5E1),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterToggleCard() {
    return Container(
      key: const Key('card_master_reminder'),
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _settings.isEnabled
              ? AppTheme.primaryColor.withValues(alpha: 0.4)
              : AppTheme.borderSubtle,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _settings.isEnabled
                  ? AppTheme.primaryColor.withValues(alpha: 0.12)
                  : AppTheme.surfaceColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_active_rounded,
              color: _settings.isEnabled
                  ? AppTheme.primaryColor
                  : AppTheme.textSecondary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aktifkan Pengingat Harian',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _settings.isEnabled
                      ? 'Notifikasi cerdas dan saran harian aktif'
                      : 'Semua notifikasi pengingat harian nonaktif',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            key: const Key('switch_master_reminder'),
            value: _settings.isEnabled,
            activeColor: AppTheme.primaryColor,
            onChanged: (val) {
              setState(() {
                _settings = _settings.copyWith(isEnabled: val);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
          color: AppTheme.textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildScheduleCard({
    required String cardKey,
    required String switchKey,
    required String timeBtnKey,
    required String timeTextKey,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String timeFormatted,
    required bool isEnabled,
    required ValueChanged<bool> onToggleSwitch,
    required VoidCallback? onTapTime,
  }) {
    return Container(
      key: Key(cardKey),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isEnabled
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                key: Key(switchKey),
                value: isEnabled,
                activeColor: AppTheme.primaryColor,
                onChanged: onToggleSwitch,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppTheme.borderSubtle),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Waktu Pengingat',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              InkWell(
                key: Key(timeBtnKey),
                onTap: onTapTime,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? AppTheme.primaryColor.withValues(alpha: 0.08)
                        : AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isEnabled
                          ? AppTheme.primaryColor.withValues(alpha: 0.3)
                          : AppTheme.borderSubtle,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: isEnabled
                            ? AppTheme.primaryColor
                            : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        timeFormatted,
                        key: Key(timeTextKey),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isEnabled
                              ? AppTheme.primaryColor
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveDaysCard(bool isMasterEnabled) {
    final days = [
      {'id': 1, 'label': 'Sen'},
      {'id': 2, 'label': 'Sel'},
      {'id': 3, 'label': 'Rab'},
      {'id': 4, 'label': 'Kam'},
      {'id': 5, 'label': 'Jum'},
      {'id': 6, 'label': 'Sab'},
      {'id': 7, 'label': 'Min'},
    ];

    return Container(
      key: const Key('card_active_days'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Frekuensi Hari',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                _settings.activeDaysSummary,
                key: const Key('text_active_days_summary'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days.map((day) {
              final dayId = day['id'] as int;
              final isSelected = _settings.activeDays.contains(dayId);

              return InkWell(
                key: Key('chip_day_$dayId'),
                onTap: isMasterEnabled ? () => _toggleDay(dayId) : null,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isSelected && isMasterEnabled
                        ? AppTheme.primaryColor
                        : AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected && isMasterEnabled
                          ? AppTheme.primaryColor
                          : AppTheme.borderSubtle,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    day['label'] as String,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected && isMasterEnabled
                          ? Colors.white
                          : AppTheme.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartAlertsCard(bool isMasterEnabled) {
    return Container(
      key: const Key('card_smart_alerts'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        children: [
          _buildAlertSwitchTile(
            switchKey: 'switch_alert_overbudget',
            title: 'Peringatan Batas Belanja Kritis',
            subtitle: 'Notifikasi saat sisa anggaran harian < 20%.',
            icon: Icons.warning_amber_rounded,
            iconColor: Colors.orange,
            value: isMasterEnabled && _settings.notifyOnOverbudget,
            onChanged: (val) {
              if (!isMasterEnabled) return;
              setState(() {
                _settings = _settings.copyWith(notifyOnOverbudget: val);
              });
            },
          ),
          const Divider(height: 1, color: AppTheme.borderSubtle),
          _buildAlertSwitchTile(
            switchKey: 'switch_alert_saving_tips',
            title: 'Tips Hemat Personal AI',
            subtitle: 'Rekomendasi tips hemat berdasarkan pola transaksi.',
            icon: Icons.lightbulb_outline_rounded,
            iconColor: Colors.amber,
            value: isMasterEnabled && _settings.notifySavingTips,
            onChanged: (val) {
              if (!isMasterEnabled) return;
              setState(() {
                _settings = _settings.copyWith(notifySavingTips: val);
              });
            },
          ),
          const Divider(height: 1, color: AppTheme.borderSubtle),
          _buildAlertSwitchTile(
            switchKey: 'switch_alert_debt_due',
            title: 'Pengingat Jatuh Tempo Hutang',
            subtitle: 'Pemberitahuan H-3 tagihan dan paylater.',
            icon: Icons.calendar_today_rounded,
            iconColor: const Color(0xFF10B981),
            value: isMasterEnabled && _settings.notifyDebtDue,
            onChanged: (val) {
              if (!isMasterEnabled) return;
              setState(() {
                _settings = _settings.copyWith(notifyDebtDue: val);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesCard(bool isMasterEnabled) {
    return Container(
      key: const Key('card_system_preferences'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        children: [
          _buildAlertSwitchTile(
            switchKey: 'switch_sound_enabled',
            title: 'Suara Notifikasi',
            subtitle: 'Bunyikan nada saat pengingat harian tiba.',
            icon: Icons.volume_up_outlined,
            iconColor: AppTheme.primaryColor,
            value: isMasterEnabled && _settings.soundEnabled,
            onChanged: (val) {
              if (!isMasterEnabled) return;
              setState(() {
                _settings = _settings.copyWith(soundEnabled: val);
              });
            },
          ),
          const Divider(height: 1, color: AppTheme.borderSubtle),
          _buildAlertSwitchTile(
            switchKey: 'switch_vibration_enabled',
            title: 'Getar',
            subtitle: 'Aktifkan getaran saat pengingat masuk.',
            icon: Icons.vibration_rounded,
            iconColor: AppTheme.primaryColor,
            value: isMasterEnabled && _settings.vibrationEnabled,
            onChanged: (val) {
              if (!isMasterEnabled) return;
              setState(() {
                _settings = _settings.copyWith(vibrationEnabled: val);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAlertSwitchTile({
    required String switchKey,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            key: Key(switchKey),
            value: value,
            activeColor: AppTheme.primaryColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
