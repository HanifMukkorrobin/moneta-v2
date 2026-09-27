import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../beranda/pengaturan_pengingat_screen.dart';
import '../beranda/riwayat_tips_hemat_screen.dart';
import '../budget/atur_budget_screen.dart';
import '../category_management/manage_categories_screen.dart';
import '../history/transaction_history_screen.dart';
import '../hutang/hutang_screen.dart';

class AkunPengaturanScreen extends StatefulWidget {
  final UserProfile? initialProfile;

  const AkunPengaturanScreen({
    super.key,
    this.initialProfile,
  });

  @override
  State<AkunPengaturanScreen> createState() => _AkunPengaturanScreenState();
}

class _AkunPengaturanScreenState extends State<AkunPengaturanScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.initialProfile != null) {
      AppState.instance.updateUserProfile(widget.initialProfile!);
    }
  }

  void _openEditProfileDialog(UserProfile profile) {
    final nameController = TextEditingController(text: profile.displayName);
    final emailController = TextEditingController(text: profile.email);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Ubah Profil Akun',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('edit_profile_name_field'),
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Nama Lengkap',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Nama tidak boleh kosong';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('edit_profile_email_field'),
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Alamat Email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Email tidak boleh kosong';
                      }
                      if (!val.contains('@')) {
                        return 'Format email tidak valid';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      key: const Key('btn_save_profile_dialog'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        if (formKey.currentState?.validate() ?? false) {
                          final updated = profile.copyWith(
                            displayName: nameController.text.trim(),
                            email: emailController.text.trim(),
                          );
                          AppState.instance.updateUserProfile(updated);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Profil akun berhasil diperbarui.'),
                              backgroundColor: AppTheme.primaryColor,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      child: const Text(
                        'Simpan Perubahan',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openCurrencyPicker(UserProfile profile) {
    final currencies = [
      {'code': 'IDR', 'symbol': 'Rp', 'name': 'Rupiah Indonesia'},
      {'code': 'USD', 'symbol': '\$', 'name': 'Dolar Amerika Serikat'},
      {'code': 'EUR', 'symbol': '€', 'name': 'Euro Uni Eropa'},
      {'code': 'SGD', 'symbol': 'S\$', 'name': 'Dolar Singapura'},
      {'code': 'MYR', 'symbol': 'RM', 'name': 'Ringgit Malaysia'},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
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
                  key: Key('currency_option_${c['code']}'),
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
        );
      },
    );
  }

  void _openAiTonePicker(UserProfile profile) {
    final tones = [
      {'tone': 'Santai', 'desc': 'Bahasa kasual, ramah, dan santai seperti teman ngobrol.'},
      {'tone': 'Standar', 'desc': 'Seimbang, sopan, profesional, dan to-the-point.'},
      {'tone': 'Tegas', 'desc': 'Disiplin finansial ketat, tegas saat mendekati over-budget.'},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
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
                  key: Key('ai_tone_option_${t['tone']}'),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Gaya saran AI diubah ke: ${t['tone']}'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ekspor Data Transaksi'),
        content: const Text(
          'Pilih format file ekspor untuk laporan keuangan dan rekapitulasi data Anda:',
        ),
        actions: [
          TextButton(
            key: const Key('btn_export_csv'),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Laporan CSV berhasil diunduh ke perangkat.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Format CSV'),
          ),
          ElevatedButton(
            key: const Key('btn_export_json'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cadangan JSON berhasil diekspor.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Format JSON'),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Reset Data Lokal?'),
          ],
        ),
        content: const Text(
          'Tindakan ini akan mengembalikan semua data chat, transaksi, budget, hutang, dan profil ke data awal bawaan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            key: const Key('btn_confirm_reset_data'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              AppState.instance.resetToDefault();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Data aplikasi berhasil di-reset ke kondisi awal.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Ya, Reset Data'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final profile = AppState.instance.userProfile;
        final reminder = AppState.instance.reminderSettings;

        return Scaffold(
          key: const Key('akun_pengaturan_screen'),
          backgroundColor: AppTheme.surfaceColor,
          appBar: AppBar(
            title: const Text('Akun & Pengaturan'),
            centerTitle: true,
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // 1. Profil Pengguna Header Card
              Container(
                key: const Key('profile_header_card'),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
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
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                          child: Text(
                            profile.displayName.isNotEmpty
                                ? profile.displayName
                                    .split(' ')
                                    .map((s) => s.isNotEmpty ? s[0] : '')
                                    .take(2)
                                    .join()
                                    .toUpperCase()
                                : 'MO',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.displayName,
                                key: const Key('profile_display_name_text'),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                profile.email,
                                key: const Key('profile_email_text'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                key: const Key('profile_tier_badge'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.stars_rounded,
                                      size: 13,
                                      color: AppTheme.primaryColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      profile.accountTier,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const Key('btn_edit_profile'),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit Profil'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: const BorderSide(color: AppTheme.primaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _openEditProfileDialog(profile),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 2. Section: Preferensi Keuangan
              _buildSectionHeader('Preferensi Keuangan'),
              _buildSettingsCard([
                _buildSettingsTile(
                  key: const Key('setting_currency_tile'),
                  icon: Icons.currency_exchange_rounded,
                  iconColor: Colors.teal,
                  title: 'Mata Uang Utama',
                  subtitle: '${profile.currency} (${profile.currencySymbol})',
                  onTap: () => _openCurrencyPicker(profile),
                ),
                _buildSettingsTile(
                  key: const Key('setting_manage_categories_tile'),
                  icon: Icons.category_outlined,
                  iconColor: Colors.deepOrange,
                  title: 'Kelola Kategori Transaksi',
                  subtitle: 'Tambah & atur kategori pemasukan/pengeluaran',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ManageCategoriesScreen(),
                      ),
                    );
                  },
                ),
                _buildSettingsTile(
                  key: const Key('setting_budget_tile'),
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: Colors.indigo,
                  title: 'Alokasi & Batas Budget Bulanan',
                  subtitle: 'Atur persentase kebutuhan, tabungan, & hiburan',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AturBudgetScreen(),
                      ),
                    );
                  },
                ),
                _buildSettingsTile(
                  key: const Key('setting_debts_tile'),
                  icon: Icons.receipt_long_outlined,
                  iconColor: Colors.purple,
                  title: 'Catatan Hutang & Paylater',
                  subtitle: 'Pantau tagihan cicilan & jatuh tempo',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HutangScreen(),
                      ),
                    );
                  },
                ),
              ]),

              const SizedBox(height: 18),

              // 3. Section: Pengingat & Kecerdasan AI
              _buildSectionHeader('Pengingat & Kecerdasan AI'),
              _buildSettingsCard([
                _buildSettingsTile(
                  key: const Key('setting_reminder_tile'),
                  icon: Icons.alarm_rounded,
                  iconColor: Colors.amber.shade800,
                  title: 'Pengaturan Pengingat Harian',
                  subtitle: reminder.isEnabled
                      ? 'Pagi ${reminder.morningTimeFormatted} • Malam ${reminder.eveningTimeFormatted}'
                      : 'Pengingat harian nonaktif',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: reminder.isEnabled ? Colors.green.shade50 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      reminder.isEnabled ? 'Aktif' : 'Nonaktif',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: reminder.isEnabled ? Colors.green.shade700 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PengaturanPengingatScreen(),
                      ),
                    );
                  },
                ),
                _buildSettingsTile(
                  key: const Key('setting_saving_tips_history_tile'),
                  icon: Icons.lightbulb_outline_rounded,
                  iconColor: Colors.orange,
                  title: 'Riwayat Tips Hemat AI',
                  subtitle: 'Daftar tips dan saran hemat yang telah diberikan',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RiwayatTipsHematScreen(),
                      ),
                    );
                  },
                ),
                _buildSettingsTile(
                  key: const Key('setting_ai_tone_tile'),
                  icon: Icons.auto_awesome_rounded,
                  iconColor: AppTheme.primaryColor,
                  title: 'Gaya Bahasa Saran AI',
                  subtitle: 'Mode saat ini: ${profile.aiAdviceTone}',
                  onTap: () => _openAiTonePicker(profile),
                ),
              ]),

              const SizedBox(height: 18),

              // 4. Section: Keamanan & Privasi
              _buildSectionHeader('Keamanan & Privasi'),
              _buildSettingsCard([
                SwitchListTile(
                  key: const Key('setting_pin_switch'),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_outline, color: Colors.blue, size: 20),
                  ),
                  title: const Text(
                    'Kunci Aplikasi dengan PIN',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    profile.pinEnabled ? 'PIN pengaman aktif' : 'PIN belum diaktifkan',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  value: profile.pinEnabled,
                  onChanged: (val) {
                    AppState.instance.togglePin(val);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          val ? 'Kunci PIN aplikasi diaktifkan.' : 'Kunci PIN dinonaktifkan.',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                SwitchListTile(
                  key: const Key('setting_biometric_switch'),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.fingerprint_rounded, color: Colors.teal, size: 20),
                  ),
                  title: const Text(
                    'Biometrik (Sidik Jari / Wajah)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    profile.biometricEnabled ? 'Biometrik aktif' : 'Gunakan sensor perangkat',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  value: profile.biometricEnabled,
                  onChanged: (val) {
                    AppState.instance.toggleBiometric(val);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          val ? 'Biometrik diaktifkan.' : 'Biometrik dinonaktifkan.',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ]),

              const SizedBox(height: 18),

              // 5. Section: Data & Cadangan
              _buildSectionHeader('Data & Laporan'),
              _buildSettingsCard([
                _buildSettingsTile(
                  key: const Key('setting_transaction_history_tile'),
                  icon: Icons.history_rounded,
                  iconColor: Colors.blueGrey,
                  title: 'Riwayat Transaksi Lengkap',
                  subtitle: 'Pencarian & filter semua catatan keuangan',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TransactionHistoryScreen(),
                      ),
                    );
                  },
                ),
                _buildSettingsTile(
                  key: const Key('setting_export_data_tile'),
                  icon: Icons.file_download_outlined,
                  iconColor: Colors.green,
                  title: 'Ekspor Data Keuangan',
                  subtitle: 'Unduh laporan dalam format CSV atau JSON',
                  onTap: _showExportDialog,
                ),
                _buildSettingsTile(
                  key: const Key('setting_reset_data_tile'),
                  icon: Icons.restart_alt_rounded,
                  iconColor: Colors.red,
                  title: 'Reset Data Simulasi',
                  subtitle: 'Kembalikan data ke kondisi awal bawaan',
                  textColor: Colors.red.shade700,
                  onTap: _showResetConfirmationDialog,
                ),
              ]),

              const SizedBox(height: 18),

              // 6. Section: Tentang Aplikasi
              _buildSectionHeader('Tentang Moneta AI'),
              _buildSettingsCard([
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 20),
                  ),
                  title: const Text(
                    'Versi Aplikasi',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Moneta AI v2.0.0 (Build 12)'),
                  trailing: const Text(
                    'Terbaru',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.cloud_done_outlined, color: Colors.purple, size: 20),
                  ),
                  title: const Text(
                    'Infrastruktur AI & Database',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Proxy 9Router • SQLite Engine • VPS'),
                ),
              ]),

              const SizedBox(height: 24),

              // Tombol Keluar Akun
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: OutlinedButton.icon(
                  key: const Key('btn_logout_tile'),
                  icon: const Icon(Icons.logout_rounded, color: Colors.red),
                  label: const Text(
                    'Keluar Akun',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sesi pengguna saat ini tetap aktif.'),
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
          letterSpacing: 0.3,
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
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingsTile({
    Key? key,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    Color? textColor,
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
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textColor ?? AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
      ),
      trailing: trailing ??
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppTheme.textSecondary,
          ),
      onTap: onTap,
    );
  }
}
