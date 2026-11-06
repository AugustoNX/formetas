import '../../domain/entities/ant_brain.dart';
import '../../domain/services/ml/category_classifier.dart';

/// Mapa único de `users/{uid}/antBrain`. Listas podem voltar do RTDB como
/// mapas `{"0": ...}`; a leitura aceita os dois formatos.
abstract final class AntBrainModel {
  static Map<String, Object?> toMap(AntBrainSnapshot snapshot) {
    return {
      'modelo': snapshot.model.toMap(),
      'stats': [for (final stat in snapshot.history) _statToMap(stat)],
      'zerado': snapshot.cleared,
    };
  }

  static AntBrainSnapshot fromValue(Object? value) {
    final root = _stringKeyMap(value);
    final model = root['modelo'];
    return AntBrainSnapshot(
      model: CategoryClassifier.fromMap(
        model is Map ? _stringKeyMap(model) : const {},
      ),
      history: [
        for (final item in _asList(root['stats']))
          if (item is Map) _statFromMap(_stringKeyMap(item)),
      ],
      cleared: root['zerado'] == true,
    );
  }

  static Map<String, Object?> _statToMap(ImportStat stat) {
    return {
      'em': stat.at.toUtc().toIso8601String(),
      'total': stat.total,
      'aceitas': stat.accepted,
      'corrigidas': stat.corrected,
      'regra': stat.regra,
      'recorrente': stat.recorrente,
      'aprendido': stat.aprendido,
      'heuristica': stat.heuristica,
      'semSugestao': stat.semSugestao,
    };
  }

  static ImportStat _statFromMap(Map<String, Object?> map) {
    return ImportStat(
      at:
          DateTime.tryParse(map['em'] as String? ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      total: _int(map['total']),
      accepted: _int(map['aceitas']),
      corrected: _int(map['corrigidas']),
      regra: _int(map['regra']),
      recorrente: _int(map['recorrente']),
      aprendido: _int(map['aprendido']),
      heuristica: _int(map['heuristica']),
      semSugestao: _int(map['semSugestao']),
    );
  }

  static int _int(Object? value) => value is num ? value.toInt() : 0;

  static Map<String, Object?> _stringKeyMap(Object? value) {
    if (value is! Map) return {};
    return value.map((key, val) => MapEntry(key.toString(), val));
  }

  static List<Object?> _asList(Object? value) {
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
}
