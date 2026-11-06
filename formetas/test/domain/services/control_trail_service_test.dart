import 'package:flutter_test/flutter_test.dart';
import 'package:formetas/data/models/control_trail_model.dart';
import 'package:formetas/domain/entities/control_trail.dart';
import 'package:formetas/domain/entities/insight.dart';
import 'package:formetas/domain/entities/transaction_entity.dart';
import 'package:formetas/domain/services/control_trail_service.dart';

var _seq = 0;
TransactionEntity _tx(double value, DateTime date, {String category = 'Delivery'}) {
  _seq++;
  return TransactionEntity(
    id: 't$_seq', userId: 'u', type: TransactionType.expense, category: category,
    value: value, description: 'x', date: date, createdAt: date,
  );
}

const _spike = Insight(
  id: 'categorySpike-2026-06-delivery',
  type: InsightType.categorySpike,
  severity: InsightSeverity.warning,
  score: 70,
  title: 't',
  message: 'm',
  category: 'Delivery',
  action: InsightAction(type: InsightActionType.createTrail, label: 'Criar trilha', category: 'Delivery'),
);

void main() {
  const service = ControlTrailService();
  final now = DateTime(2026, 6, 10, 9);
  // 3 meses com 650/mês em delivery = 150/semana.
  final history = [
    for (var m = 1; m <= 3; m++) _tx(650, DateTime(2026, 6 - m, 12)),
  ];

  test('proposta com metas semanais decrescentes', () {
    final trail = service.propose(insight: _spike, transactions: history, now: now, id: 'tr1')!;
    expect(trail.kind, TrailKind.category);
    expect(trail.weeklyBaseline, closeTo(150, 0.01));
    expect(trail.weeklyTargets, [145, 135, 130, 120]);
    expect(trail.startDate, DateTime(2026, 6, 10));
    expect(trail.endDate, DateTime(2026, 7, 8));
    expect(trail.plannedSaving, closeTo(70, 0.01));
    expect(trail.insightId, _spike.id);
  });

  test('sem histórico não propõe', () {
    expect(service.propose(insight: _spike, transactions: const [], now: now), isNull);
  });

  test('progresso semana a semana com transações reais', () {
    final trail = service.propose(insight: _spike, transactions: history, now: now, id: 'tr1')!;
    final txs = [
      ...history,
      _tx(100, DateTime(2026, 6, 11)), // S1 ok (<=145)
      _tx(160, DateTime(2026, 6, 18)), // S2 estourou (>135)
      _tx(40, DateTime(2026, 6, 25)), // S3 em andamento
      _tx(999, DateTime(2026, 6, 25), category: 'Mercado'), // outra categoria
      _tx(50, DateTime(2026, 6, 29)), // futuro: não conta
    ];
    final p = service.progress(trail: trail, transactions: txs, now: DateTime(2026, 6, 26, 10));
    expect(p.weeks.map((w) => w.status), [
      TrailWeekStatus.met,
      TrailWeekStatus.missed,
      TrailWeekStatus.inProgress,
      TrailWeekStatus.upcoming,
    ]);
    expect(p.weeks[2].spent, 40);
    expect(p.currentWeek!.index, 2);
    expect(p.metCount, 1);
    expect(p.isFinished, isFalse);
    expect(p.savedSoFar, closeTo(150 - 100 + 150 - 160, 0.01));

    final end = service.progress(trail: trail, transactions: txs, now: DateTime(2026, 7, 9));
    expect(end.isFinished, isTrue);
    expect(end.currentWeek, isNull);
  });

  test('trilha de compras pequenas conta só compras até o limite', () {
    const small = Insight(
      id: 'smallPurchases-2026-06', type: InsightType.smallPurchases,
      severity: InsightSeverity.info, score: 50, title: 't', message: 'm',
      action: InsightAction(type: InsightActionType.createTrail, label: 'Criar trilha'),
    );
    final txs = [
      for (var m = 1; m <= 3; m++)
        for (var d = 1; d <= 20; d++) _tx(15, DateTime(2026, 6 - m, d), category: 'Café'),
      _tx(500, DateTime(2026, 5, 3), category: 'Café'),
    ];
    final trail = service.propose(insight: small, transactions: txs, now: now)!;
    expect(trail.kind, TrailKind.smallPurchases);
    expect(trail.weeklyBaseline, closeTo(300 / (52 / 12), 0.01));
  });

  test('modelo RTDB faz ida e volta', () {
    final trail = service.propose(insight: _spike, transactions: history, now: now, id: 'tr1')!;
    final back = ControlTrailModel.fromMap(ControlTrailModel.toMap(trail), 'tr1');
    expect(back, trail);
    expect(back.weeklyBaseline, trail.weeklyBaseline);
    final asMap = ControlTrailModel.toMap(trail)
      ..['metasSemanais'] = {'1': 135, '0': 145, '2': 130, '3': 120};
    expect(ControlTrailModel.fromMap(asMap, 'tr1').weeklyTargets, [145, 135, 130, 120]);
  });
}
