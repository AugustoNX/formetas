import '../../entities/import_rule.dart';
import '../../entities/recurring_pattern.dart';
import '../../entities/statement_import.dart';
import '../../entities/transaction_entity.dart';
import '../description_normalizer.dart';
import '../statement_classifier.dart';
import 'category_classifier.dart';
import 'classifier_thresholds.dart';
import 'feature_extractor.dart';

enum SuggestionSource { regra, recorrente, aprendido, heuristica, nenhuma }

/// Uma linha de extrato já passada pelo [SmartCategorizer].
///
/// [suggestedCategory] fica nulo quando ninguém sugeriu categoria. O papel
/// sugerido serve para saber, na hora de aprender, se o usuário mudou a linha.
class CategorizedEntry {
  const CategorizedEntry({
    required this.entry,
    required this.source,
    required this.confidence,
    required this.reasons,
    required this.alternatives,
    required this.suggestedCategory,
    required this.suggestedRole,
  });

  final StatementEntry entry;
  final SuggestionSource source;
  final double confidence;
  final List<String> reasons;
  final List<CategoryPrediction> alternatives;
  final String? suggestedCategory;
  final StatementRole suggestedRole;

  bool get needsReview =>
      source == SuggestionSource.nenhuma ||
      confidence < ClassifierThresholds.mediumConfidence;

  CategorizedEntry copyWith({
    StatementEntry? entry,
    SuggestionSource? source,
    double? confidence,
    List<String>? reasons,
    List<CategoryPrediction>? alternatives,
    String? suggestedCategory,
    StatementRole? suggestedRole,
    bool clearSuggestion = false,
  }) {
    return CategorizedEntry(
      entry: entry ?? this.entry,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
      reasons: reasons ?? this.reasons,
      alternatives: alternatives ?? this.alternatives,
      suggestedCategory: clearSuggestion
          ? null
          : (suggestedCategory ?? this.suggestedCategory),
      suggestedRole: suggestedRole ?? this.suggestedRole,
    );
  }
}

/// Decide a categoria de cada linha, nesta ordem:
/// regra salva, padrão recorrente, Naive Bayes, heurística antiga, ou nada.
class SmartCategorizer {
  SmartCategorizer({
    required CategoryClassifier classifier,
    List<ImportRule> rules = const [],
    this.patterns = const [],
    this.userName,
  }) : _rules = ImportRuleIndex(rules) {
    _classifier = classifier;
  }

  late final CategoryClassifier _classifier;
  final ImportRuleIndex _rules;
  final List<RecurringPattern> patterns;
  final String? userName;

  List<CategorizedEntry> categorize(List<StatementEntry> entries) {
    return [for (final entry in entries) categorizeOne(entry)];
  }

  CategorizedEntry categorizeOne(StatementEntry entry) {
    final rule = _rules.match(
      entry.description,
      StatementClassifier.normalize(entry.description),
    );
    if (rule != null) {
      final applied = entry.copyWith(
        role: rule.role,
        category: rule.category,
        type: rule.type,
      );
      return CategorizedEntry(
        entry: applied,
        source: SuggestionSource.regra,
        confidence: 1,
        reasons: const ['Regra que você já ensinou para esta descrição'],
        alternatives: _others(_predict(applied), rule.category),
        suggestedCategory: rule.role == StatementRole.transaction
            ? rule.category
            : null,
        suggestedRole: rule.role,
      );
    }

    final pattern = _matchPattern(entry);
    if (pattern != null) {
      final applied = entry.copyWith(category: pattern.category);
      return CategorizedEntry(
        entry: applied,
        source: SuggestionSource.recorrente,
        confidence: pattern.confidence.clamp(0.0, 1.0).toDouble(),
        reasons: ['Esse lançamento se repete como ${pattern.category}'],
        alternatives: _others(_predict(applied), pattern.category),
        suggestedCategory: pattern.category,
        suggestedRole: entry.role,
      );
    }

    final predictions = _predict(entry);
    final best = predictions.isEmpty ? null : predictions.first;
    if (best != null &&
        best.confidence >= ClassifierThresholds.learnedMinConfidence) {
      final applied = entry.copyWith(category: best.category);
      return CategorizedEntry(
        entry: applied,
        source: SuggestionSource.aprendido,
        confidence: best.confidence,
        reasons: best.reasons,
        alternatives: _others(predictions, best.category),
        suggestedCategory: best.category,
        suggestedRole: entry.role,
      );
    }

    final hint = StatementClassifier.heuristic(entry, userName: userName);
    if (hint != null) {
      final suggested = hint.entry.role == StatementRole.transaction
          ? hint.entry.category
          : null;
      return CategorizedEntry(
        entry: hint.entry,
        source: SuggestionSource.heuristica,
        confidence: 1,
        reasons: hint.reasons,
        alternatives: _others(predictions, suggested),
        suggestedCategory: suggested,
        suggestedRole: hint.entry.role,
      );
    }

    return CategorizedEntry(
      entry: entry.copyWith(category: ''),
      source: SuggestionSource.nenhuma,
      confidence: best?.confidence ?? 0,
      reasons: best?.reasons ?? const [],
      alternatives: predictions.take(3).toList(growable: false),
      suggestedCategory: null,
      suggestedRole: entry.role,
    );
  }

  RecurringPattern? _matchPattern(StatementEntry entry) {
    if (entry.type != TransactionType.income &&
        entry.type != TransactionType.expense) {
      return null;
    }
    final tokens = DescriptionNormalizer.tokens(entry.description);
    if (tokens.isEmpty) return null;

    RecurringPattern? best;
    var bestScore = 0.0;
    for (final pattern in patterns) {
      if (pattern.type != entry.type) continue;
      if (pattern.category.trim().isEmpty) continue;
      if (pattern.confidence < ClassifierThresholds.recurrenceMinConfidence) {
        continue;
      }
      final score = DescriptionNormalizer.tokenSimilarity(
        pattern.key.split(' '),
        tokens,
      );
      if (score >= ClassifierThresholds.recurrenceSimilarity &&
          score > bestScore) {
        best = pattern;
        bestScore = score;
      }
    }
    return best;
  }

  List<CategoryPrediction> _predict(StatementEntry entry) {
    if (entry.type != TransactionType.income &&
        entry.type != TransactionType.expense) {
      return const [];
    }
    return _classifier.predict(
      FeatureExtractor.extract(
        description: entry.description,
        amount: entry.amount,
        type: entry.type,
        date: entry.date,
      ),
      entry.type,
    );
  }

  List<CategoryPrediction> _others(
    List<CategoryPrediction> predictions,
    String? except,
  ) {
    return [
      for (final prediction in predictions)
        if (prediction.category != except) prediction,
    ].take(3).toList(growable: false);
  }
}

/// Aplica [category] na linha [index] e nas outras do mesmo tipo com descrição parecida.
List<CategorizedEntry> withSimilarCategory(
  List<CategorizedEntry> lines,
  int index,
  String category,
) {
  if (index < 0 || index >= lines.length) return lines;
  final source = lines[index].entry;
  final tokens = DescriptionNormalizer.tokens(source.description);
  return [
    for (var i = 0; i < lines.length; i++)
      if (i == index ||
          (lines[i].entry.role == StatementRole.transaction &&
              lines[i].entry.type == source.type &&
              DescriptionNormalizer.tokenSimilarity(
                    tokens,
                    DescriptionNormalizer.tokens(lines[i].entry.description),
                  ) >=
                  ClassifierThresholds.similarApply))
        lines[i].copyWith(entry: lines[i].entry.copyWith(category: category))
      else
        lines[i],
  ];
}
