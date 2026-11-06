import 'package:flutter_test/flutter_test.dart';
import 'package:formetas/domain/entities/recurring_pattern.dart';
import 'package:formetas/domain/entities/transaction_entity.dart';
import 'package:formetas/domain/services/recurrence_detector.dart';

var _seq = 0;

TransactionEntity _tx(
  String description,
  double value,
  DateTime date, {
  TransactionType type = TransactionType.expense,
  String category = 'Outros',
}) {
  _seq++;
  return TransactionEntity(
    id: 't$_seq',
    userId: 'u',
    type: type,
    category: category,
    value: value,
    description: description,
    date: date,
    createdAt: date,
  );
}

void main() {
  const detector = RecurrenceDetector();
  final now = DateTime(2026, 6, 10);

  test('salário mensal no 5º dia útil com valor estável', () {
    final txs = [
      _tx('Transferência recebida pelo Pix - ACME LTDA - 12.345.678/0001-90', 5200,
          DateTime(2026, 2, 6), type: TransactionType.income, category: 'Salário'),
      _tx('Transferência recebida pelo Pix - ACME LTDA - 12.345.678/0001-90', 5200,
          DateTime(2026, 3, 6), type: TransactionType.income, category: 'Salário'),
      _tx('Transferência recebida pelo Pix - ACME LTDA - 12.345.678/0001-90', 5350,
          DateTime(2026, 4, 7), type: TransactionType.income, category: 'Salário'),
      _tx('Transferência recebida pelo Pix - ACME LTDA - 12.345.678/0001-90', 5200,
          DateTime(2026, 5, 7), type: TransactionType.income, category: 'Salário'),
    ];
    final patterns = detector.detect(txs, referenceDate: now);
    expect(patterns, hasLength(1));
    final salary = patterns.single;
    expect(salary.kind, RecurringKind.salary);
    expect(salary.cadence, RecurrenceCadence.monthly);
    expect(salary.category, 'Salário');
    expect(salary.occurrences, 4);
    expect(salary.averageAmount, closeTo(5237.5, 0.01));
    expect(salary.expectedNextDate.month, 6);
    expect(salary.confidence, greaterThan(0.7));
  });

  test('assinatura com ruído diferente a cada mês', () {
    final txs = [
      _tx('NETFLIX.COM 05/02 SAO PAULO BR', 44.90, DateTime(2026, 2, 5)),
      _tx('Netflix.com 05/03 Sao Paulo BR', 44.90, DateTime(2026, 3, 5)),
      _tx('NETFLIX.COM 06/04 SAO PAULO BR', 44.90, DateTime(2026, 4, 6)),
      _tx('NETFLIX.COM 05/05 SAO PAULO BR', 44.90, DateTime(2026, 5, 5)),
    ];
    final pattern = detector.detect(txs, referenceDate: now).single;
    expect(pattern.kind, RecurringKind.subscription);
    expect(pattern.amountVariance, 0);
    expect(pattern.expectedNextDate, DateTime(2026, 6, 5));
  });

  test('conta fixa com valor variável dentro da tolerância', () {
    final txs = [
      _tx('Pagamento de boleto efetuado - ENEL CE', 182.40, DateTime(2026, 2, 10)),
      _tx('Pagamento de boleto efetuado - ENEL CE', 201.15, DateTime(2026, 3, 10)),
      _tx('Pagamento de boleto efetuado - ENEL CE', 175.80, DateTime(2026, 4, 9)),
      _tx('Pagamento de boleto efetuado - ENEL CE', 195.00, DateTime(2026, 5, 11)),
    ];
    final pattern = detector.detect(txs, referenceDate: now).single;
    expect(pattern.kind, RecurringKind.bill);
    expect(pattern.cadence, RecurrenceCadence.monthly);
    expect(pattern.amountVariance, greaterThan(0));
  });

  test('gasto semanal exige pelo menos 3 ocorrências', () {
    final two = [
      _tx('Compra no débito - FEIRA DO BAIRRO', 60, DateTime(2026, 6, 1)),
      _tx('Compra no débito - FEIRA DO BAIRRO', 62, DateTime(2026, 6, 8)),
    ];
    expect(detector.detect(two, referenceDate: now), isEmpty);

    final four = [
      ...two,
      _tx('Compra no débito - FEIRA DO BAIRRO', 58, DateTime(2026, 5, 25)),
      _tx('Compra no débito - FEIRA DO BAIRRO', 61, DateTime(2026, 5, 18)),
    ];
    final pattern = detector.detect(four, referenceDate: now).single;
    expect(pattern.cadence, RecurrenceCadence.weekly);
    expect(pattern.expectedNextDate, DateTime(2026, 6, 15));
  });

  test('gastos irregulares não viram padrão', () {
    final txs = [
      _tx('Uber Trip', 23, DateTime(2026, 3, 1)),
      _tx('Uber Trip', 41, DateTime(2026, 3, 3)),
      _tx('Uber Trip', 12, DateTime(2026, 3, 19)),
      _tx('Uber Trip', 80, DateTime(2026, 4, 30)),
    ];
    expect(detector.detect(txs, referenceDate: now), isEmpty);
  });

  test('padrão antigo é descartado, a menos que pedido', () {
    final txs = [
      _tx('SPOTIFY', 21.90, DateTime(2025, 1, 10)),
      _tx('SPOTIFY', 21.90, DateTime(2025, 2, 10)),
      _tx('SPOTIFY', 21.90, DateTime(2025, 3, 10)),
    ];
    expect(detector.detect(txs, referenceDate: now), isEmpty);
    expect(
      detector.detect(txs, referenceDate: now, includeInactive: true),
      hasLength(1),
    );
  });

  test('Pix para a mesma pessoa em sentidos opostos fica separado', () {
    final txs = [
      for (final month in [3, 4, 5]) ...[
        _tx('Pix enviado - MARIA SOUZA', 800, DateTime(2026, month, 1)),
        _tx('Pix recebido - MARIA SOUZA', 300, DateTime(2026, month, 15),
            type: TransactionType.income),
      ],
    ];
    final patterns = detector.detect(txs, referenceDate: now);
    expect(patterns, hasLength(2));
    expect(patterns.map((p) => p.type).toSet(),
        {TransactionType.expense, TransactionType.income});
  });

  test('ignora saldo inicial e investimentos', () {
    final txs = [
      for (final month in [2, 3, 4, 5])
        _tx('Aporte mensal', 500, DateTime(2026, month, 1),
            type: TransactionType.investment),
    ];
    expect(detector.detect(txs, referenceDate: now), isEmpty);
  });
}
