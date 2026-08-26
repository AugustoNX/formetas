import 'package:firebase_database/firebase_database.dart';

import '../../core/config/rtdb_helper.dart';
import '../../domain/entities/investment_entity.dart';
import '../models/investment_model.dart';

class InvestmentRemoteDataSource {
  InvestmentRemoteDataSource({FirebaseDatabase? database})
      : _database = database ?? RtdbHelper.database;

  final FirebaseDatabase _database;

  DatabaseReference _ref(String userId) =>
      _database.ref('users/$userId/investments');

  Stream<List<InvestmentEntity>> watchInvestments(String userId) {
    return _ref(userId).onValue.map((event) {
      return RtdbHelper.parseChildren(
        event.snapshot.value,
        (map, id) => InvestmentModel.fromMap(map, id),
      );
    });
  }

  Future<List<InvestmentEntity>> getInvestments(String userId) async {
    final snapshot = await _ref(userId).get();
    return RtdbHelper.parseChildren(
      snapshot.value,
      (map, id) => InvestmentModel.fromMap(map, id),
    );
  }

  Future<void> createInvestment(InvestmentEntity investment) async {
    final data = InvestmentModel.fromEntity(investment).toMap();
    await _ref(investment.userId).child(investment.id).set(data);
  }

  Future<void> updateInvestment(InvestmentEntity investment) async {
    final data = InvestmentModel.fromEntity(investment).toMap();
    await _ref(investment.userId).child(investment.id).update(data);
  }

  Future<void> deleteInvestment(String userId, String id) async {
    await _ref(userId).child(id).remove();
  }
}
