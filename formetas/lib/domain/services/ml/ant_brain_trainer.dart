import '../../entities/ant_brain.dart';
import '../../entities/statement_import.dart';
import '../../entities/transaction_entity.dart';
import 'category_classifier.dart';
import 'classifier_thresholds.dart';
import 'feature_extractor.dart';
import 'smart_categorizer.dart';

/// Atualiza contagens e o histórico quando o usuário confirma um extrato.
class AntBrainTrainer {
  const AntBrainTrainer();

  ({AntBrainSnapshot snapshot, ImportSummary summary}) learnImport({
    required AntBrainSnapshot snapshot,
    required List<CategorizedEntry> lines,
    DateTime? now,
  }) {
    final moment = now ?? DateTime.now();
    final model = CategoryClassifier.fromMap(snapshot.model.toMap());
    var accepted = 0;
    var corrected = 0;
    var regra = 0;
    var recorrente = 0;
    var aprendido = 0;
    var heuristica = 0;
    var semSugestao = 0;
    var total = 0;

    for (final line in lines) {
      if (!line.entry.included) continue;
      total++;
      switch (line.source) {
        case SuggestionSource.regra:
          regra++;
        case SuggestionSource.recorrente:
          recorrente++;
        case SuggestionSource.aprendido:
          aprendido++;
        case SuggestionSource.heuristica:
          heuristica++;
        case SuggestionSource.nenhuma:
          semSugestao++;
      }

      final kept = _kept(line);
      if (line.source != SuggestionSource.nenhuma) {
        if (kept) {
          accepted++;
        } else {
          corrected++;
        }
      }
      _teach(model, line, moment, kept);
    }

    final stat = ImportStat(
      at: moment,
      total: total,
      accepted: accepted,
      corrected: corrected,
      regra: regra,
      recorrente: recorrente,
      aprendido: aprendido,
      heuristica: heuristica,
      semSugestao: semSugestao,
    );
    final history = [...snapshot.history, stat];
    final trimmed = history.length <= ClassifierThresholds.maxHistory
        ? history
        : history.sublist(history.length - ClassifierThresholds.maxHistory);

    return (
      snapshot: AntBrainSnapshot(
        model: model,
        history: trimmed,
        cleared: false,
      ),
      summary: ImportSummary(
        total: total,
        accepted: accepted,
        corrected: corrected,
        regra: regra,
        recorrente: recorrente,
        aprendido: aprendido,
        heuristica: heuristica,
        semSugestao: semSugestao,
        previousRate: _lastRate(snapshot.history),
      ),
    );
  }

  void _teach(
    CategoryClassifier model,
    CategorizedEntry line,
    DateTime now,
    bool kept,
  ) {
    final entry = line.entry;
    if (entry.role != StatementRole.transaction) return;
    if (entry.type != TransactionType.income &&
        entry.type != TransactionType.expense) {
      return;
    }
    final category = entry.category.trim();
    if (category.isEmpty) return;

    final features = FeatureExtractor.extract(
      description: entry.description,
      amount: entry.amount,
      type: entry.type,
      date: entry.date,
    );
    final weight = kept && line.source != SuggestionSource.nenhuma
        ? ClassifierThresholds.acceptWeight
        : ClassifierThresholds.correctionWeight;
    model.train(features, category, type: entry.type, weight: weight, now: now);
  }

  bool _kept(CategorizedEntry line) {
    final categoryOk =
        line.suggestedCategory == null ||
        line.entry.category.trim() == line.suggestedCategory;
    return categoryOk && line.entry.role == line.suggestedRole;
  }

  double? _lastRate(List<ImportStat> history) {
    for (var i = history.length - 1; i >= 0; i--) {
      final rate = history[i].rate;
      if (rate != null) return rate;
    }
    return null;
  }
}
