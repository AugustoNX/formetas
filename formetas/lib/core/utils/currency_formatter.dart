import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

abstract final class CurrencyFormatter {
  static final _formatter = NumberFormat.currency(
    locale: AppConstants.locale,
    symbol: 'R\$',
    decimalDigits: 2,
  );

  static final _inputFormatter = NumberFormat.currency(
    locale: AppConstants.locale,
    symbol: '',
    decimalDigits: 2,
  );

  static String format(double value) => _formatter.format(value);

  static String formatForInput(double value) =>
      _inputFormatter.format(value).trim();

  static double? parse(String value) {
    final cleaned = value
        .replaceAll('R\$', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  /// Compara valores monetários em centavos para evitar erros de ponto flutuante.
  static bool exceeds(double amount, double limit) =>
      (amount * 100).round() > (limit * 100).round();

  static List<TextInputFormatter> get inputFormatters =>
      const [CurrencyInputFormatter()];
}

class CurrencyInputFormatter extends TextInputFormatter {
  const CurrencyInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final value = int.parse(digits) / 100;
    final formatted = CurrencyFormatter.formatForInput(value);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
