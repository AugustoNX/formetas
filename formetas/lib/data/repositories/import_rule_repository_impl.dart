import '../../domain/entities/import_rule.dart';
import '../../domain/repositories/import_rule_repository.dart';
import '../datasources/import_rule_remote_datasource.dart';

class ImportRuleRepositoryImpl implements ImportRuleRepository {
  ImportRuleRepositoryImpl(this._dataSource);

  final ImportRuleRemoteDataSource _dataSource;

  @override
  Future<List<ImportRule>> getRules(String userId) =>
      _dataSource.getRules(userId);

  @override
  Future<void> saveRules(String userId, List<ImportRule> rules) =>
      _dataSource.saveRules(userId, rules);
}
