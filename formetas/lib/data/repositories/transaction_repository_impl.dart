import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/transaction_remote_datasource.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  TransactionRepositoryImpl(this._dataSource);

  final TransactionRemoteDataSource _dataSource;

  @override
  Stream<List<TransactionEntity>> watchTransactions(String userId) =>
      _dataSource.watchTransactions(userId);

  @override
  Stream<List<TransactionEntity>> watchFiltered(
    String userId,
    TransactionFilter filter,
  ) =>
      _dataSource.watchFiltered(userId, filter);

  @override
  Future<List<TransactionEntity>> getTransactions(String userId) =>
      _dataSource.getTransactions(userId);

  @override
  Future<TransactionEntity?> getTransaction(String userId, String id) =>
      _dataSource.getTransaction(userId, id);

  @override
  Future<void> createTransaction(TransactionEntity transaction) =>
      _dataSource.createTransaction(transaction);

  @override
  Future<void> updateTransaction(TransactionEntity transaction) =>
      _dataSource.updateTransaction(transaction);

  @override
  Future<void> deleteTransaction(String userId, String id) =>
      _dataSource.deleteTransaction(userId, id);
}
