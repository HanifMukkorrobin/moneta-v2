import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';

class PreferensiAplikasiScreen extends StatelessWidget {
  const PreferensiAplikasiScreen({super.key});

  void _openCurrencyPicker(BuildContext context, UserProfile profile) {
    final currencies = [
      {'code': 'IDR', 'symbol': 'Rp', 'name': 'Rupiah Indonesia'},
      {'code': 'USD', 'symbol': '\$', 'name': 'Dolar Amerika Serikat'},
      {'code': 'EUR', 'symbol': '€', 'name': 'Euro Uni Eropa'},
      {'code': 'SGD', 'symbol': 'S\$', 'name': 'Dolar Singapura'},
      {'code': 'MYR', 'symbol': 'RM', 'name': 'Ringgit Malaysia'},
      {'code': 'GBP', 'symbol': '£', 'name': 'Pound Britania'},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Pilih Mata Uang Utama',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const Divider(),
            ...currencies.map((c) {
              final isSelected = profile.currency == c['code'];
              return ListTile(
                key: Key('pref_currency_option_${c['code']}'),
                leading: CircleAvatar(
                  backgroundColor: isSelected
                      ? AppTheme.primaryColor.withValues(alpha: 0.15)
                      : Colors.grey.shade100,
                  child: Text(
                    c['symbol']!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                    ),
                  ),
                ),
                title: Text(
                  '${c['code']} - ${c['name']}',
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: AppTheme.primaryColor)
                    : null,
                onTap: () {
                  AppState.instance.updateCurrency(c['code']!, c['symbol']);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Mata uang diubah ke ${c['code']} (${c['symbol']})'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _openDateFormatPicker(BuildContext context, UserProfile profile) {
    final formats = [
      'DD/MM/YYYY',
      'YYYY-MM-DD',
      'DD MMMM YYYY',
      'MM/DD/YYYY',
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Pilih Format Tanggal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const Divider(),
            ...formats.map((f) {
              final isSelected = profile.dateFormat == f;
              return ListTile(
                key: Key('pref_date_format_option_$f'),
                title: Text(
                  f,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: AppTheme.primaryColor)
                    : null,
                onTap: () {
                  AppState.instance.updateUserProfile(profile.copyWith(dateFormat: f));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Format tanggal diubah ke $f'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _openFirstDayPicker(BuildContext context, UserProfile profile) {
    final days = ['Senin', 'Minggu', 'Sabtu'];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Hari Pertama dalam Seminggu',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const Divider(),
            ...days.map((d) {
              final isSelected = profile.firstDayOfWeek == d;
              return ListTile(
                key: Key('pref_first_day_option_$d'),
                title: Text(
                  d,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: AppTheme.primaryColor)
                    : null,
                onTap: () {
                  AppState.instance.updateUserProfile(profile.copyWith(firstDayOfWeek: d));
                  Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _openThemePicker(BuildContext context, UserProfile profile) {
    final themes = [
      {'name': 'Terang', 'desc': 'Tampilan bersih dan cerah (Default)'},
      {'name': 'Gelap', 'desc': 'Hemat daya dan nyaman di mata malam hari'},
      {'name': 'Ikuti Sistem', 'desc': 'Menyesuaikan tema otomatis perangkat'},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Tema Tampilan Aplikasi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const Divider(),
            ...themes.map((t) {
              final isSelected = profile.themeMode == t['name'];
              return ListTile(
                key: Key('pref_theme_option_${t['name']}'),
                title: Text(
                  t['name']!,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                  ),
                ),
                subtitle: Text(t['desc']!),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: AppTheme.primaryColor)
                    : null,
                onTap: () {
                  AppState.instance.updateUserProfile(profile.copyWith(themeMode: t['name']));
                  Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _openAiTonePicker(BuildContext context, UserProfile profile) {
    final tones = [
      {'tone': 'Santai', 'desc': 'Bahasa kasual, ramah, dan santai seperti teman ngobrol.'},
      {'tone': 'Standar', 'desc': 'Seimbang, sopan, profesional, dan to-the-point.'},
      {'tone': 'Tegas', 'desc': 'Disiplin finansial ketat, tegas saat mendekati batas over-budget.'},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Gaya Bahasa Saran Finansial AI',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const Divider(),
            ...tones.map((t) {
              final isSelected = profile.aiAdviceTone == t['tone'];
              return ListTile(
                key: Key('pref_ai_tone_option_${t['tone']}'),
                title: Text(
                  t['tone']!,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                  ),
                ),
                subtitle: Text(t['desc']!),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: AppTheme.primaryColor)
                    : null,
                onTap: () {
                  AppState.instance.updateAiTone(t['tone']!);
                  Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _openThresholdPicker(BuildContext context, UserProfile profile) {
    final thresholds = [70, 80, 85, 90, 95];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Ambang Peringatan Pengeluaran Bulanan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const Divider(),
            ...thresholds.map((th) {
              final isSelected = profile.budgetAlertThreshold == th;
              return ListTile(
                key: Key('pref_threshold_option_$th'),
                title: Text(
                  '$th% dari Batas Total Budget',
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                  ),
                ),
                subtitle: Text('Beri peringatan saat belanja telah mencapai $th%'),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: AppTheme.primaryColor)
                    : null,
                onTap: () {
                  AppState.instance.updateUserProfile(
                    profile.copyWith(budgetAlertThreshold: th),
                  );
                  Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final profile = AppState.instance.userProfile;

        return Scaffold(
          key: const Key('preferensi_aplikasi_screen'),
          backgroundColor: AppTheme.surfaceColor,
          appBar: AppBar(
            title: const Text('Preferensi Aplikasi'),
            centerTitle: true,
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Section 1: Tampilan & Format Regional
              _buildSectionHeader('Tampilan & Format Regional'),
              _buildSettingsCard([
                _buildTile(
                  key: const Key('pref_currency_tile'),
                  icon: Icons.currency_exchange,
                  iconColor: Colors.teal,
                  title: 'Mata Uang Utama',
                  subtitle: '${profile.currency} (${profile.currencySymbol})',
                  onTap: () => _openCurrencyPicker(context, profile),
                ),
                _buildTile(
                  key: const Key('pref_date_format_tile'),
                  icon: Icons.calendar_today_outlined,
                  iconColor: Colors.blue,
                  title: 'Format Tanggal',
                  subtitle: profile.dateFormat,
                  onTap: () => _openDateFormatPicker(context, profile),
                ),
                _buildTile(
                  key: const Key('pref_first_day_tile'),
                  icon: Icons.view_week_outlined,
                  iconColor: Colors.deepPurple,
                  title: 'Hari Pertama Pekan',
                  subtitle: profile.firstDayOfWeek,
                  onTap: () => _openFirstDayPicker(context, profile),
                ),
                _buildTile(
                  key: const Key('pref_theme_tile'),
                  icon: Icons.palette_outlined,
                  iconColor: Colors.indigo,
                  title: 'Tema Aplikasi',
                  subtitle: profile.themeMode,
                  onTap: () => _openThemePicker(context, profile),
                ),
              ]),

              const SizedBox(height: 18),

              // Section 2: Kecerdasan Finansial AI
              _buildSectionHeader('Kecerdasan Finansial AI'),
              _buildSettingsCard([
                _buildTile(
                  key: const Key('pref_ai_tone_tile'),
                  icon: Icons.auto_awesome,
                  iconColor: AppTheme.primaryColor,
                  title: 'Gaya Bahasa Asisten AI',
                  subtitle: profile.aiAdviceTone,
                  onTap: () => _openAiTonePicker(context, profile),
                ),
                SwitchListTile(
                  key: const Key('pref_auto_confirm_switch'),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.flash_auto_rounded, color: Colors.green, size: 20),
                  ),
                  title: const Text(
                    'Auto-Konfirmasi Catatan Chat',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Otomatis simpan transaksi tanpa menunggu kartu review',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  value: profile.autoConfirmChat,
                  onChanged: (val) {
                    AppState.instance.updateUserProfile(
                      profile.copyWith(autoConfirmChat: val),
                    );
                  },
                ),
                _buildTile(
                  key: const Key('pref_budget_alert_threshold_tile'),
                  icon: Icons.warning_amber_rounded,
                  iconColor: Colors.orange,
                  title: 'Peringatan Batas Budget',
                  subtitle: 'Peringatkan di ${profile.budgetAlertThreshold}% dari batas budget',
                  onTap: () => _openThresholdPicker(context, profile),
                ),
              ]),

              const SizedBox(height: 18),

              // Section 3: Privasi & Respons Layar
              _buildSectionHeader('Privasi & Sensor Layar'),
              _buildSettingsCard([
                SwitchListTile(
                  key: const Key('pref_hide_balance_switch'),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.visibility_off_outlined, color: Colors.blueGrey, size: 20),
                  ),
                  title: const Text(
                    'Sembunyikan Nominal Saldo',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Sensor angka saldo di ringkasan demi privasi di tempat umum',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  value: profile.hideBalance,
                  onChanged: (val) {
                    AppState.instance.updateUserProfile(
                      profile.copyWith(hideBalance: val),
                    );
                  },
                ),
                SwitchListTile(
                  key: const Key('pref_haptic_feedback_switch'),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade800.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.vibration_rounded, color: Colors.amber.shade800, size: 20),
                  ),
                  title: const Text(
                    'Umpan Balik Getar (Haptic)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Getaran halus saat mengirim pesan chat atau tombol ditekan',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  value: profile.hapticFeedback,
                  onChanged: (val) {
                    AppState.instance.updateUserProfile(
                      profile.copyWith(hapticFeedback: val),
                    );
                  },
                ),
              ]),

              const SizedBox(height: 24),

              // Reset to defaults
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('btn_reset_preferences'),
                  icon: const Icon(Icons.restore_rounded),
                  label: const Text('Pulihkan Preferensi Bawaan'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    AppState.instance.updateUserProfile(
                      profile.copyWith(
                        currency: 'IDR',
                        currencySymbol: 'Rp',
                        aiAdviceTone: 'Standar',
                        dateFormat: 'DD/MM/YYYY',
                        firstDayOfWeek: 'Senin',
                        themeMode: 'Terang',
                        hideBalance: false,
                        autoConfirmChat: false,
                        hapticFeedback: true,
                        budgetAlertThreshold: 80,
                      ),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Preferensi aplikasi dikembalikan ke pengaturan default.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTile({
    Key? key,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      key: key,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: AppTheme.textSecondary,
      ),
      onTap: onTap,
    );
  }
}
