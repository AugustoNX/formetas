import 'package:equatable/equatable.dart';

import 'transaction_entity.dart';

/// O que um item recorrente representa no mês da pessoa.
enum RecurringKind { salary, income, bill, subscription }

/// Ritmo em que o item se repete.
enum RecurrenceCadence { weekly, monthly, yearly }

/// Um movimento que se repete, descoberto a partir do histórico.
///
/// É só leitura: nada aqui é gravado. Serve para prever o próximo salário,
/// as contas fixas e as assinaturas.
class RecurringPattern extends Equatable {
  const RecurringPattern({
    required this.key,
    required this.label,
    required this.kind,
    required this.type,
    required this.cadence,
    required this.averageAmount,
    required this.amountVariance,
    required this.lastDate,
    required this.expectedNextDate,
    required this.confidence,
    required this.transactionIds,
    required this.category,
  });

  /// Chave normalizada do grupo (ver DescriptionNormalizer).
  final String key;

  /// Descrição mais recente, para exibir.
  final String label;
  final RecurringKind kind;
  final TransactionType type;
  final RecurrenceCadence cadence;
  final double averageAmount;

  /// Coeficiente de variação do valor (desvio padrão / média). 0 = fixo.
  final double amountVariance;
  final DateTime lastDate;
  final DateTime expectedNextDate;

  /// 0 a 1: quantidade de ocorrências, regularidade e estabilidade do valor.
  final double confidence;
  final List<String> transactionIds;

  /// Categoria mais comum entre as ocorrências (o app guarda o nome).
  final String category;

  int get occurrences => transactionIds.length;

  @override
  List<Object?> get props => [
        key,
        kind,
        type,
        cadence,
        averageAmount,
        expectedNextDate,
        transactionIds,
      ];
}

abstract final class RecurringKindLabels {
  static String label(RecurringKind kind) => switch (kind) {
        RecurringKind.salary => 'Salário',
        RecurringKind.income => 'Receita recorrente',
        RecurringKind.bill => 'Conta fixa',
        RecurringKind.subscription => 'Assinatura',
      };
}
