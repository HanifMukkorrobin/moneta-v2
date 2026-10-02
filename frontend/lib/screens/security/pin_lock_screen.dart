import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';

enum PinLockMode {
  unlock,
  setup,
  change,
}

class PinLockScreen extends StatefulWidget {
  final PinLockMode mode;
  final VoidCallback? onUnlockSuccess;
  final ValueChanged<String>? onPinSet;
  final bool canCancel;
  final String? initialExpectedPin;

  const PinLockScreen({
    super.key,
    this.mode = PinLockMode.unlock,
    this.onUnlockSuccess,
    this.onPinSet,
    this.canCancel = true,
    this.initialExpectedPin,
  });

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  static const int _pinLength = 4;

  String _enteredPin = '';
  String? _firstPin; // Digunakan saat setup/change untuk konfirmasi
  String? _errorMessage;
  int _attemptsCount = 0;

  // Step saat mode change: 0 = verify old, 1 = enter new, 2 = confirm new
  // Step saat mode setup: 0 = enter new, 1 = confirm new
  // Step saat mode unlock: 0 = verify pin
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _step = 0;
  }

  void _onDigitPressed(String digit) {
    if (_enteredPin.length >= _pinLength) return;

    setState(() {
      _errorMessage = null;
      _enteredPin += digit;
    });

    if (_enteredPin.length == _pinLength) {
      _processPin();
    }
  }

  void _onBackspacePressed() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _errorMessage = null;
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _processPin() {
    final pin = _enteredPin;

    switch (widget.mode) {
      case PinLockMode.unlock:
        _handleUnlock(pin);
        break;

      case PinLockMode.setup:
        _handleSetup(pin);
        break;

      case PinLockMode.change:
        _handleChange(pin);
        break;
    }
  }

  void _handleUnlock(String pin) {
    final expected = widget.initialExpectedPin ??
        AppState.instance.userProfile.pinCode ??
        '1234';

    if (pin == expected) {
      AppState.instance.verifyPin(pin);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kunci PIN berhasil dibuka!'),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (widget.onUnlockSuccess != null) {
        widget.onUnlockSuccess!();
      } else if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }
    } else {
      _attemptsCount++;
      setState(() {
        _enteredPin = '';
        _errorMessage = 'PIN salah. Silakan coba lagi (Percobaan $_attemptsCount).';
      });
    }
  }

  void _handleSetup(String pin) {
    if (_step == 0) {
      // Selesai input PIN baru pertama kali
      setState(() {
        _firstPin = pin;
        _enteredPin = '';
        _step = 1;
      });
    } else {
      // Konfirmasi PIN
      if (pin == _firstPin) {
        AppState.instance.setPin(pin);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN keamanan berhasil dibuat!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (widget.onPinSet != null) {
          widget.onPinSet!(pin);
        }
        if (Navigator.canPop(context)) {
          Navigator.pop(context, pin);
        }
      } else {
        setState(() {
          _enteredPin = '';
          _errorMessage = 'Konfirmasi PIN tidak cocok. Silakan ulangi.';
          _step = 0;
          _firstPin = null;
        });
      }
    }
  }

  void _handleChange(String pin) {
    final expectedOld = widget.initialExpectedPin ??
        AppState.instance.userProfile.pinCode ??
        '1234';

    if (_step == 0) {
      // Verifikasi PIN Lama
      if (pin == expectedOld) {
        setState(() {
          _enteredPin = '';
          _step = 1;
        });
      } else {
        _attemptsCount++;
        setState(() {
          _enteredPin = '';
          _errorMessage = 'PIN lama salah. Percobaan $_attemptsCount.';
        });
      }
    } else if (_step == 1) {
      // Input PIN Baru
      setState(() {
        _firstPin = pin;
        _enteredPin = '';
        _step = 2;
      });
    } else {
      // Konfirmasi PIN Baru
      if (pin == _firstPin) {
        AppState.instance.setPin(pin);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN keamanan berhasil diubah!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (widget.onPinSet != null) {
          widget.onPinSet!(pin);
        }
        if (Navigator.canPop(context)) {
          Navigator.pop(context, pin);
        }
      } else {
        setState(() {
          _enteredPin = '';
          _errorMessage = 'Konfirmasi PIN baru tidak cocok. Silakan ulangi.';
          _step = 1;
          _firstPin = null;
        });
      }
    }
  }

  void _triggerBiometricScan() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
                    size: 56,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Autentikasi Biometrik',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Gunakan sensor sidik jari atau Face ID untuk membuka aplikasi Moneta AI secara instan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    key: const Key('btn_confirm_biometric_scan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Autentikasi biometrik berhasil diverifikasi!'),
                          backgroundColor: Colors.teal,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      if (widget.onUnlockSuccess != null) {
                        widget.onUnlockSuccess!();
                      } else if (Navigator.canPop(context)) {
                        Navigator.pop(context, true);
                      }
                    },
                    child: const Text(
                      'Pindai Sidik Jari (Simulasi)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String get _title {
    switch (widget.mode) {
      case PinLockMode.unlock:
        return 'Buka Kunci Moneta';
      case PinLockMode.setup:
        return _step == 0 ? 'Buat PIN Baru' : 'Konfirmasi PIN Anda';
      case PinLockMode.change:
        if (_step == 0) return 'Masukkan PIN Lama';
        if (_step == 1) return 'Buat PIN Baru';
        return 'Konfirmasi PIN Baru';
    }
  }

  String get _subtitle {
    switch (widget.mode) {
      case PinLockMode.unlock:
        return 'Masukkan 4 digit PIN pengaman Anda';
      case PinLockMode.setup:
        return _step == 0
            ? 'Masukkan 4 digit nomor yang mudah Anda ingat'
            : 'Ketik ulang 4 digit PIN untuk konfirmasi';
      case PinLockMode.change:
        if (_step == 0) return 'Verifikasi identitas dengan PIN saat ini';
        if (_step == 1) return 'Tentukan 4 digit PIN baru Anda';
        return 'Ketik ulang 4 digit PIN baru untuk memastikan';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('pin_lock_screen'),
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.mode == PinLockMode.unlock ? 'Keamanan Moneta' : 'Pengaturan PIN',
          style: const TextStyle(fontSize: 16),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: widget.canCancel
            ? IconButton(
                key: const Key('btn_pin_back'),
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 1),

            // Security Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_outlined,
                size: 40,
                color: AppTheme.primaryColor,
              ),
            ),

            const SizedBox(height: 18),

            // Title & Subtitle
            Text(
              _title,
              key: const Key('pin_screen_title'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _subtitle,
                key: const Key('pin_screen_subtitle'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // PIN Indicator Dots
            Row(
              key: const Key('pin_indicator_dots'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pinLength, (index) {
                final isFilled = index < _enteredPin.length;
                return Container(
                  key: Key('pin_dot_$index'),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled ? AppTheme.primaryColor : Colors.transparent,
                    border: Border.all(
                      color: isFilled ? AppTheme.primaryColor : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),

            // Error Text
            Container(
              height: 32,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _errorMessage != null
                  ? Text(
                      _errorMessage!,
                      key: const Key('pin_error_text'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            const Spacer(flex: 1),

            // Numeric Keypad Grid
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                children: [
                  _buildKeypadRow(['1', '2', '3']),
                  const SizedBox(height: 16),
                  _buildKeypadRow(['4', '5', '6']),
                  const SizedBox(height: 16),
                  _buildKeypadRow(['7', '8', '9']),
                  const SizedBox(height: 16),
                  _buildBottomRow(),
                ],
              ),
            ),

            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: digits.map((d) => _buildKeypadButton(d)).toList(),
    );
  }

  Widget _buildKeypadButton(String digit) {
    return InkWell(
      key: Key('btn_pin_digit_$digit'),
      onTap: () => _onDigitPressed(digit),
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Text(
          digit,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Biometric Button
        InkWell(
          key: const Key('btn_biometric_auth'),
          onTap: _triggerBiometricScan,
          borderRadius: BorderRadius.circular(36),
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.fingerprint_rounded,
              size: 32,
              color: Colors.teal,
            ),
          ),
        ),

        // Digit 0 Button
        _buildKeypadButton('0'),

        // Backspace Button
        InkWell(
          key: const Key('btn_pin_backspace'),
          onTap: _onBackspacePressed,
          borderRadius: BorderRadius.circular(36),
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.backspace_outlined,
              size: 24,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
