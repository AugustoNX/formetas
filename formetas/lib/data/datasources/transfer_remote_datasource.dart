import 'package:firebase_database/firebase_database.dart';

import '../../core/config/rtdb_helper.dart';
import '../../domain/entities/transfer_entity.dart';
import '../models/transfer_model.dart';

class TransferRemoteDataSource {
  TransferRemoteDataSource({FirebaseDatabase? database})
      : _database = database ?? RtdbHelper.database;

  final FirebaseDatabase _database;

  DatabaseReference _ref(String userId) =>
      _database.ref('users/$userId/transfers');

  Stream<List<TransferEntity>> watchTransfers(String userId) {
    return _ref(userId).onValue.map((event) {
      final list = RtdbHelper.parseChildren(
        event.snapshot.value,
        (map, id) => TransferModel.fromMap(map, id),
      );
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  Future<List<TransferEntity>> getTransfers(String userId) async {
    final snapshot = await _ref(userId).get();
    final list = RtdbHelper.parseChildren(
      snapshot.value,
      (map, id) => TransferModel.fromMap(map, id),
    );
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> createTransfer(TransferEntity transfer) async {
    final data = TransferModel.fromEntity(transfer).toMap();
    await _ref(transfer.userId).child(transfer.id).set(data);
  }

  Future<void> deleteTransfer(String userId, String id) async {
    await _ref(userId).child(id).remove();
  }
}
