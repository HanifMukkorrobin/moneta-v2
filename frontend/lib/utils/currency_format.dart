/// Utility for robust Indonesian Rupiah (IDR) currency formatting.
///
/// Designed to be pure Dart without requiring external locale data initialization,
/// ensuring 100% reliability in widget tests and mobile environments.
class CurrencyFormat {
  CurrencyFormat._();

  /// Formats a numeric [amount] into standard Indonesian Rupiah format.
  ///
  /// Example:
  /// - `50000` -> `'Rp 50.000'`
  /// - `1250500` -> `'Rp 1.250.500'`
  /// - `-25000` -> `'-Rp 25.000'`
  /// - `10000` with `showSign: true` -> `'+Rp 10.000'`
  /// - `50000` with `withSymbol: false` -> `'50.000'`
  static String formatRupiah(
    num? amount, {
    bool withSymbol = true,
    bool showSign = false,
  }) {
    if (amount == null) return withSymbol ? 'Rp 0' : '0';

    final isNegative = amount < 0;
    final absAmount = amount.abs().round();

    final str = absAmount.toString();
    final buffer = StringBuffer();
    final len = str.length;

    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }

    final formattedNumber = buffer.toString();

    if (withSymbol) {
      if (isNegative) {
        return '-Rp $formattedNumber';
      } else if (showSign && amount > 0) {
        return '+Rp $formattedNumber';
      }
      return 'Rp $formattedNumber';
    }

    final signPrefix = isNegative ? '-' : (showSign && amount > 0 ? '+' : '');
    return '$signPrefix$formattedNumber';
  }

  /// Formats a numeric [amount] into a compact, human-readable Indonesian representation.
  ///
  /// Example:
  /// - `50000` -> `'Rp 50rb'`
  /// - `1500000` -> `'Rp 1.5jt'`
  /// - `2000000000` -> `'Rp 2M'`
  /// - `-120000` -> `'-Rp 120rb'`
  static String formatCompactRupiah(
    num? amount, {
    bool withSymbol = true,
  }) {
    if (amount == null) return withSymbol ? 'Rp 0' : '0';

    final absAmount = amount.abs();
    final isNegative = amount < 0;

    String compactValue;
    if (absAmount >= 1000000000) {
      final val = absAmount / 1000000000;
      final formatted = val % 1 == 0 ? val.toStringAsFixed(0) : val.toStringAsFixed(1);
      compactValue = '${formatted}M';
    } else if (absAmount >= 1000000) {
      final val = absAmount / 1000000;
      final formatted = val % 1 == 0 ? val.toStringAsFixed(0) : val.toStringAsFixed(1);
      compactValue = '${formatted}jt';
    } else if (absAmount >= 1000) {
      final val = absAmount / 1000;
      final formatted = val % 1 == 0 ? val.toStringAsFixed(0) : val.toStringAsFixed(0);
      compactValue = '${formatted}rb';
    } else {
      compactValue = absAmount.round().toString();
    }

    if (withSymbol) {
      return isNegative ? '-Rp $compactValue' : 'Rp $compactValue';
    }
    return isNegative ? '-$compactValue' : compactValue;
  }

  /// Parses text into double amount, stripping 'Rp', spaces, and '.' separators.
  /// Returns `null` if the text cannot be parsed.
  static double? parseRupiah(String? text) {
    if (text == null) return null;
    final clean = text
        .replaceAll('Rp', '')
        .replaceAll('rp', '')
        .replaceAll('RP', '')
        .replaceAll(' ', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();
    if (clean.isEmpty) return null;
    return double.tryParse(clean);
  }
}
