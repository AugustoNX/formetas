import '../../domain/entities/reserve_entity.dart';
import '../../domain/entities/reserve_movement_entity.dart';
import '../../domain/repositories/reserve_repository.dart';
import '../datasources/reserve_remote_datasource.dart';

class ReserveRepositoryImpl implements ReserveRepository {
  ReserveRepositoryImpl(this._dataSource);

  final ReserveRemoteDataSource _dataSource;

  @override
  Stream<List<ReserveWithMovements>> watchReservesWithMovements(String userId) =>
      _dataSource.watchReservesWithMovements(userId);

  @override
  Future<List<ReserveWithMovements>> getReservesWithMovements(String userId) =>
      _dataSource.getReservesWithMovements(userId);

  @override
  Stream<List<ReserveEntity>> watchReserves(String userId) =>
      _dataSource.watchReserves(userId);

  @override
  Future<List<ReserveEntity>> getReserves(String userId) =>
      _dataSource.getReserves(userId);

  @override
  Stream<List<ReserveMovementEntity>> watchMovements(
    String userId,
    String reserveId,
  ) =>
      _dataSource.watchMovements(userId, reserveId);

  @override
  Future<void> createReserve(ReserveEntity reserve) =>
      _dataSource.createReserve(reserve);

  @override
  Future<void> updateReserve(ReserveEntity reserve) =>
      _dataSource.updateReserve(reserve);

  @override
  Future<void> deleteReserve(String userId, String id) =>
      _dataSource.deleteReserve(userId, id);

  @override
  Future<void> createMovement(ReserveMovementEntity movement) =>
      _dataSource.createMovement(movement);

  @override
  Future<void> deleteMovement(
    String userId,
    String reserveId,
    String movementId,
  ) =>
      _dataSource.deleteMovement(userId, reserveId, movementId);
}
