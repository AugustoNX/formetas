import '../../domain/entities/investment_entity.dart';
import '../../domain/repositories/investment_repository.dart';
import '../datasources/investment_remote_datasource.dart';

class InvestmentRepositoryImpl implements InvestmentRepository {
  InvestmentRepositoryImpl(this._dataSource);

  final InvestmentRemoteDataSource _dataSource;

  @override
  Stream<List<InvestmentEntity>> watchInvestments(String userId) =>
      _dataSource.watchInvestments(userId);

  @override
  Future<List<InvestmentEntity>> getInvestments(String userId) =>
      _dataSource.getInvestments(userId);

  @override
  Future<void> createInvestment(InvestmentEntity investment) =>
      _dataSource.createInvestment(investment);

  @override
  Future<void> updateInvestment(InvestmentEntity investment) =>
      _dataSource.updateInvestment(investment);

  @override
  Future<void> deleteInvestment(String userId, String id) =>
      _dataSource.deleteInvestment(userId, id);
}
