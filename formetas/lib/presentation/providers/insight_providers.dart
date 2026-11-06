import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/reserve_calculator.dart';
import '../../data/datasources/insight_remote_datasource.dart';
import '../../data/repositories/insight_repository_impl.dart';
import '../../domain/entities/control_trail.dart';
import '../../domain/entities/insight.dart';
import '../../domain/repositories/insight_repository.dart';
import '../../domain/services/control_trail_service.dart';
import '../../domain/services/insight_engine.dart';
import 'auth_provider.dart';
import 'data_providers.dart';
import 'recurrence_providers.dart';

// ------------------------------------------------------------------ infra

final insightRemoteDataSourceProvider =
    Provider<InsightRemoteDataSource>((ref) => InsightRemoteDataSource());

final insightRepositoryProvider = Provider<InsightRepository>(
  (ref) => InsightRepositoryImpl(ref.watch(insightRemoteDataSourceProvider)),
);

final insightEngineProvider = Provider<InsightEngine>((_) => const InsightEngine());

final controlTrailServiceProvider =
    Provider<ControlTrailService>((_) => const ControlTrailService());

/// Relógio injetável (facilita testes de widget).
final insightClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

// ------------------------------------------------------------------ dados

final dismissedInsightsProvider = StreamProvider<Set<String>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(<String>{});
  return ref.watch(insightRepositoryProvider).watchDismissed(user.id);
});

final controlTrailsProvider = StreamProvider<List<ControlTrail>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  return ref.watch(insightRepositoryProvider).watchTrails(user.id);
});

/// Saldo atual somado das caixinhas (com rendimento).
final reserveBalanceProvider = Provider<double>((ref) {
  final reserves = ref.watch(reservesWithMovementsProvider).valueOrNull ?? const [];
  final cdi = ref.watch(settingsProvider).valueOrNull?.cdiRate ?? 13.25;
  return reserves.fold(0.0, (sum, r) {
    return sum +
        ReserveCalculator.compute(reserve: r.reserve, movements: r.movements, cdiRate: cdi)
            .currentValue;
  });
});

/// Insights ordenados e já sem os dispensados.
final insightsProvider = Provider<AsyncValue<List<Insight>>>((ref) {
  final transactions = ref.watch(transactionsProvider);
  final patterns = ref.watch(recurringPatternsProvider).valueOrNull ?? const [];
  final goals = ref.watch(goalsProvider).valueOrNull ?? const [];
  final dismissed = ref.watch(dismissedInsightsProvider).valueOrNull ?? const <String>{};
  final reserveBalance = ref.watch(reserveBalanceProvider);
  final engine = ref.watch(insightEngineProvider);
  final now = ref.watch(insightClockProvider)();
  return transactions.whenData(
    (txs) => engine.generate(InsightInput(
      transactions: txs,
      patterns: patterns,
      goals: goals,
      reserveBalance: reserveBalance,
      dismissedIds: dismissed,
      now: now,
    )),
  );
});

/// Trilhas ativas com progresso calculado.
final activeTrailsProgressProvider = Provider<List<TrailProgress>>((ref) {
  final trails = ref.watch(controlTrailsProvider).valueOrNull ?? const [];
  final txs = ref.watch(transactionsProvider).valueOrNull ?? const [];
  final service = ref.watch(controlTrailServiceProvider);
  final now = ref.watch(insightClockProvider)();
  final active = trails.where((t) => t.status == TrailStatus.active).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return [
    for (final t in active) service.progress(trail: t, transactions: txs, now: now),
  ];
});

// ------------------------------------------------------------------ ações

final insightActionsProvider = Provider<InsightActions>(InsightActions.new);

class InsightActions {
  InsightActions(this._ref);

  final Ref _ref;

  String? get _userId => _ref.read(currentUserProvider)?.id;
  InsightRepository get _repo => _ref.read(insightRepositoryProvider);

  Future<void> dismiss(Insight insight) async {
    final uid = _userId;
    if (uid != null) await _repo.dismiss(uid, insight.id);
  }

  Future<void> restoreDismissed() async {
    final uid = _userId;
    if (uid != null) await _repo.clearDismissed(uid);
  }

  /// Proposta de trilha (não salva). `null` = sem histórico suficiente.
  ControlTrail? proposeTrail(Insight insight) {
    final txs = _ref.read(transactionsProvider).valueOrNull ?? const [];
    return _ref.read(controlTrailServiceProvider).propose(
          insight: insight,
          transactions: txs,
          now: _ref.read(insightClockProvider)(),
        );
  }

  Future<void> acceptTrail(ControlTrail trail) async {
    final uid = _userId;
    if (uid == null) return;
    await _repo.saveTrail(uid, trail);
    final insightId = trail.insightId;
    // O insight que originou a trilha sai da lista: agora ele vira desafio.
    if (insightId != null) await _repo.dismiss(uid, insightId);
  }

  Future<void> abandonTrail(ControlTrail trail) => _setStatus(trail, TrailStatus.abandoned);

  Future<void> completeTrail(ControlTrail trail) => _setStatus(trail, TrailStatus.completed);

  Future<void> _setStatus(ControlTrail trail, TrailStatus status) async {
    final uid = _userId;
    if (uid != null) await _repo.updateTrailStatus(uid, trail.id, status);
  }
}
