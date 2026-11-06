import 'dart:math' as math;

import '../entities/recurring_pattern.dart';
import '../entities/transaction_entity.dart';
import 'description_normalizer.dart';

/// Descobre salários, contas fixas e assinaturas no histórico.
///
/// Tudo roda no aparelho, sem serviço externo: agrupa as transações pela
/// descrição normalizada (com junção aproximada por Jaccard), mede o intervalo
/// entre as ocorrências e a estabilidade do valor.
class RecurrenceDetector {
  const RecurrenceDetector({
    this.similarityThreshold = DescriptionNormalizer.defaultThreshold,
    this.amountTolerance = 0.25,
    this.minConfidence = 0.4,
  });

  final double similarityThreshold;

  /// Coeficiente de variação máximo para o valor ser considerado estável.
  final double amountTolerance;
  final double minConfidence;

  static const _subscriptionHints = [
    'netflix', 'spotify', 'prime', 'amazon', 'disney', 'hbo', 'max',
    'youtube', 'apple', 'icloud', 'google', 'globoplay', 'deezer',
    'paramount', 'crunchyroll', 'openai', 'chatgpt', 'microsoft', 'xbox',
    'playstation', 'steam', 'smartfit', 'smart', 'gympass', 'wellhub',
    'academia', 'ifood', 'clube', 'assinatura', 'mensalidade', 'uol',
    'adobe', 'canva', 'dropbox', 'tinder', 'duolingo', 'kindle', 'audible',
  ];

  static const _salaryHints = ['salario', 'folha', 'pagamento', 'proventos', 'remuneracao'];

  /// [referenceDate] define o "hoje": padrões sem ocorrência recente (mais de
  /// 2,5 ciclos) são descartados, a menos que [includeInactive] seja true.
  List<RecurringPattern> detect(
    List<TransactionEntity> transactions, {
    DateTime? referenceDate,
    bool includeInactive = false,
  }) {
    final now = referenceDate ?? DateTime.now();
    final clusters = _cluster(transactions);
    final patterns = <RecurringPattern>[];
    for (final cluster in clusters) {
      final pattern = _analyze(cluster);
      if (pattern == null) continue;
      if (pattern.confidence < minConfidence) continue;
      if (!includeInactive && !_isActive(pattern, now)) continue;
      patterns.add(pattern);
    }
    patterns.sort((a, b) {
      final byConfidence = b.confidence.compareTo(a.confidence);
      return byConfidence != 0
          ? byConfidence
          : a.expectedNextDate.compareTo(b.expectedNextDate);
    });
    return patterns;
  }

  // ---------------------------------------------------------------------------
  // Agrupamento
  // ---------------------------------------------------------------------------

  List<_Cluster> _cluster(List<TransactionEntity> transactions) {
    final candidates = transactions
        .where((t) =>
            t.type == TransactionType.income || t.type == TransactionType.expense)
        .where((t) => t.value > 0)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final byKey = <String, _Cluster>{};
    final clusters = <_Cluster>[];
    for (final transaction in candidates) {
      final tokens = DescriptionNormalizer.tokens(transaction.description);
      if (tokens.isEmpty) continue;
      final key = '${transaction.type.name}|${tokens.join(' ')}';

      var cluster = byKey[key];
      if (cluster == null) {
        _Cluster? best;
        var bestScore = 0.0;
        for (final candidate in clusters) {
          if (candidate.type != transaction.type) continue;
          final score =
              DescriptionNormalizer.tokenSimilarity(candidate.tokens, tokens);
          if (score >= similarityThreshold && score > bestScore) {
            best = candidate;
            bestScore = score;
          }
        }
        if (best == null) {
          best = _Cluster(type: transaction.type, tokens: tokens);
          clusters.add(best);
        }
        cluster = best;
        byKey[key] = cluster;
      }
      cluster.items.add(transaction);
    }
    return clusters;
  }

  // ---------------------------------------------------------------------------
  // Análise de um grupo
  // ---------------------------------------------------------------------------

  RecurringPattern? _analyze(_Cluster cluster) {
    // Duas linhas no mesmo dia contam como uma ocorrência (ex.: parcelas).
    final byDay = <DateTime, List<TransactionEntity>>{};
    for (final item in cluster.items) {
      byDay.putIfAbsent(_day(item.date), () => []).add(item);
    }
    final days = byDay.keys.toList()..sort();
    if (days.length < 2) return null;

    final intervals = [
      for (var i = 1; i < days.length; i++) days[i].difference(days[i - 1]).inDays,
    ];
    final cadence = _cadenceOf(_median(intervals.map((d) => d.toDouble()).toList()));
    if (cadence == null) return null;

    final minOccurrences = cadence == RecurrenceCadence.weekly ? 3 : 2;
    if (days.length < minOccurrences) return null;

    final regularity = _regularity(intervals, cadence);
    if (regularity < 0.5) return null;

    final amounts = [
      for (final day in days) byDay[day]!.fold(0.0, (sum, t) => sum + t.value),
    ];
    final mean = amounts.reduce((a, b) => a + b) / amounts.length;
    final variance = amounts.fold(0.0, (sum, a) => sum + (a - mean) * (a - mean)) /
        amounts.length;
    final cv = mean <= 0 ? 0.0 : math.sqrt(variance) / mean;
    if (cv > amountTolerance * 2) return null;

    final ordered = [...cluster.items]..sort((a, b) => a.date.compareTo(b.date));
    final last = ordered.last;
    final text = ordered.map((t) => DescriptionNormalizer.key(t.description)).join(' ');
    final category = _mostCommon(ordered.map((t) => t.category.trim()));

    final occurrenceScore = math.min(1.0, days.length / 6);
    final amountScore = (1 - cv / amountTolerance).clamp(0.0, 1.0);
    final confidence =
        (0.35 * occurrenceScore + 0.4 * regularity + 0.25 * amountScore)
            .clamp(0.0, 1.0)
            .toDouble();

    return RecurringPattern(
      key: cluster.tokens.join(' '),
      label: last.description.trim(),
      kind: _kindOf(cluster.type, text, category, mean, cv, cadence),
      type: cluster.type,
      cadence: cadence,
      averageAmount: mean,
      amountVariance: cv,
      lastDate: last.date,
      expectedNextDate: _next(days.last, cadence, days),
      confidence: confidence,
      transactionIds: [for (final t in ordered) t.id],
      category: category.isEmpty ? 'Outros' : category,
    );
  }

  RecurrenceCadence? _cadenceOf(double medianDays) {
    if (medianDays >= 5 && medianDays <= 9) return RecurrenceCadence.weekly;
    if (medianDays >= 25 && medianDays <= 36) return RecurrenceCadence.monthly;
    if (medianDays >= 340 && medianDays <= 390) return RecurrenceCadence.yearly;
    return null;
  }

  /// Fração dos intervalos que batem com o ciclo. Um mês pulado (intervalo
  /// de dois ciclos) vale meio ponto em vez de quebrar o padrão.
  double _regularity(List<int> intervals, RecurrenceCadence cadence) {
    final (period, tolerance) = switch (cadence) {
      RecurrenceCadence.weekly => (7, 2),
      RecurrenceCadence.monthly => (30, 5),
      RecurrenceCadence.yearly => (365, 20),
    };
    var score = 0.0;
    for (final interval in intervals) {
      if ((interval - period).abs() <= tolerance) {
        score += 1;
      } else if ((interval - 2 * period).abs() <= tolerance * 2) {
        score += 0.5;
      }
    }
    return score / intervals.length;
  }

  RecurringKind _kindOf(
    TransactionType type,
    String text,
    String category,
    double mean,
    double cv,
    RecurrenceCadence cadence,
  ) {
    final normalizedCategory = DescriptionNormalizer.key(category);
    if (type == TransactionType.income) {
      final looksLikeSalary = normalizedCategory.contains('salario') ||
          _salaryHints.any(text.contains) ||
          (cadence == RecurrenceCadence.monthly && mean >= 1000);
      return looksLikeSalary ? RecurringKind.salary : RecurringKind.income;
    }
    final words = text.split(' ').toSet();
    final hinted = _subscriptionHints.any(words.contains) ||
        normalizedCategory.contains('assinatura');
    if (hinted) return RecurringKind.subscription;
    if (cadence != RecurrenceCadence.weekly && cv < 0.02 && mean < 150) {
      return RecurringKind.subscription;
    }
    return RecurringKind.bill;
  }

  DateTime _next(DateTime last, RecurrenceCadence cadence, List<DateTime> days) {
    switch (cadence) {
      case RecurrenceCadence.weekly:
        return last.add(const Duration(days: 7));
      case RecurrenceCadence.monthly:
        // Usa o dia do mês mais comum, para não arrastar atrasos pontuais.
        final day = int.parse(_mostCommon(days.map((d) => '${d.day}')));
        return _clampDay(last.year, last.month + 1, day);
      case RecurrenceCadence.yearly:
        return _clampDay(last.year + 1, last.month, last.day);
    }
  }

  bool _isActive(RecurringPattern pattern, DateTime now) {
    final cycle = switch (pattern.cadence) {
      RecurrenceCadence.weekly => 7,
      RecurrenceCadence.monthly => 30,
      RecurrenceCadence.yearly => 365,
    };
    return now.difference(pattern.lastDate).inDays <= (cycle * 2.5).round();
  }

  static DateTime _clampDay(int year, int month, int day) {
    final normalized = DateTime(year, month);
    final lastDay = DateTime(normalized.year, normalized.month + 1, 0).day;
    return DateTime(normalized.year, normalized.month, math.min(day, lastDay));
  }

  static DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

  static double _median(List<double> values) {
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  static String _mostCommon(Iterable<String> values) {
    final counts = <String, int>{};
    String best = '';
    var bestCount = 0;
    for (final value in values) {
      final count = (counts[value] ?? 0) + 1;
      counts[value] = count;
      if (count > bestCount) {
        best = value;
        bestCount = count;
      }
    }
    return best;
  }
}

class _Cluster {
  _Cluster({required this.type, required this.tokens});

  final TransactionType type;
  final List<String> tokens;
  final List<TransactionEntity> items = [];
}
