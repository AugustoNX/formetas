import '../entities/investment_entity.dart';

abstract class InvestmentRepository {
  Stream<List<InvestmentEntity>> watchInvestments(String userId);
  Future<List<InvestmentEntity>> getInvestments(String userId);
  Future<void> createInvestment(InvestmentEntity investment);
  Future<void> updateInvestment(InvestmentEntity investment);
  Future<void> deleteInvestment(String userId, String id);
}
