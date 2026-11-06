import '../../domain/entities/control_trail.dart';

/// Mapeamento RTDB de [ControlTrail] (chaves em português, como no restante do app).
abstract final class ControlTrailModel {
  static ControlTrail fromMap(Map<String, dynamic> map, String id) {
    final targets = map['metasSemanais'];
    return ControlTrail(
      id: id,
      kind: _enum(TrailKind.values, map['tipo'], TrailKind.category),
      title: map['titulo'] as String? ?? '',
      category: map['categoria'] as String?,
      smallPurchaseLimit: (map['limiteCompraPequena'] as num? ?? 30).toDouble(),
      startDate: _date(map['inicio']),
      weeklyBaseline: (map['baseSemanal'] as num? ?? 0).toDouble(),
      weeklyTargets: targets is List
          ? [for (final t in targets) (t as num? ?? 0).toDouble()]
          : targets is Map // RTDB pode devolver listas como mapas {"0": ...}
              ? ([...targets.entries]..sort((a, b) => int.parse('${a.key}').compareTo(int.parse('${b.key}'))))
                  .map((e) => (e.value as num? ?? 0).toDouble())
                  .toList()
              : const [],
      status: _enum(TrailStatus.values, map['status'], TrailStatus.active),
      insightId: map['insightId'] as String?,
      createdAt: _date(map['criadoEm']),
    );
  }

  static Map<String, dynamic> toMap(ControlTrail t) => {
        'tipo': t.kind.name,
        'titulo': t.title,
        'categoria': t.category,
        'limiteCompraPequena': t.smallPurchaseLimit,
        'inicio': t.startDate.toIso8601String(),
        'baseSemanal': t.weeklyBaseline,
        'metasSemanais': t.weeklyTargets,
        'status': t.status.name,
        'insightId': t.insightId,
        'criadoEm': t.createdAt.toIso8601String(),
      };

  static T _enum<T extends Enum>(List<T> values, Object? raw, T fallback) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return fallback;
  }

  static DateTime _date(Object? raw) =>
      raw is String ? DateTime.tryParse(raw) ?? DateTime.now() : DateTime.now();
}
