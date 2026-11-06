import 'package:flutter_test/flutter_test.dart';
import 'package:formetas/data/models/ant_brain_model.dart';
import 'package:formetas/domain/entities/ant_brain.dart';
import 'package:formetas/domain/entities/transaction_entity.dart';
import 'package:formetas/domain/services/ml/category_classifier.dart';

void main() {
  test('o mapa do RTDB volta idêntico, mesmo quando a lista vira mapa', () {
    final model = CategoryClassifier();
    final now = DateTime.utc(2026, 4, 2);
    model.train(
      const ['w:ifood', 'b:compra_ifood', 'v:30-100'],
      'Alimentação',
      type: TransactionType.expense,
      now: now,
    );
    model.train(
      const ['w:salario'],
      'Salário',
      type: TransactionType.income,
      weight: 3,
      now: now,
    );
    final snapshot = AntBrainSnapshot(
      model: model,
      history: [
        ImportStat(
          at: now,
          total: 10,
          accepted: 7,
          corrected: 2,
          regra: 3,
          recorrente: 1,
          aprendido: 4,
          heuristica: 1,
          semSugestao: 1,
        ),
      ],
    );

    final stored = AntBrainModel.toMap(snapshot);
    final restored = AntBrainModel.fromValue(_listsAsMaps(stored));

    expect(restored.model.toMap(), model.toMap());
    expect(restored.history.single.accepted, 7);
    expect(restored.history.single.corrected, 2);
    expect(restored.history.single.aprendido, 4);
    expect(restored.history.single.at, now);
  });
}

Object? _listsAsMaps(Object? node) {
  if (node is List) {
    return {for (var i = 0; i < node.length; i++) '$i': _listsAsMaps(node[i])};
  }
  if (node is Map) {
    return {
      for (final entry in node.entries)
        entry.key.toString(): _listsAsMaps(entry.value),
    };
  }
  return node;
}
