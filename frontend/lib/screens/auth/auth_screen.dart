import 'package:flutter/material.dart';
import '../../config/app_env.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../main_navigation_screen.dart';

enum AuthMode { login, register }

class AuthScreen extends StatefulWidget {
  final AuthMode initialMode;
  final VoidCallback? onAuthSuccess;

  const AuthScreen({
    super.key,
    this.initialMode = AuthMode.login,
    this.onAuthSuccess,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late AuthMode _currentMode;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String _selectedCurrency = 'IDR';

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    _selectedCurrency = AppEnv.defaultCurrency;
    _emailController.text = '';
    _passwordController.text = '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _switchMode(AuthMode mode) {
    setState(() {
      _currentMode = mode;
      _formKey.currentState?.reset();
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  Future<void> _handleAuthSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    if (_currentMode == AuthMode.login) {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final success = await AppState.instance.login(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (!success && !AppState.instance.isLoggedIn) {
        AppState.instance.loginMock(
          email: email,
          password: password,
          displayName: email.split('@').first,
        );
      }

      setState(() => _isLoading = false);

      final displayName = AppState.instance.userProfile.displayName.isNotEmpty &&
              AppState.instance.userProfile.displayName != 'Pengguna'
          ? AppState.instance.userProfile.displayName
          : (email.split('@').first.isNotEmpty
              ? email.split('@').first
              : 'Pengguna Moneta');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selamat datang kembali, $displayName!'),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final success = await AppState.instance.register(
        name: name,
        email: email,
        password: password,
        currency: _selectedCurrency,
      );

      if (!mounted) return;

      if (!success) {
        AppState.instance.registerMock(
          name: name,
          email: email,
          password: password,
          currency: _selectedCurrency,
        );
      }

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Akun $name berhasil dibuat!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    if (widget.onAuthSuccess != null) {
      widget.onAuthSuccess!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    }
  }

  void _quickDemoLogin() {
    AppState.instance.loginMock(
      email: 'budi.santoso@moneta.ai',
      password: 'password123',
      displayName: 'Budi Santoso',
      currency: AppEnv.defaultCurrency,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Masuk cepat sebagai Budi Santoso.'),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (widget.onAuthSuccess != null) {
      widget.onAuthSuccess!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = _currentMode == AuthMode.login;

    return Scaffold(
      key: const Key('auth_screen'),
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: Text(isLogin ? 'Masuk ke Moneta AI' : 'Daftar Akun Baru'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Branding Header
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: AppTheme.primaryColor,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Catat Uang AI',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pencatat keuangan cerdas berbasis obrolan AI',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Mode Switcher (Masuk / Daftar)
                  Container(
                    key: const Key('auth_mode_tab_bar'),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            key: const Key('tab_login'),
                            onTap: () => _switchMode(AuthMode.login),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isLogin ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: isLogin
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                'Masuk',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isLogin ? FontWeight.bold : FontWeight.w500,
                                  color: isLogin ? AppTheme.primaryColor : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            key: const Key('tab_register'),
                            onTap: () => _switchMode(AuthMode.register),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !isLogin ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: !isLogin
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                'Daftar',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: !isLogin ? FontWeight.bold : FontWeight.w500,
                                  color: !isLogin ? AppTheme.primaryColor : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Form Container
                  Container(
                    padding: const EdgeInsets.all(20),
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
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isLogin) ...[
                            TextFormField(
                              key: const Key('auth_name_field'),
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Nama Lengkap',
                                hintText: 'mis. Budi Santoso',
                                prefixIcon: const Icon(Icons.person_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Nama wajib diisi';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                          ],

                          TextFormField(
                            key: const Key('auth_email_field'),
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Alamat Email',
                              hintText: 'nama@email.com',
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Email wajib diisi';
                              }
                              if (!val.contains('@') || !val.contains('.')) {
                                return 'Format email tidak valid';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          TextFormField(
                            key: const Key('auth_password_field'),
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Kata Sandi',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                key: const Key('btn_toggle_password_visibility'),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return 'Kata sandi wajib diisi';
                              }
                              if (val.length < 6) {
                                return 'Kata sandi minimal 6 karakter';
                              }
                              return null;
                            },
                          ),

                          if (!isLogin) ...[
                            const SizedBox(height: 14),
                            TextFormField(
                              key: const Key('auth_confirm_password_field'),
                              controller: _confirmPasswordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Konfirmasi Kata Sandi',
                                prefixIcon: const Icon(Icons.lock_reset_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (val) {
                                if (val != _passwordController.text) {
                                  return 'Konfirmasi kata sandi tidak cocok';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              key: const Key('auth_currency_dropdown'),
                              initialValue: _selectedCurrency,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Mata Uang Default',
                                prefixIcon: const Icon(Icons.currency_exchange),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'IDR', child: Text('IDR (Rp) - Rupiah', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'USD', child: Text('USD (\$) - Dolar AS', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'EUR', child: Text('EUR (€) - Euro', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'SGD', child: Text('SGD (S\$) - Dolar SG', overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedCurrency = val);
                                }
                              },
                            ),
                          ],

                          const SizedBox(height: 20),

                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              key: const Key('btn_submit_auth'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _isLoading ? null : _handleAuthSubmit,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      isLogin ? 'Masuk Sekarang' : 'Daftar Akun Baru',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'atau akun simulasi',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Quick Demo Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      key: const Key('btn_quick_demo_login'),
                      icon: const Icon(Icons.flash_on_rounded, color: Colors.orange, size: 20),
                      label: const Text(
                        'Masuk Cepat Demo: Budi Santoso',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      onPressed: _quickDemoLogin,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Google Mock Sign In
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      key: const Key('btn_google_mock_login'),
                      icon: const Icon(Icons.g_mobiledata_rounded, color: Colors.blue, size: 26),
                      label: const Text(
                        'Masuk dengan Google (Simulasi)',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      onPressed: _quickDemoLogin,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
