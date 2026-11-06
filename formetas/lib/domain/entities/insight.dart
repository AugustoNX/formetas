import 'package:equatable/equatable.dart';

/// Tipos de leitura que o motor de insights sabe produzir.
enum InsightType {
  monthForecast,
  categorySpike,
  categoryDrop,
  categoryTrend,
  unusualExpense,
  smallPurchases,
  subscriptions,
  savingsRate,
  incomeArrival,
  goalPace,
}

/// Gravidade de um insight. A ordem importa: maior índice = mais urgente.
enum InsightSeverity { positive, info, warning, alert }

/// O que a tela pode oferecer a partir de um insight.
enum InsightActionType { createTrail, openTransactions, openGoals }

class InsightAction extends Equatable {
  const InsightAction({required this.type, required this.label, this.category});

  final InsightActionType type;
  final String label;

  /// Categoria alvo (para trilhas de categoria). `null` em trilhas de
  /// "compras pequenas" ou ações de navegação.
  final String? category;

  @override
  List<Object?> get props => [type, label, category];
}

/// Ponto de uma mini série exibida no card expandido.
class InsightPoint extends Equatable {
  const InsightPoint(this.label, this.value, {this.highlight = false});

  final String label;
  final double value;
  final bool highlight;

  @override
  List<Object?> get props => [label, value, highlight];
}

/// Uma leitura curta, tipada e acionável sobre as finanças do usuário.
class Insight extends Equatable {
  const Insight({
    required this.id,
    required this.type,
    required this.severity,
    required this.score,
    required this.title,
    required this.message,
    this.amount,
    this.category,
    this.metrics = const {},
    this.details = const [],
    this.series = const [],
    this.action,
    this.periodLabel,
  });

  /// Estável dentro do período (ex.: `categorySpike-2026-11-mercado`),
  /// para que "dispensar" valha até a situação mudar de mês.
  final String id;
  final InsightType type;
  final InsightSeverity severity;

  /// Relevância para ordenação (maior = mais importante).
  final double score;
  final String title;
  final String message;

  /// Valor principal em R$, quando houver.
  final double? amount;
  final String? category;
  final Map<String, double> metrics;
  final List<String> details;
  final List<InsightPoint> series;
  final InsightAction? action;

  /// Mês a que o valor se refere, já formatado (ex.: `Outubro 2026`).
  /// Evita a ambiguidade de "mês passado" vs "este mês".
  final String? periodLabel;

  @override
  List<Object?> get props =>
      [id, type, severity, score, title, message, amount, category, periodLabel];
}
