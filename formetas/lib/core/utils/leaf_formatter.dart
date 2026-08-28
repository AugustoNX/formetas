import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

/// Folhinha é a leitura lúdica do dinheiro: R$ 1 equivale a 1 folhinha.
///
/// A formatação existe apenas para exibição — o valor real em reais continua
/// sendo mostrado sempre ao lado.
abstract final class LeafFormatter {
  static final _formatter = NumberFormat.decimalPattern(AppConstants.locale);

  static String count(num value) {
    final leaves = value <= 0 ? 0 : value.round();
    return _formatter.format(leaves);
  }

  static String label(num value) {
    final leaves = value <= 0 ? 0 : value.round();
    return leaves == 1 ? '1 folhinha' : '${count(leaves)} folhinhas';
  }
}
