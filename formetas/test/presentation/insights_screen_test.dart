import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formetas/domain/entities/control_trail.dart';
import 'package:formetas/domain/entities/settings_entity.dart';
import 'package:formetas/domain/entities/transaction_entity.dart';
import 'package:formetas/domain/entities/user_entity.dart';
import 'package:formetas/domain/repositories/insight_repository.dart';
import 'package:formetas/presentation/providers/auth_provider.dart';
import 'package:formetas/presentation/providers/data_providers.dart';
import 'package:formetas/presentation/providers/insight_providers.dart';
import 'package:formetas/presentation/screens/insights/insights_screen.dart';

/// Repositório em memória que imita o RTDB.
class _FakeRepo implements InsightRepository {
  final trails = <String, ControlTrail>{};
  final dismissed = <String>{};
  final _trails = StreamController<List<ControlTrail>>.broadcast();
  final _dismissed = StreamController<Set<String>>.broadcast();

  void _emit() {
    _trails.add(trails.values.toList());
    _dismissed.add({...dismissed});
  }

  @override
  Stream<List<ControlTrail>> watchTrails(String userId) async* {
    yield trails.values.toList();
    yield* _trails.stream;
  }

  @override
  Stream<Set<String>> watchDismissed(String userId) async* {
    yield {...dismissed};
    yield* _dismissed.stream;
  }

  @override
  Future<void> saveTrail(String userId, ControlTrail trail) async {
    trails[trail.id] = trail;
    _emit();
  }

  @override
  Future<void> updateTrailStatus(String userId, String trailId, TrailStatus status) async {
    trails[trailId] = trails[trailId]!.copyWith(status: status);
    _emit();
  }

  @override
  Future<void> deleteTrail(String userId, String trailId) async {
    trails.remove(trailId);
    _emit();
  }

  @override
  Future<void> dismiss(String userId, String insightId) async {
    dismissed.add(insightId);
    _emit();
  }

  @override
  Future<void> clearDismissed(String userId) async {
    dismissed.clear();
    _emit();
  }
}

var _seq = 0;
TransactionEntity _tx(double v, DateTime d, {String cat = 'Delivery', TransactionType type = TransactionType.expense}) {
  _seq++;
  return TransactionEntity(
    id: 't$_seq', userId: 'u', type: type, category: cat, value: v,
    description: 'x', date: d, createdAt: d,
  );
}

void main() {
  final now = DateTime(2026, 6, 15, 10);
  final txs = [
    for (var m = 1; m <= 3; m++) ...[
      _tx(5000, DateTime(2026, 6 - m, 5), cat: 'Salário', type: TransactionType.income),
      _tx(650, DateTime(2026, 6 - m, 12)),
    ],
    _tx(5000, DateTime(2026, 6, 5), cat: 'Salário', type: TransactionType.income),
    _tx(1100, DateTime(2026, 6, 10)),
  ];

  Widget app(_FakeRepo repo) => ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(
            UserEntity(id: 'u', name: 'A', email: 'a@a', createdAt: DateTime(2026)),
          ),
          insightRepositoryProvider.overrideWithValue(repo),
          insightClockProvider.overrideWithValue(() => now),
          transactionsProvider.overrideWith((_) => Stream.value(txs)),
          goalsProvider.overrideWith((_) => Stream.value(const [])),
          reservesWithMovementsProvider.overrideWith((_) => Stream.value(const [])),
          settingsProvider.overrideWith((_) => Stream.value(const SettingsEntity())),
        ],
        child: const MaterialApp(home: InsightsScreen()),
      );

  testWidgets('mostra o pico, cria trilha e acompanha a semana', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('Delivery'), findsWidgets);
    // O primeiro card já vem expandido com a ação.
    final create = find.text('Criar trilha');
    expect(create, findsOneWidget);
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(find.text('Aceitar trilha'), findsOneWidget);
    await tester.tap(find.text('Aceitar trilha'));
    await tester.pumpAndSettle();

    expect(repo.trails, hasLength(1));
    expect(repo.dismissed, contains('categorySpike-2026-06-delivery'));
    await tester.fling(find.byType(ListView), const Offset(0, 2000), 3000);
    await tester.pumpAndSettle();
    expect(find.text('Trilhas em andamento'), findsOneWidget);
    expect(find.textContaining('Semana 1 de 4'), findsOneWidget);
  });

  testWidgets('deslizar dispensa o insight', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    final cards = find.byType(Dismissible);
    final before = tester.widgetList(cards).length;
    await tester.drag(cards.first, const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(repo.dismissed, hasLength(1));
    expect(tester.widgetList(find.byType(Dismissible)).length, before - 1);
    expect(find.byIcon(Icons.restore_rounded), findsOneWidget);
  });
}
