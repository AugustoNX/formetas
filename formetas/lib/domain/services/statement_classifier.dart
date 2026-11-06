import '../../core/utils/brazil_business_calendar.dart';
import '../entities/import_rule.dart';
import '../entities/statement_import.dart';
import '../entities/transaction_entity.dart';
import 'description_normalizer.dart';
import 'ml/classifier_thresholds.dart';

abstract final class StatementClassifier {
  static const salaryCategory = 'Salário';
  static const reserveName = 'RDB';
  static const highIncome = 1000.0;
  static const salaryBusinessDayLimit = 6;

  static List<StatementEntry> classify(
    List<StatementEntry> entries, {
    String? userName,
    List<ImportRule> rules = const [],
  }) {
    final learned = ImportRuleIndex(rules);
    return [for (final entry in entries) _classify(entry, userName, learned)];
  }

  static StatementEntry _classify(
    StatementEntry entry,
    String? userName,
    ImportRuleIndex rules,
  ) {
    final learned = rules.match(
      entry.description,
      normalize(entry.description),
    );
    if (learned != null) {
      return entry.copyWith(
        role: learned.role,
        category: learned.category,
        type: learned.type,
      );
    }
    return heuristic(entry, userName: userName)?.entry ?? entry;
  }

  /// Fatura, estorno, RDB, salário e Pix para a própria pessoa.
  /// Não olha regras aprendidas: quem chama decide a ordem.
  static StatementHeuristic? heuristic(
    StatementEntry entry, {
    String? userName,
  }) {
    final text = normalize(entry.description);
    if (_containsAny(text, const ['pagamento de fatura', 'pagamento fatura'])) {
      return StatementHeuristic(
        entry: entry.copyWith(role: StatementRole.ignored),
        reasons: const ['Pagamento de fatura não entra no mês'],
      );
    }
    if (text.contains('estorno')) {
      return StatementHeuristic(
        entry: entry.copyWith(role: StatementRole.ignored),
        reasons: const ['Estorno não entra no mês'],
      );
    }
    if (text.contains('aplicacao rdb')) {
      return StatementHeuristic(
        entry: entry.copyWith(role: StatementRole.toReserve),
        reasons: const ['Aplicação na caixinha RDB'],
      );
    }
    if (text.contains('resgate rdb')) {
      return StatementHeuristic(
        entry: entry.copyWith(role: StatementRole.fromReserve),
        reasons: const ['Resgate da caixinha RDB'],
      );
    }
    if (_isSalary(entry, text)) {
      return StatementHeuristic(
        entry: entry.copyWith(
          type: TransactionType.income,
          category: salaryCategory,
        ),
        reasons: const [
          'Recebimento alto no começo do mês, no jeito de salário',
        ],
      );
    }
    if (_isOwnAccount(text, userName)) {
      return StatementHeuristic(
        entry: entry.copyWith(role: StatementRole.ownTransfer),
        reasons: const ['Pix ou transferência no seu próprio nome'],
      );
    }
    return null;
  }

  static bool _isSalary(StatementEntry entry, String text) {
    if (entry.type != TransactionType.income) return false;
    if (_containsAny(text, const ['salario', 'folha de pagamento'])) {
      return true;
    }
    if (_containsAny(text, const [
      'resgate',
      'rdb',
      'estorno',
      'rendimento',
      'dividendo',
      'provento',
    ])) {
      return false;
    }
    if (entry.amount < highIncome) return false;
    final businessDay = BrazilBusinessCalendar.businessDayNumber(entry.date);
    return businessDay != null && businessDay <= salaryBusinessDayLimit;
  }

  static bool _isOwnAccount(String text, String? userName) {
    if (userName == null || userName.trim().isEmpty) return false;
    if (!text.contains('pix') && !text.contains('transferencia')) return false;
    final parts = normalize(
      userName,
    ).split(' ').where((part) => part.length >= 3);
    final tokens = parts.toList();
    if (tokens.isEmpty) return false;
    return tokens.every(text.contains);
  }

  static bool _containsAny(String text, List<String> needles) {
    return needles.any(text.contains);
  }

  static String normalize(String value) {
    const accents = {
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
    };
    final buffer = StringBuffer();
    for (final rune in value.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      final mapped = accents[char];
      if (mapped != null) {
        buffer.write(mapped);
      } else if ((rune >= 48 && rune <= 57) || (rune >= 97 && rune <= 122)) {
        buffer.writeCharCode(rune);
      } else {
        buffer.write(' ');
      }
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

/// O que a heurística antiga decidiu, com uma frase para o usuário.
class StatementHeuristic {
  const StatementHeuristic({required this.entry, required this.reasons});

  final StatementEntry entry;
  final List<String> reasons;
}

/// Regras aprendidas, casadas em três passos para continuar compatível com as
/// regras já gravadas (texto exato normalizado):
/// 1. texto exato, como sempre foi;
/// 2. chave estável do [DescriptionNormalizer] (ignora datas, NSU, CPF...);
/// 3. a regra mais parecida por Jaccard, acima de [fuzzyThreshold].
class ImportRuleIndex {
  ImportRuleIndex(List<ImportRule> rules) {
    for (final rule in rules) {
      if (rule.text.isEmpty) continue;
      _exact[rule.text] = rule;
      final tokens = DescriptionNormalizer.tokens(rule.text);
      if (tokens.isEmpty) continue;
      _byKey[tokens.join(' ')] = rule;
      _tokens.add((tokens, rule));
    }
  }

  static const fuzzyThreshold = ClassifierThresholds.ruleFuzzy;

  final _exact = <String, ImportRule>{};
  final _byKey = <String, ImportRule>{};
  final _tokens = <(List<String>, ImportRule)>[];

  ImportRule? match(String description, String legacyText) {
    final exact = _exact[legacyText];
    if (exact != null) return exact;
    final tokens = DescriptionNormalizer.tokens(description);
    if (tokens.isEmpty) return null;
    final byKey = _byKey[tokens.join(' ')];
    if (byKey != null) return byKey;
    ImportRule? best;
    var bestScore = 0.0;
    for (final (ruleTokens, rule) in _tokens) {
      final score = DescriptionNormalizer.tokenSimilarity(ruleTokens, tokens);
      if (score >= fuzzyThreshold && score > bestScore) {
        best = rule;
        bestScore = score;
      }
    }
    return best;
  }
}
