import 'package:equatable/equatable.dart';

/// Trilha alvo: uma categoria específica ou o conjunto de compras pequenas.
enum TrailKind { category, smallPurchases }

enum TrailStatus { active, completed, abandoned }

enum TrailWeekStatus { upcoming, inProgress, met, missed }

/// Desafio de controle de gastos com metas semanais decrescentes.
class ControlTrail extends Equatable {
  const ControlTrail({
    required this.id,
    required this.kind,
    required this.title,
    required this.startDate,
    required this.weeklyBaseline,
    required this.weeklyTargets,
    required this.createdAt,
    this.category,
    this.smallPurchaseLimit = 30,
    this.status = TrailStatus.active,
    this.insightId,
  });

  final String id;
  final TrailKind kind;
  final String title;

  /// Categoria-alvo quando [kind] é [TrailKind.category].
  final String? category;

  /// Teto por compra usado quando [kind] é [TrailKind.smallPurchases].
  final double smallPurchaseLimit;

  /// Início da semana 1 (sempre à meia-noite).
  final DateTime startDate;

  /// Gasto semanal médio antes da trilha.
  final double weeklyBaseline;
  final List<double> weeklyTargets;
  final TrailStatus status;
  final String? insightId;
  final DateTime createdAt;

  int get weeks => weeklyTargets.length;
  DateTime get endDate =>
      DateTime(startDate.year, startDate.month, startDate.day + 7 * weeks);
  double get totalTarget => weeklyTargets.fold(0.0, (a, b) => a + b);
  double get plannedSaving => weeklyBaseline * weeks - totalTarget;

  ControlTrail copyWith({TrailStatus? status}) => ControlTrail(
        id: id,
        kind: kind,
        title: title,
        category: category,
        smallPurchaseLimit: smallPurchaseLimit,
        startDate: startDate,
        weeklyBaseline: weeklyBaseline,
        weeklyTargets: weeklyTargets,
        status: status ?? this.status,
        insightId: insightId,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => [id, kind, category, startDate, weeklyTargets, status];
}

class TrailWeek extends Equatable {
  const TrailWeek({
    required this.index,
    required this.start,
    required this.end,
    required this.target,
    required this.spent,
    required this.status,
  });

  final int index;
  final DateTime start;

  /// Exclusivo.
  final DateTime end;
  final double target;
  final double spent;
  final TrailWeekStatus status;

  double get ratio => target <= 0 ? (spent > 0 ? 1.5 : 0) : spent / target;
  double get remaining => target - spent;

  @override
  List<Object?> get props => [index, start, target, spent, status];
}

/// Progresso calculado a partir das transações reais.
class TrailProgress extends Equatable {
  const TrailProgress({required this.trail, required this.weeks});

  final ControlTrail trail;
  final List<TrailWeek> weeks;

  TrailWeek? get currentWeek {
    for (final w in weeks) {
      if (w.status == TrailWeekStatus.inProgress) return w;
    }
    return null;
  }

  int get metCount => weeks.where((w) => w.status == TrailWeekStatus.met).length;
  int get closedCount => weeks
      .where((w) => w.status == TrailWeekStatus.met || w.status == TrailWeekStatus.missed)
      .length;
  bool get isFinished => closedCount == weeks.length;
  double get totalSpent => weeks.fold(0.0, (a, w) => a + w.spent);

  /// Fração do tempo decorrido (0..1), para a barra de progresso.
  double timeProgress(DateTime now) {
    final total = trail.endDate.difference(trail.startDate).inMinutes;
    final done = now.difference(trail.startDate).inMinutes;
    return total <= 0 ? 1 : (done / total).clamp(0.0, 1.0);
  }

  /// Economia real até aqui em relação à linha de base das semanas fechadas
  /// e da semana corrente.
  double get savedSoFar {
    var saved = 0.0;
    for (final w in weeks) {
      if (w.status == TrailWeekStatus.upcoming) continue;
      if (w.status == TrailWeekStatus.inProgress) continue;
      saved += trail.weeklyBaseline - w.spent;
    }
    return saved;
  }

  @override
  List<Object?> get props => [trail, weeks];
}
