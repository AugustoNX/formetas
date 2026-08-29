import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

/// Formatações da carteira: quantidades fracionadas, percentuais e preços de
/// ativo, que precisam de mais casas do que um valor em reais comum.
abstract final class NumberFormatter {
  static final _integer = NumberFormat('#,##0', AppConstants.locale);
  static final _fractional = NumberFormat('#,##0.########', AppConstants.locale);
  static final _price = NumberFormat('#,##0.00', AppConstants.locale);
  static final _smallPrice = NumberFormat('#,##0.00######', AppConstants.locale);

  static String quantity(double value) {
    if (value == value.roundToDouble()) return _integer.format(value);
    return _fractional.format(value);
  }

  /// Preço unitário. Centavos bastam para uma ação; cripto precisa de mais.
  static String price(double value) {
    final formatted =
        value != 0 && value.abs() < 1 ? _smallPrice.format(value) : _price.format(value);
    return 'R\$ $formatted';
  }

  /// Recebe a fração (0,0677) e devolve o percentual (6,77%).
  static String percent(double fraction, {int decimals = 2}) {
    final value = (fraction * 100).toStringAsFixed(decimals).replaceAll('.', ',');
    return '$value%';
  }

  /// Igual a [percent], mas deixa explícito quando o número é positivo.
  static String signedPercent(double fraction, {int decimals = 2}) {
    final prefix = fraction > 0 ? '+' : '';
    return '$prefix${percent(fraction, decimals: decimals)}';
  }

  static String signedCurrency(double value, String Function(double) format) {
    final prefix = value > 0 ? '+' : '';
    return '$prefix${format(value)}';
  }
}
