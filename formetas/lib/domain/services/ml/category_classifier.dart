import 'dart:isolate';
import 'dart:math' as math;

import '../../entities/transaction_entity.dart';
import 'classifier_thresholds.dart';
import 'feature_extractor.dart';

/// Uma categoria sugerida, já ordenada da mais provável para a menos.
class CategoryPrediction {
  const CategoryPrediction({
    required this.category,
    required this.confidence,
    required this.reasons,
  });

  final String category;

  /// 0 a 1, depois do softmax das log-probabilidades.
  final double confidence;

  /// Até três tokens que mais puxaram esta categoria.
  final List<String> reasons;
}

/// Naive Bayes multinomial incremental, separado por receita e despesa.
///
/// [train] e [untrain] só atualizam contagens. O estado cabe num mapa
/// enxuto: cada categoria guarda no máximo
/// [ClassifierThresholds.maxFeaturesPerCategory] atributos.
class CategoryClassifier {
  CategoryClassifier({int? maxFeaturesPerCategory})
    : maxFeaturesPerCategory =
          maxFeaturesPerCategory ?? ClassifierThresholds.maxFeaturesPerCategory,
      _schemaVersion = ClassifierThresholds.schemaVersion,
      _expense = _Bucket(),
      _income = _Bucket();

  CategoryClassifier._({
    required this._schemaVersion,
    required int examples,
    required this._updatedAt,
    required this._expense,
    required this._income,
    required this.maxFeaturesPerCategory,
  }) {
    _examples = examples;
  }

  final int maxFeaturesPerCategory;

  final int _schemaVersion;
  int _examples = 0;
  DateTime? _updatedAt;
  final _Bucket _expense;
  final _Bucket _income;

  int get schemaVersion => _schemaVersion;
  int get exampleCount => _examples;
  DateTime? get updatedAt => _updatedAt;
  bool get isEmpty => _expense.isEmpty && _income.isEmpty;

  /// Treina com o histórico já categorizado. Listas grandes rodam noutro
  /// isolate para não travar a interface; o resultado volta como mapa.
  static Future<CategoryClassifier> bootstrap(
    List<TransactionEntity> transactions,
  ) {
    final payload = <Map<String, Object?>>[
      for (final transaction in transactions)
        if (_trainable(transaction)) _rowOf(transaction),
    ];
    if (payload.length < ClassifierThresholds.bootstrapIsolateAt) {
      return Future<CategoryClassifier>.value(trainPayload(payload));
    }
    return Isolate.run(
      () => trainPayload(payload).toMap(),
    ).then((raw) => CategoryClassifier.fromMap(Map<String, Object?>.from(raw)));
  }

  static CategoryClassifier trainPayload(List<Map<String, Object?>> payload) {
    final model = CategoryClassifier();
    final ordered = [...payload]
      ..sort((a, b) => (a['dateMs'] as int).compareTo(b['dateMs'] as int));
    for (final row in ordered) {
      final type = TransactionType.values[row['type'] as int];
      final paymentIndex = row['payment'] as int?;
      model.train(
        FeatureExtractor.extract(
          description: row['description'] as String,
          amount: (row['amount'] as num).toDouble(),
          type: type,
          date: DateTime.fromMillisecondsSinceEpoch(row['dateMs'] as int),
          paymentMethod: paymentIndex == null
              ? null
              : PaymentMethod.values[paymentIndex],
        ),
        row['category'] as String,
        type: type,
        now: DateTime.fromMillisecondsSinceEpoch(row['dateMs'] as int),
      );
    }
    return model;
  }

  void train(
    List<String> features,
    String category, {
    required TransactionType type,
    double weight = 1,
    DateTime? now,
  }) {
    final name = category.trim();
    final unique = features.toSet().toList();
    if (name.isEmpty || weight <= 0 || unique.isEmpty) return;
    final bucket = _bucket(type);
    if (bucket == null) return;

    _decay(now ?? DateTime.now());
    bucket.add(name, unique, weight);
    bucket.prune(name, maxFeaturesPerCategory);
    _examples += 1;
  }

  /// Desfaz um [train] com o mesmo peso. No mesmo dia, sem poda no meio,
  /// o estado volta a ser o anterior.
  void untrain(
    List<String> features,
    String category, {
    required TransactionType type,
    double weight = 1,
  }) {
    final name = category.trim();
    final unique = features.toSet().toList();
    if (name.isEmpty || weight <= 0 || unique.isEmpty) return;
    final bucket = _bucket(type);
    if (bucket == null) return;
    if (!bucket.remove(name, unique, weight)) return;
    if (_examples > 0) _examples -= 1;
    if (isEmpty) {
      _examples = 0;
      _updatedAt = null;
    }
  }

  List<CategoryPrediction> predict(
    List<String> features,
    TransactionType type,
  ) {
    final bucket = _bucket(type);
    if (bucket == null || bucket.isEmpty) return const [];

    final alpha = ClassifierThresholds.laplaceAlpha;
    final vocab = bucket.vocabulary;
    if (vocab.isEmpty) return const [];

    final present = <String>[
      for (final feature in features.toSet())
        if (vocab.contains(feature)) feature,
    ];
    final categoryCount = bucket.docs.length;
    final denoms = <String, double>{
      for (final name in bucket.docs.keys)
        name: (bucket.mass[name] ?? 0) + alpha * vocab.length,
    };

    final scores = <String, double>{};
    for (final name in bucket.docs.keys) {
      final prior =
          ((bucket.docs[name] ?? 0) + alpha) /
          (bucket.totalDocs + alpha * categoryCount);
      var score = math.log(prior);
      final denom = denoms[name]!;
      final counts = bucket.features[name];
      for (final feature in present) {
        final count = counts?[feature] ?? 0;
        score +=
            FeatureExtractor.weightOf(feature) *
            math.log((count + alpha) / denom);
      }
      scores[name] = score;
    }
    if (scores.isEmpty) return const [];

    var maxScore = scores.values.first;
    for (final score in scores.values) {
      if (score > maxScore) maxScore = score;
    }
    final exps = <String, double>{
      for (final entry in scores.entries)
        entry.key: math.exp(entry.value - maxScore),
    };
    final sum = exps.values.fold(0.0, (total, value) => total + value);
    if (sum <= 0) return const [];

    final ranked = scores.keys.toList()
      ..sort((a, b) {
        final byScore = scores[b]!.compareTo(scores[a]!);
        return byScore != 0 ? byScore : a.compareTo(b);
      });

    return [
      for (var i = 0; i < ranked.length; i++)
        CategoryPrediction(
          category: ranked[i],
          confidence: (exps[ranked[i]]! / sum).clamp(0.0, 1.0).toDouble(),
          reasons: _reasons(
            bucket: bucket,
            category: ranked[i],
            rival: ranked.length == 1 ? null : ranked[i == 0 ? 1 : 0],
            present: present,
            denoms: denoms,
          ),
        ),
    ];
  }

  Map<String, Object?> toMap() {
    return {
      'schemaVersion': _schemaVersion,
      'exemplos': _examples,
      if (_updatedAt != null) 'atualizadoEm': _stamp(_updatedAt!),
      'despesa': _expense.toList(),
      'receita': _income.toList(),
    };
  }

  factory CategoryClassifier.fromMap(
    Map<String, Object?> map, {
    int? maxFeaturesPerCategory,
  }) {
    return CategoryClassifier._(
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 0,
      examples: (map['exemplos'] as num?)?.toInt() ?? 0,
      updatedAt: _parseStamp(map['atualizadoEm']),
      expense: _Bucket.fromList(map['despesa']),
      income: _Bucket.fromList(map['receita']),
      maxFeaturesPerCategory:
          maxFeaturesPerCategory ?? ClassifierThresholds.maxFeaturesPerCategory,
    );
  }

  List<String> _reasons({
    required _Bucket bucket,
    required String category,
    required String? rival,
    required List<String> present,
    required Map<String, double> denoms,
  }) {
    final alpha = ClassifierThresholds.laplaceAlpha;
    final scored = <(double, String)>[];
    for (final feature in present) {
      if (!feature.startsWith('w:') && !feature.startsWith('b:')) continue;
      final mine = _logFeature(bucket, category, feature, denoms, alpha);
      final other = rival == null
          ? 0.0
          : _logFeature(bucket, rival, feature, denoms, alpha);
      scored.add((
        FeatureExtractor.weightOf(feature) * (mine - other),
        FeatureExtractor.describe(feature),
      ));
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));

    final reasons = <String>[];
    for (final item in scored) {
      if (item.$1 <= 0 && reasons.isNotEmpty) break;
      if (reasons.contains(item.$2)) continue;
      reasons.add(item.$2);
      if (reasons.length == 3) break;
    }
    return List.unmodifiable(reasons);
  }

  double _logFeature(
    _Bucket bucket,
    String category,
    String feature,
    Map<String, double> denoms,
    double alpha,
  ) {
    final count = bucket.features[category]?[feature] ?? 0;
    final denom = denoms[category] ?? alpha;
    return math.log((count + alpha) / denom);
  }

  void _decay(DateTime now) {
    final previous = _updatedAt;
    _updatedAt = now;
    if (previous == null) return;
    final days = now.difference(previous).inDays;
    if (days <= 0) return;
    final capped = days > 900 ? 900 : days;
    var factor = 1.0;
    for (var i = 0; i < capped; i++) {
      factor *= ClassifierThresholds.timeDecayPerDay;
    }
    _expense.scale(factor);
    _income.scale(factor);
  }

  _Bucket? _bucket(TransactionType type) {
    return switch (type) {
      TransactionType.expense => _expense,
      TransactionType.income => _income,
      TransactionType.investment || TransactionType.opening => null,
    };
  }

  static bool _trainable(TransactionEntity transaction) {
    if (transaction.type != TransactionType.income &&
        transaction.type != TransactionType.expense) {
      return false;
    }
    return transaction.category.trim().isNotEmpty &&
        transaction.description.trim().isNotEmpty &&
        transaction.value > 0;
  }

  static Map<String, Object?> _rowOf(TransactionEntity transaction) {
    return {
      'description': transaction.description,
      'amount': transaction.value,
      'type': transaction.type.index,
      'category': transaction.category.trim(),
      'dateMs': transaction.date.millisecondsSinceEpoch,
      'payment': transaction.paymentMethod?.index,
    };
  }

  static String _stamp(DateTime value) => value.toUtc().toIso8601String();

  static DateTime? _parseStamp(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc();
  }
}

class _Bucket {
  _Bucket();

  final docs = <String, double>{};
  final features = <String, Map<String, double>>{};
  final mass = <String, double>{};
  double totalDocs = 0;
  Set<String>? _vocabulary;

  bool get isEmpty => docs.isEmpty;

  Set<String> get vocabulary {
    final cached = _vocabulary;
    if (cached != null) return cached;
    final all = <String>{};
    for (final counts in features.values) {
      all.addAll(counts.keys);
    }
    return _vocabulary = all;
  }

  void add(String category, List<String> featureList, double weight) {
    docs[category] = (docs[category] ?? 0) + weight;
    totalDocs += weight;
    final counts = features.putIfAbsent(category, () => {});
    for (final feature in featureList) {
      counts[feature] = (counts[feature] ?? 0) + weight;
    }
    mass[category] = (mass[category] ?? 0) + weight * featureList.length;
    _vocabulary = null;
  }

  /// False quando a categoria não existia.
  bool remove(String category, List<String> featureList, double weight) {
    if (!docs.containsKey(category)) return false;
    docs[category] = (docs[category] ?? 0) - weight;
    totalDocs -= weight;
    if (totalDocs < 0) totalDocs = 0;

    final counts = features[category];
    if (counts != null) {
      for (final feature in featureList) {
        final next = (counts[feature] ?? 0) - weight;
        if (next <= 1e-9) {
          counts.remove(feature);
        } else {
          counts[feature] = next;
        }
      }
      if (counts.isEmpty) {
        mass.remove(category);
      } else {
        mass[category] = counts.values.fold(0.0, (sum, value) => sum + value);
      }
    }

    if ((docs[category] ?? 0) <= 1e-9 || counts == null || counts.isEmpty) {
      docs.remove(category);
      features.remove(category);
      mass.remove(category);
    }
    _vocabulary = null;
    return true;
  }

  void prune(String category, int maxFeatures) {
    final counts = features[category];
    if (counts == null || counts.length <= maxFeatures) return;
    final ranked = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    features[category] = Map<String, double>.fromEntries(
      ranked.take(maxFeatures),
    );
    mass[category] = features[category]!.values.fold(
      0.0,
      (sum, value) => sum + value,
    );
    _vocabulary = null;
  }

  void scale(double factor) {
    if (factor == 1 || docs.isEmpty) return;
    totalDocs *= factor;
    for (final name in docs.keys.toList()) {
      docs[name] = docs[name]! * factor;
    }
    for (final counts in features.values) {
      for (final feature in counts.keys.toList()) {
        counts[feature] = counts[feature]! * factor;
      }
    }
    for (final name in mass.keys.toList()) {
      mass[name] = mass[name]! * factor;
    }
  }

  List<Map<String, Object?>> toList() {
    final names = docs.keys.toList()..sort();
    return [
      for (final name in names)
        if (features[name] != null)
          {
            'categoria': name,
            'contagem': docs[name],
            'atributos': _sorted(features[name]!),
          },
    ];
  }

  factory _Bucket.fromList(Object? value) {
    final bucket = _Bucket();
    for (final item in _asList(value)) {
      if (item is! Map) continue;
      final map = item.map((key, val) => MapEntry(key.toString(), val));
      final name = map['categoria'] as String? ?? '';
      if (name.isEmpty) continue;
      final counts = _doubleMap(map['atributos']);
      if (counts.isEmpty) continue;
      bucket.docs[name] = (map['contagem'] as num?)?.toDouble() ?? 0;
      bucket.features[name] = counts;
      bucket.mass[name] = counts.values.fold(0.0, (sum, item) => sum + item);
      bucket.totalDocs += bucket.docs[name]!;
    }
    return bucket;
  }

  static Map<String, double> _sorted(Map<String, double> counts) {
    final keys = counts.keys.toList()..sort();
    return {for (final key in keys) key: counts[key]!};
  }
}

List<Object?> _asList(Object? value) {
  if (value is List) return value;
  if (value is Map) {
    final entries = value.entries.toList()
      ..sort((a, b) {
        final ai = int.tryParse(a.key.toString());
        final bi = int.tryParse(b.key.toString());
        if (ai != null && bi != null) return ai.compareTo(bi);
        return a.key.toString().compareTo(b.key.toString());
      });
    return [for (final entry in entries) entry.value];
  }
  return const [];
}

Map<String, double> _doubleMap(Object? value) {
  if (value is! Map) return {};
  final result = <String, double>{};
  for (final entry in value.entries) {
    final raw = entry.value;
    if (raw is! num) continue;
    if (raw <= 0) continue;
    result[entry.key.toString()] = raw.toDouble();
  }
  return result;
}
