import 'package:firebase_database/firebase_database.dart';

import '../../core/config/rtdb_helper.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../models/transaction_model.dart';

class TransactionRemoteDataSource {
  TransactionRemoteDataSource({FirebaseDatabase? database})
      : _database = database ?? RtdbHelper.database;

  final FirebaseDatabase _database;

  DatabaseReference _ref(String userId) =>
      _database.ref('users/$userId/transactions');

  Stream<List<TransactionEntity>> watchTransactions(String userId) {
    return _ref(userId).onValue.map((event) {
      final list = RtdbHelper.parseChildren(
        event.snapshot.value,
        (map, id) => TransactionModel.fromMap(map, id),
      );
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  Stream<List<TransactionEntity>> watchFiltered(
    String userId,
    TransactionFilter filter,
  ) {
    return watchTransactions(userId).map((list) => _applyFilter(list, filter));
  }

  Future<List<TransactionEntity>> getTransactions(String userId) async {
    final snapshot = await _ref(userId).get();
    final list = RtdbHelper.parseChildren(
      snapshot.value,
      (map, id) => TransactionModel.fromMap(map, id),
    );
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<TransactionEntity?> getTransaction(String userId, String id) async {
    final snapshot = await _ref(userId).child(id).get();
    if (!snapshot.exists) return null;
    return TransactionModel.fromMap(
      RtdbHelper.toStringKeyMap(snapshot.value),
      id,
    );
  }

  Future<void> createTransaction(TransactionEntity transaction) async {
    final data = TransactionModel.fromEntity(transaction).toMap();
    await _ref(transaction.userId).child(transaction.id).set(data);
  }

  Future<void> updateTransaction(TransactionEntity transaction) async {
    final data = TransactionModel.fromEntity(transaction).toMap();
    await _ref(transaction.userId).child(transaction.id).update(data);
  }

  Future<void> deleteTransaction(String userId, String id) async {
    await _ref(userId).child(id).remove();
  }

  List<TransactionEntity> _applyFilter(
    List<TransactionEntity> list,
    TransactionFilter filter,
  ) {
    return list.where((t) {
      if (filter.type != null && t.type != filter.type) return false;
      if (filter.category != null && t.category != filter.category) return false;
      if (filter.account != null && t.account != filter.account) return false;
      if (filter.month != null && t.date.month != filter.month) return false;
      if (filter.year != null && t.date.year != filter.year) return false;
      if (filter.startDate != null && t.date.isBefore(filter.startDate!)) {
        return false;
      }
      if (filter.endDate != null && t.date.isAfter(filter.endDate!)) return false;
      if (filter.minValue != null && t.value < filter.minValue!) return false;
      if (filter.maxValue != null && t.value > filter.maxValue!) return false;
      if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
        final q = filter.searchQuery!.toLowerCase();
        final matches = t.description.toLowerCase().contains(q) ||
            t.category.toLowerCase().contains(q) ||
            t.value.toString().contains(q);
        if (!matches) return false;
      }
      return true;
    }).toList();
  }
}
