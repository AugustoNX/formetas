import '../entities/transaction_entity.dart';

class TransactionFilter {
  const TransactionFilter({
    this.type,
    this.category,
    this.account,
    this.searchQuery,
    this.minValue,
    this.maxValue,
    this.startDate,
    this.endDate,
    this.month,
    this.year,
  });

  final TransactionType? type;
  final String? category;
  final String? account;
  final String? searchQuery;
  final double? minValue;
  final double? maxValue;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? month;
  final int? year;
}

abstract class TransactionRepository {
  Stream<List<TransactionEntity>> watchTransactions(String userId);
  Stream<List<TransactionEntity>> watchFiltered(
    String userId,
    TransactionFilter filter,
  );
  Future<List<TransactionEntity>> getTransactions(String userId);
  Future<TransactionEntity?> getTransaction(String userId, String id);
  Future<void> createTransaction(TransactionEntity transaction);
  Future<void> updateTransaction(TransactionEntity transaction);
  Future<void> deleteTransaction(String userId, String id);
}
