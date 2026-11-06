import '../services/ml/category_classifier.dart';

/// Uma importação lembrada para o gráfico de acerto.
class ImportStat {
  const ImportStat({
    required this.at,
    required this.total,
    required this.accepted,
    required this.corrected,
    required this.regra,
    required this.recorrente,
    required this.aprendido,
    required this.heuristica,
    required this.semSugestao,
  });

  final DateTime at;
  final int total;
  final int accepted;
  final int corrected;
  final int regra;
  final int recorrente;
  final int aprendido;
  final int heuristica;
  final int semSugestao;

  int get suggested => accepted + corrected;

  double? get rate => suggested == 0 ? null : accepted / suggested;
}

/// Frase do resumo logo depois de importar.
class ImportSummary {
  const ImportSummary({
    required this.total,
    required this.accepted,
    required this.corrected,
    required this.regra,
    required this.recorrente,
    required this.aprendido,
    required this.heuristica,
    required this.semSugestao,
    this.previousRate,
  });

  final int total;
  final int accepted;
  final int corrected;
  final int regra;
  final int recorrente;
  final int aprendido;
  final int heuristica;
  final int semSugestao;
  final double? previousRate;

  int get suggested => accepted + corrected;

  double? get rate => suggested == 0 ? null : accepted / suggested;

  String get message {
    final hit = rate;
    if (hit == null) {
      return 'A formiga ainda não tinha uma sugestão. '
          'O que você escolheu passa a fazer parte do aprendizado.';
    }
    final percent = (hit * 100).round();
    final base = 'A formiga acertou $accepted de $suggested ($percent%).';
    final previous = previousRate;
    if (previous == null) return base;
    final before = (previous * 100).round();
    if (percent > before) {
      return '$base Subiu em relação aos $before% da importação anterior.';
    }
    if (percent == before) {
      return '$base A taxa ficou igual à importação anterior.';
    }
    return '$base Na importação anterior tinha sido $before%.';
  }
}

/// Modelo em memória mais o histórico curto de acertos.
class AntBrainSnapshot {
  const AntBrainSnapshot({
    required this.model,
    this.history = const [],
    this.cleared = false,
  });

  factory AntBrainSnapshot.empty() =>
      AntBrainSnapshot(model: CategoryClassifier());

  final CategoryClassifier model;
  final List<ImportStat> history;

  /// Verdadeiro depois de "Zerar aprendizado": o histórico não volta sozinho.
  final bool cleared;

  double? get recentRate {
    final rates = [
      for (final stat in history) stat.rate,
    ].whereType<double>().toList();
    if (rates.isEmpty) return null;
    return rates.reduce((a, b) => a + b) / rates.length;
  }
}
