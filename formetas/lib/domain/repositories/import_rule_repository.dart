import '../entities/import_rule.dart';

abstract class ImportRuleRepository {
  Future<List<ImportRule>> getRules(String userId);
  Future<void> saveRules(String userId, List<ImportRule> rules);
}
