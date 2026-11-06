import 'package:flutter_test/flutter_test.dart';
import 'package:formetas/domain/entities/goal_entity.dart';
import 'package:formetas/domain/entities/insight.dart';
import 'package:formetas/domain/entities/recurring_pattern.dart';
import 'package:formetas/domain/entities/transaction_entity.dart';
import 'package:formetas/domain/services/insight_engine.dart';

var _seq = 0;

TransactionEntity _tx(
  double value,
  DateTime date, {
  String category = 'Mercado',
  TransactionType type = TransactionType.expense,
  String description = 'compra',
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

RecurringPattern _pattern({
  required String key,
  required RecurringKind kind,
  required TransactionType type,
  required double amount,
  required DateTime next,
  List<String> ids = const [],
}) =>
    RecurringPattern(
      key: key,
      label: key,
      kind: kind,
      type: type,
      cadence: RecurrenceCadence.monthly,
      averageAmount: amount,
      amountVariance: 0,
      lastDate: DateTime(next.year, next.month - 1, next.day),
      expectedNextDate: next,
      confidence: 0.9,
      transactionIds: ids,
      category: 'Outros',
    );

/// Três meses de base: salário 5000, mercado ~600, lazer ~200.
List<TransactionEntity> _baseline(DateTime now) => [
      for (var m = 1; m <= 4; m++) ...[
        _tx(5000, DateTime(now.year, now.month - m, 5),
            type: TransactionType.income, category: 'Salário'),
        _tx(300, DateTime(now.year, now.month - m, 8)),
        _tx(300, DateTime(now.year, now.month - m, 20)),
        _tx(100, DateTime(now.year, now.month - m, 10), category: 'Lazer'),
        _tx(100, DateTime(now.year, now.month - m, 22), category: 'Lazer'),
      ],
    ];

Insight? _find(List<Insight> list, InsightType type) {
  for (final i in list) {
    if (i.type == type) return i;
  }
  return null;
}

void main() {
  const engine = InsightEngine();
  final now = DateTime(2026, 6, 15, 12);

  test('mês estável não gera alertas de categoria', () {
    final txs = [
      ..._baseline(now),
      _tx(5000, DateTime(2026, 6, 5), type: TransactionType.income, category: 'Salário'),
      _tx(300, DateTime(2026, 6, 8)),
    ];
    final out = engine.generate(InsightInput(transactions: txs, now: now));
    expect(out.where((i) => i.type == InsightType.categorySpike), isEmpty);
    expect(out.where((i) => i.severity == InsightSeverity.alert), isEmpty);
    final forecast = _find(out, InsightType.monthForecast)!;
    expect(forecast.severity, InsightSeverity.positive);
  });

  test('pico de categoria aparece com ação de criar trilha', () {
    final txs = [
      ..._baseline(now),
      _tx(5000, DateTime(2026, 6, 5), type: TransactionType.income, category: 'Salário'),
      _tx(500, DateTime(2026, 6, 3)),
      _tx(450, DateTime(2026, 6, 12)),
    ];
    final out = engine.generate(InsightInput(transactions: txs, now: now));
    final spike = _find(out, InsightType.categorySpike)!;
    expect(spike.category, 'Mercado');
    expect(spike.metrics['average'], 600);
    expect(spike.action?.type, InsightActionType.createTrail);
    expect(spike.id, 'categorySpike-2026-06-mercado');
    expect(spike.series.last.highlight, isTrue);
  });

  test('previsão fica vermelha quando ritmo + contas fixas passam a renda', () {
    final rent = _pattern(
      key: 'aluguel', kind: RecurringKind.bill, type: TransactionType.expense,
      amount: 2500, next: DateTime(2026, 6, 25),
    );
    final txs = [
      ..._baseline(now),
      _tx(5000, DateTime(2026, 6, 5), type: TransactionType.income, category: 'Salário'),
      _tx(2000, DateTime(2026, 6, 6), category: 'Viagem'),
      _tx(900, DateTime(2026, 6, 10)),
    ];
    final out = engine.generate(InsightInput(transactions: txs, patterns: [rent], now: now));
    final forecast = _find(out, InsightType.monthForecast)!;
    expect(forecast.severity, InsightSeverity.alert);
    expect(forecast.metrics['pendingBills'], 2500);
    expect(forecast.amount!, lessThan(0));
    expect(out.first.type, InsightType.monthForecast, reason: 'alerta vai para o topo');
  });

  test('salário previsto entra na previsão e gera aviso de chegada', () {
    final salary = _pattern(
      key: 'Salário ACME', kind: RecurringKind.salary, type: TransactionType.income,
      amount: 5000, next: DateTime(2026, 6, 17),
    );
    final txs = [..._baseline(now), _tx(200, DateTime(2026, 6, 8))];
    final out = engine.generate(InsightInput(transactions: txs, patterns: [salary], now: now));
    expect(_find(out, InsightType.monthForecast)!.metrics['pendingIncome'], 5000);
    final arrival = _find(out, InsightType.incomeArrival)!;
    expect(arrival.title, contains('Salário ACME'));
    expect(arrival.title + arrival.message, contains('2 dias'));
  });

  test('compras pequenas somam e viram formiga ao contrário', () {
    final txs = [
      ..._baseline(now),
      for (var d = 1; d <= 10; d++) _tx(18, DateTime(2026, 6, d), category: 'Café'),
    ];
    final out = engine.generate(InsightInput(transactions: txs, now: now));
    final small = _find(out, InsightType.smallPurchases)!;
    expect(small.metrics['count'], 10);
    expect(small.amount, 180);
    expect(small.action?.category, isNull);
  });

  test('gasto incomum isolado é detectado', () {
    final txs = [
      ..._baseline(now),
      _tx(1500, DateTime(2026, 6, 9), category: 'Lazer', description: 'Show'),
    ];
    final out = engine.generate(InsightInput(transactions: txs, now: now));
    final unusual = _find(out, InsightType.unusualExpense)!;
    expect(unusual.message, contains('Show'));
  });

  test('assinaturas somadas', () {
    final subs = [
      _pattern(key: 'Netflix', kind: RecurringKind.subscription, type: TransactionType.expense, amount: 55, next: DateTime(2026, 7, 2)),
      _pattern(key: 'Spotify', kind: RecurringKind.subscription, type: TransactionType.expense, amount: 22, next: DateTime(2026, 7, 4)),
    ];
    final out = engine.generate(InsightInput(transactions: _baseline(now), patterns: subs, now: now));
    final s = _find(out, InsightType.subscriptions)!;
    expect(s.amount, 77);
    expect(s.details, hasLength(2));
  });

  test('taxa de poupança do mês passado', () {
    final out = engine.generate(InsightInput(transactions: _baseline(now), now: now));
    final rate = _find(out, InsightType.savingsRate)!;
    expect(rate.metrics['rate'], closeTo(0.84, 0.001));
    expect(rate.severity, InsightSeverity.positive);
    expect(rate.periodLabel, 'Maio 2026');
    expect(rate.message, contains('maio'));
  });

  test('meta atrasada', () {
    final goal = GoalEntity(
      id: 'g1', userId: 'u', name: 'Carro', targetValue: 100000, currentValue: 1000,
      targetDate: DateTime(2027, 6, 1), createdAt: DateTime(2026, 1, 1),
    );
    final out = engine.generate(InsightInput(transactions: _baseline(now), goals: [goal], now: now));
    final pace = _find(out, InsightType.goalPace)!;
    expect(pace.title + pace.message, contains('Carro'));
  });

  test('dispensados somem, ids são estáveis e há limite de cards', () {
    final txs = [
      ..._baseline(now),
      _tx(500, DateTime(2026, 6, 3)),
      _tx(450, DateTime(2026, 6, 12)),
    ];
    final first = engine.generate(InsightInput(transactions: txs, now: now));
    final again = engine.generate(InsightInput(transactions: txs, now: now));
    expect(again.map((i) => i.id), first.map((i) => i.id));
    expect(again.map((i) => i.title), first.map((i) => i.title));
    final dismissed = engine.generate(InsightInput(
      transactions: txs, now: now, dismissedIds: {'categorySpike-2026-06-mercado'},
    ));
    expect(_find(dismissed, InsightType.categorySpike), isNull);
    expect(first.length, lessThanOrEqualTo(8));
  });

  test('sem dados não gera nada', () {
    expect(engine.generate(InsightInput(transactions: const [], now: now)), isEmpty);
  });

  test('queda não elogia categoria zerada no mês passado', () {
    final txs = [
      for (var m = 2; m <= 4; m++) ...[
        _tx(5000, DateTime(now.year, now.month - m, 5),
            type: TransactionType.income, category: 'Salário'),
        _tx(400, DateTime(now.year, now.month - m, 8), category: 'Delivery'),
        _tx(400, DateTime(now.year, now.month - m, 20), category: 'Delivery'),
      ],
      _tx(5000, DateTime(now.year, now.month - 1, 5),
          type: TransactionType.income, category: 'Salário'),
      _tx(900, DateTime(now.year, now.month - 1, 12), category: 'Lazer'),
      _tx(5000, DateTime(now.year, now.month, 5),
          type: TransactionType.income, category: 'Salário'),
    ];
    final out = engine.generate(InsightInput(transactions: txs, now: now));
    expect(out.where((i) => i.type == InsightType.categoryDrop), isEmpty);
    expect(
      out.where((i) => i.message.contains('R\$ 0')),
      isEmpty,
    );
  });

  test('queda dispara quando o mês passado gastou menos, mas não zero', () {
    final txs = [
      for (var m = 2; m <= 4; m++) ...[
        _tx(5000, DateTime(now.year, now.month - m, 5),
            type: TransactionType.income, category: 'Salário'),
        _tx(400, DateTime(now.year, now.month - m, 8), category: 'Delivery'),
        _tx(400, DateTime(now.year, now.month - m, 20), category: 'Delivery'),
      ],
      _tx(5000, DateTime(now.year, now.month - 1, 5),
          type: TransactionType.income, category: 'Salário'),
      _tx(250, DateTime(now.year, now.month - 1, 12), category: 'Delivery'),
      _tx(5000, DateTime(now.year, now.month, 5),
          type: TransactionType.income, category: 'Salário'),
    ];
    final drop = _find(
      engine.generate(InsightInput(transactions: txs, now: now)),
      InsightType.categoryDrop,
    )!;
    expect(drop.category, 'Delivery');
    expect(drop.amount, 250);
    expect(drop.message, contains('Delivery'));
    expect(drop.message, contains('maio'));
    expect(drop.message, isNot(contains('junho')));
    expect(drop.periodLabel, 'Maio 2026');
    expect(drop.message, isNot(contains('R\$ 0')));
  });

  test('queda usa o mês fechado, não o total do mês atual', () {
    final txs = [
      for (var m = 2; m <= 4; m++)
        _tx(800, DateTime(now.year, now.month - m, 10), category: 'Delivery'),
      _tx(250, DateTime(now.year, now.month - 1, 12), category: 'Delivery'),
      _tx(400, DateTime(now.year, now.month, 8), category: 'Delivery'),
    ];
    final drop = _find(
      engine.generate(InsightInput(transactions: txs, now: now)),
      InsightType.categoryDrop,
    )!;
    expect(drop.amount, 250);
    expect(drop.message, isNot(contains('400')));
    expect(drop.message, contains('maio'));
    expect(drop.periodLabel, isNot(contains('Junho')));
  });

  test('gasto noturno no fim do mês conta no mês civil, mesmo em UTC', () {
    final lastNight = DateTime(now.year, now.month, 0, 22);
    final txs = [
      for (var m = 2; m <= 4; m++) ...[
        _tx(5000, DateTime(now.year, now.month - m, 5),
            type: TransactionType.income, category: 'Salário'),
        _tx(300, DateTime(now.year, now.month - m, 10), category: 'Farmácia'),
      ],
      _tx(5000, DateTime(now.year, now.month - 1, 5),
          type: TransactionType.income, category: 'Salário'),
      _tx(120, lastNight.toUtc(), category: 'Farmácia'),
      _tx(5000, DateTime(now.year, now.month, 5),
          type: TransactionType.income, category: 'Salário'),
    ];
    final drop = _find(
      engine.generate(InsightInput(transactions: txs, now: now)),
      InsightType.categoryDrop,
    );
    expect(drop?.category, 'Farmácia');
    expect(drop?.amount, 120);
  });

  test('poupança do mês passado some se não houve despesa', () {
    final txs = [
      for (var m = 1; m <= 3; m++)
        _tx(5000, DateTime(now.year, now.month - m, 5),
            type: TransactionType.income, category: 'Salário'),
    ];
    final out = engine.generate(InsightInput(transactions: txs, now: now));
    expect(_find(out, InsightType.savingsRate), isNull);
  });
}
