import '../../domain/entities/reserve_movement_entity.dart';

class ReserveMovementModel extends ReserveMovementEntity {
  const ReserveMovementModel({
    required super.id,
    required super.reserveId,
    required super.userId,
    required super.type,
    required super.amount,
    required super.date,
    required super.createdAt,
    super.description,
  });

  factory ReserveMovementModel.fromMap(Map<String, dynamic> map, String id) {
    return ReserveMovementModel(
      id: id,
      reserveId: map['reserveId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      type: _parseType(map['tipo'] ?? map['type']),
      amount: (map['valor'] ?? map['amount'] ?? 0).toDouble(),
      date: _parseDate(map['data'] ?? map['date']),
      description: map['descricao'] as String? ?? map['description'] as String?,
      createdAt: _parseDate(map['criadoEm'] ?? map['createdAt']),
    );
  }

  factory ReserveMovementModel.fromEntity(ReserveMovementEntity entity) {
    return ReserveMovementModel(
      id: entity.id,
      reserveId: entity.reserveId,
      userId: entity.userId,
      type: entity.type,
      amount: entity.amount,
      date: entity.date,
      description: entity.description,
      createdAt: entity.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reserveId': reserveId,
      'userId': userId,
      'tipo': type == ReserveMovementType.deposit ? 'aporte' : 'resgate',
      'valor': amount,
      'data': date.toIso8601String(),
      'descricao': description,
      'criadoEm': createdAt.toIso8601String(),
    };
  }

  static ReserveMovementType _parseType(dynamic value) {
    final str = value?.toString() ?? 'aporte';
    if (str == 'resgate' || str == 'withdrawal') {
      return ReserveMovementType.withdrawal;
    }
    return ReserveMovementType.deposit;
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }
}
