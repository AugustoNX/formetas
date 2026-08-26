import '../entities/reserve_entity.dart';
import '../entities/reserve_movement_entity.dart';

abstract class ReserveRepository {
  Stream<List<ReserveWithMovements>> watchReservesWithMovements(String userId);
  Future<List<ReserveWithMovements>> getReservesWithMovements(String userId);
  Stream<List<ReserveEntity>> watchReserves(String userId);
  Future<List<ReserveEntity>> getReserves(String userId);
  Stream<List<ReserveMovementEntity>> watchMovements(
    String userId,
    String reserveId,
  );
  Future<void> createReserve(ReserveEntity reserve);
  Future<void> updateReserve(ReserveEntity reserve);
  Future<void> deleteReserve(String userId, String id);
  Future<void> createMovement(ReserveMovementEntity movement);
  Future<void> deleteMovement(String userId, String reserveId, String movementId);
}
