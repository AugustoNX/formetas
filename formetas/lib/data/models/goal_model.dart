import '../../domain/entities/goal_entity.dart';

class GoalModel extends GoalEntity {
  const GoalModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.targetValue,
    required super.currentValue,
    required super.targetDate,
    required super.createdAt,
    super.reserveId,
  });

  factory GoalModel.fromMap(Map<String, dynamic> map, String id) {
    return GoalModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      name: map['nome'] as String? ?? map['name'] as String? ?? '',
      targetValue: (map['valorMeta'] ?? map['targetValue'] ?? 0).toDouble(),
      currentValue: (map['valorAtual'] ?? map['currentValue'] ?? 0).toDouble(),
      targetDate: _parseDate(map['dataObjetivo'] ?? map['targetDate']),
      createdAt: _parseDate(map['criadoEm'] ?? map['createdAt']),
      reserveId: map['caixinhaId'] as String? ?? map['reserveId'] as String?,
    );
  }

  factory GoalModel.fromEntity(GoalEntity entity) {
    return GoalModel(
      id: entity.id,
      userId: entity.userId,
      name: entity.name,
      targetValue: entity.targetValue,
      currentValue: entity.currentValue,
      targetDate: entity.targetDate,
      createdAt: entity.createdAt,
      reserveId: entity.reserveId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'nome': name,
      'valorMeta': targetValue,
      'valorAtual': currentValue,
      'dataObjetivo': targetDate.toIso8601String(),
      'caixinhaId': reserveId,
      'criadoEm': createdAt.toIso8601String(),
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }
}
