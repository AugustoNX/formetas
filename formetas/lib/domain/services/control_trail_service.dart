import 'dart:math' as math;

import '../entities/control_trail.dart';
import '../entities/insight.dart';
import '../entities/transaction_entity.dart';

/// Propõe trilhas a partir de insights e mede o progresso com transações reais.
class ControlTrailService {
  const ControlTrailService({this.weeks = 4, this.targetReduction = 0.2});

  /// Duração padrão da trilha.
  final int weeks;

  /// Corte total ao fim da trilha (0.2 = gastar 20% menos na última semana).
  final double targetReduction;

  static const _weeksPerMonth = 52 / 12;

  /// Indica se o insight comporta uma trilha.
  static bool canCreateTrail(Insight insight) =>
      insight.action?.type == InsightActionType.createTrail;

  /// Monta a proposta. Retorna `null` quando não há base histórica suficiente.
  ControlTrail? propose({
    required Insight insight,
    required List<TransactionEntity> transactions,
    required DateTime now,
    double smallPurchaseLimit = 30,
    String? id,
  }) {
    if (!canCreateTrail(insight)) return null;
    final category = insight.action?.category;
    final kind = category == null ? TrailKind.smallPurchases : TrailKind.category;
    final draft = ControlTrail(
      id: '',
      kind: kind,
      title: '',
      category: category,
      smallPurchaseLimit: smallPurchaseLimit,
      startDate: now,
      weeklyBaseline: 0,
      weeklyTargets: const [],
      createdAt: now,
    );

    // Linha de base: média mensal dos 3 meses fechados (ou do mês atual,
    // projetado, se ainda não houver histórico).
    final monthStart = DateTime(now.year, now.month);
    final historyStart = DateTime(now.year, now.month - 3);
    var history = 0.0;
    var current = 0.0;
    for (final tx in transactions) {
      if (!matches(draft, tx)) continue;
      if (!tx.date.isBefore(historyStart) && tx.date.isBefore(monthStart)) history += tx.value;
      if (!tx.date.isBefore(monthStart) && !tx.date.isAfter(now)) current += tx.value;
    }
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final monthly = history > 0 ? history / 3 : current / now.day * daysInMonth;
    final baseline = monthly / _weeksPerMonth;
    if (baseline < 10) return null;

    final targets = [
      for (var i = 1; i <= weeks; i++)
        _roundTo5(baseline * (1 - targetReduction * i / weeks)),
    ];
    final title = kind == TrailKind.category
        ? 'Menos ${category!} em $weeks semanas'
        : 'Menos comprinhas em $weeks semanas';
    return ControlTrail(
      id: id ?? 'trail-${now.microsecondsSinceEpoch}',
      kind: kind,
      title: title,
      category: category,
      smallPurchaseLimit: smallPurchaseLimit,
      startDate: DateTime(now.year, now.month, now.day),
      weeklyBaseline: baseline,
      weeklyTargets: targets,
      insightId: insight.id,
      createdAt: now,
    );
  }

  /// Transação conta para a trilha?
  static bool matches(ControlTrail trail, TransactionEntity tx) {
    if (tx.type != TransactionType.expense) return false;
    return switch (trail.kind) {
      TrailKind.category =>
        tx.category.trim().toLowerCase() == trail.category?.trim().toLowerCase(),
      TrailKind.smallPurchases => tx.value <= trail.smallPurchaseLimit,
    };
  }

  TrailProgress progress({
    required ControlTrail trail,
    required List<TransactionEntity> transactions,
    required DateTime now,
  }) {
    final spent = List<double>.filled(trail.weeks, 0);
    for (final tx in transactions) {
      if (tx.date.isBefore(trail.startDate) || !tx.date.isBefore(trail.endDate)) continue;
      if (tx.date.isAfter(now)) continue; // agendamentos futuros não contam ainda
      if (!matches(trail, tx)) continue;
      final index = tx.date.difference(trail.startDate).inDays ~/ 7;
      if (index >= 0 && index < trail.weeks) spent[index] += tx.value;
    }
    final weeks = [
      for (var i = 0; i < trail.weeks; i++)
        () {
          final start = _addDays(trail.startDate, 7 * i);
          final end = _addDays(trail.startDate, 7 * (i + 1));
          final target = trail.weeklyTargets[i];
          final status = !now.isBefore(end)
              ? (spent[i] <= target ? TrailWeekStatus.met : TrailWeekStatus.missed)
              : now.isBefore(start)
                  ? TrailWeekStatus.upcoming
                  : TrailWeekStatus.inProgress;
          return TrailWeek(
            index: i,
            start: start,
            end: end,
            target: target,
            spent: spent[i],
            status: status,
          );
        }(),
    ];
    return TrailProgress(trail: trail, weeks: weeks);
  }

  // Soma dias pelo calendário (seguro em mudanças de horário de verão).
  static DateTime _addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

  static double _roundTo5(double v) => math.max(5, (v / 5).round() * 5).toDouble();
}
