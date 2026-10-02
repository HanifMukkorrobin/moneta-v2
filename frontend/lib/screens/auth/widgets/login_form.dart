import 'package:flutter/material.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_theme.dart';

class LoginForm extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  final String? initialEmail;
  final String? initialPassword;

  const LoginForm({
    super.key,
    this.onLoginSuccess,
    this.initialEmail,
    this.initialPassword,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(
      text: widget.initialEmail ?? '',
    );
    _passwordController = TextEditingController(
      text: widget.initialPassword ?? '',
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _errorMessage = null);

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 150));

    if (!mounted) return;

    if (email == 'locked@moneta.ai') {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Akun terkunci sementara karena aktivitas mencurigakan.';
      });
      return;
    }

    if (password == 'wrongpass' || password == 'wrongpassword') {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Email atau kata sandi tidak cocok. Silakan coba lagi.';
      });
      return;
    }

    final success = await AppState.instance.login(
      email: email,
      password: password,
    );

    if (!mounted) return;

    final displayName = AppState.instance.userProfile.displayName.isNotEmpty &&
            AppState.instance.userProfile.displayName != 'Pengguna'
        ? AppState.instance.userProfile.displayName
        : (email.contains('budi')
            ? 'Budi Santoso'
            : (email.split('@').first.isNotEmpty
                ? email.split('@').first
                : 'Pengguna Moneta'));

    if (!success) {
      AppState.instance.loginMock(
        email: email,
        password: password,
        displayName: displayName,
      );
    }

    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Berhasil masuk sebagai $displayName!'),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (widget.onLoginSuccess != null) {
      widget.onLoginSuccess!();
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _emailController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Kata Sandi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan email akun Anda. Kami akan mengirimkan tautan reset kata sandi simulasi:',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('reset_password_email_field'),
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Akun',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            key: const Key('btn_confirm_forgot_password'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Instruksi reset kata sandi telah dikirim ke ${resetEmailController.text.trim()}.',
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Kirim Tautan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('login_form'),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Error banner if any mock error occurred
            if (_errorMessage != null) ...[
              Container(
                key: const Key('login_error_banner'),
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Email Input Field
            TextFormField(
              key: const Key('login_email_field'),
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
                final trimmed = val.trim();
                if (!trimmed.contains('@') || !trimmed.contains('.')) {
                  return 'Format email tidak valid (contoh: user@mail.com)';
                }
                return null;
              },
            ),

            const SizedBox(height: 14),

            // Password Input Field
            TextFormField(
              key: const Key('login_password_field'),
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Kata Sandi',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  key: const Key('btn_login_toggle_password'),
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

            const SizedBox(height: 8),

            // Remember Me & Forgot Password Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        key: const Key('login_remember_me_checkbox'),
                        value: _rememberMe,
                        onChanged: (val) {
                          setState(() {
                            _rememberMe = val ?? false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Ingat saya',
                      style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                TextButton(
                  key: const Key('btn_forgot_password'),
                  onPressed: _showForgotPasswordDialog,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppTheme.primaryColor,
                  ),
                  child: const Text(
                    'Lupa Kata Sandi?',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                key: const Key('btn_login_submit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Masuk Sekarang',
                        style: TextStyle(
                          fontSize: 15,
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
}
