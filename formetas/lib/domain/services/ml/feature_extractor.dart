import '../../entities/transaction_entity.dart';
import '../description_normalizer.dart';
import 'classifier_thresholds.dart';

/// Features esparsas e determinísticas de um lançamento ou linha de extrato.
///
/// A descrição passa pelo [DescriptionNormalizer], então data, NSU, CPF e
/// final de cartão não viram token. A ordem da lista é alfabética para o
/// mesmo texto produzir sempre o mesmo vetor.
abstract final class FeatureExtractor {
  static const _weekdays = [
    'd:seg',
    'd:ter',
    'd:qua',
    'd:qui',
    'd:sex',
    'd:sab',
    'd:dom',
  ];

  static List<String> extract({
    required String description,
    required double amount,
    required TransactionType type,
    required DateTime date,
    PaymentMethod? paymentMethod,
  }) {
    final tokens = DescriptionNormalizer.tokens(description);
    final features = <String>{};

    for (final token in tokens) {
      features.add('w:$token');
    }
    for (var i = 0; i < tokens.length - 1; i++) {
      features.add('b:${tokens[i]}_${tokens[i + 1]}');
    }

    if (type == TransactionType.income) features.add('t:receita');
    if (type == TransactionType.expense) features.add('t:despesa');
    if (tokens.contains(DescriptionNormalizer.pixOut)) {
      features.add('t:pix_enviado');
    }
    if (tokens.contains(DescriptionNormalizer.pixIn)) {
      features.add('t:pix_recebido');
    }

    features.add(_amountBucket(amount));
    features.add(_weekdays[date.weekday - 1]);
    features.add(_monthPeriod(date.day));

    final payment = _payment(paymentMethod, description, tokens);
    if (payment != null) features.add(payment);

    final sorted = features.toList()..sort();
    return List.unmodifiable(sorted);
  }

  /// Peso usado na hora de pontuar. Valor e dia pesam menos que o texto.
  static double weightOf(String feature) {
    if (feature.startsWith('b:')) return ClassifierThresholds.bigramWeight;
    if (feature.startsWith('w:')) return ClassifierThresholds.tokenWeight;
    if (feature.startsWith('t:')) return ClassifierThresholds.typeWeight;
    if (feature.startsWith('p:')) return ClassifierThresholds.paymentWeight;
    if (feature.startsWith('v:')) return ClassifierThresholds.amountWeight;
    if (feature.startsWith('d:')) return ClassifierThresholds.dayWeight;
    return 1;
  }

  /// Texto curto para mostrar no "por que essa categoria?".
  static String describe(String feature) {
    final split = feature.indexOf(':');
    if (split <= 0 || split == feature.length - 1) return feature;
    final body = feature.substring(split + 1).replaceAll('_', ' ');
    if (feature.startsWith('v:')) return 'valor $body';
    return body;
  }

  static String _amountBucket(double amount) {
    final value = amount.abs();
    if (value < 10) return 'v:0-10';
    if (value < 30) return 'v:10-30';
    if (value < 100) return 'v:30-100';
    if (value < 300) return 'v:100-300';
    if (value < 1000) return 'v:300-1000';
    return 'v:1000+';
  }

  /// Dia 1–10, 11–20 e 21–31.
  static String _monthPeriod(int day) {
    if (day <= 10) return 'd:inicio';
    if (day <= 20) return 'd:meio';
    return 'd:fim';
  }

  static String? _payment(
    PaymentMethod? method,
    String description,
    List<String> tokens,
  ) {
    if (method != null) {
      return switch (method) {
        PaymentMethod.cash => 'p:dinheiro',
        PaymentMethod.debit => 'p:debito',
        PaymentMethod.credit => 'p:credito',
        PaymentMethod.pix => 'p:pix',
        PaymentMethod.transfer => 'p:transferencia',
        PaymentMethod.other => 'p:outro',
      };
    }
    if (tokens.contains(DescriptionNormalizer.pixOut) ||
        tokens.contains(DescriptionNormalizer.pixIn)) {
      return 'p:pix';
    }
    final text = DescriptionNormalizer.stripAccents(description.toLowerCase());
    if (text.contains('debito')) return 'p:debito';
    if (text.contains('credito')) return 'p:credito';
    if (text.contains('transferencia')) return 'p:transferencia';
    if (text.contains('pix')) return 'p:pix';
    return null;
  }
}
