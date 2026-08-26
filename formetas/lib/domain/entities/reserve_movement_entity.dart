import 'package:equatable/equatable.dart';

import 'reserve_entity.dart';

enum ReserveMovementType { deposit, withdrawal }

class ReserveMovementEntity extends Equatable {
  const ReserveMovementEntity({
    required this.id,
    required this.reserveId,
    required this.userId,
    required this.type,
    required this.amount,
    required this.date,
    required this.createdAt,
    this.description,
  });

  final String id;
  final String reserveId;
  final String userId;
  final ReserveMovementType type;
  final double amount;
  final DateTime date;
  final String? description;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, reserveId, type, amount, date];
}

class ReserveWithMovements extends Equatable {
  const ReserveWithMovements({
    required this.reserve,
    required this.movements,
  });

  final ReserveEntity reserve;
  final List<ReserveMovementEntity> movements;

  @override
  List<Object?> get props => [reserve, movements];
}
