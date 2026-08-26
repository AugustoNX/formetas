import 'package:firebase_database/firebase_database.dart';

import '../../core/config/rtdb_helper.dart';
import '../../domain/entities/reserve_entity.dart';
import '../../domain/entities/reserve_movement_entity.dart';
import '../models/reserve_model.dart';
import '../models/reserve_movement_model.dart';

class ReserveRemoteDataSource {
  ReserveRemoteDataSource({FirebaseDatabase? database})
      : _database = database ?? RtdbHelper.database;

  final FirebaseDatabase _database;

  DatabaseReference _ref(String userId) =>
      _database.ref('users/$userId/reserves');

  DatabaseReference _movementsRef(String userId, String reserveId) =>
      _ref(userId).child(reserveId).child('movimentacoes');

  Stream<List<ReserveWithMovements>> watchReservesWithMovements(String userId) {
    return _ref(userId).onValue.map((event) {
      return RtdbHelper.parseChildren(
        event.snapshot.value,
        (map, id) => _parseReserveWithMovements(map, id),
      );
    });
  }

  Future<List<ReserveWithMovements>> getReservesWithMovements(String userId) async {
    final snapshot = await _ref(userId).get();
    return RtdbHelper.parseChildren(
      snapshot.value,
      (map, id) => _parseReserveWithMovements(map, id),
    );
  }

  Stream<List<ReserveEntity>> watchReserves(String userId) {
    return watchReservesWithMovements(userId)
        .map((list) => list.map((item) => item.reserve).toList());
  }

  Future<List<ReserveEntity>> getReserves(String userId) async {
    final list = await getReservesWithMovements(userId);
    return list.map((item) => item.reserve).toList();
  }

  Stream<List<ReserveMovementEntity>> watchMovements(
    String userId,
    String reserveId,
  ) {
    return _movementsRef(userId, reserveId).onValue.map((event) {
      final movements = RtdbHelper.parseChildren(
        event.snapshot.value,
        (map, id) => ReserveMovementModel.fromMap(map, id),
      );
      movements.sort((a, b) => b.date.compareTo(a.date));
      return movements;
    });
  }

  Future<void> createReserve(ReserveEntity reserve) async {
    final data = ReserveModel.fromEntity(reserve).toMap();
    await _ref(reserve.userId).child(reserve.id).update(data);
  }

  Future<void> updateReserve(ReserveEntity reserve) async {
    final data = ReserveModel.fromEntity(reserve).toMap();
    await _ref(reserve.userId).child(reserve.id).update(data);
  }

  Future<void> deleteReserve(String userId, String id) async {
    await _ref(userId).child(id).remove();
  }

  Future<void> createMovement(ReserveMovementEntity movement) async {
    final data = ReserveMovementModel.fromEntity(movement).toMap();
    await _movementsRef(movement.userId, movement.reserveId)
        .child(movement.id)
        .set(data);
  }

  Future<void> deleteMovement(
    String userId,
    String reserveId,
    String movementId,
  ) async {
    await _movementsRef(userId, reserveId).child(movementId).remove();
  }

  ReserveWithMovements _parseReserveWithMovements(
    Map<String, dynamic> map,
    String id,
  ) {
    final data = Map<String, dynamic>.from(map);
    final movementsRaw = data.remove('movimentacoes');
    final reserve = ReserveModel.fromMap(data, id);

    final movements = <ReserveMovementEntity>[];
    if (movementsRaw is Map) {
      movementsRaw.forEach((key, value) {
        if (value is Map) {
          movements.add(
            ReserveMovementModel.fromMap(
              Map<String, dynamic>.from(value),
              key.toString(),
            ),
          );
        }
      });
    }

    movements.sort((a, b) => b.date.compareTo(a.date));
    return ReserveWithMovements(reserve: reserve, movements: movements);
  }
}
