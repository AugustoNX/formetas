import 'package:firebase_database/firebase_database.dart';

import '../../core/config/rtdb_helper.dart';
import '../../domain/entities/import_rule.dart';
import '../../domain/entities/statement_import.dart';
import '../../domain/entities/transaction_entity.dart';

class ImportRuleRemoteDataSource {
  ImportRuleRemoteDataSource({FirebaseDatabase? database})
      : _database = database ?? RtdbHelper.database;

  final FirebaseDatabase _database;

  DatabaseReference _ref(String userId) =>
      _database.ref('users/$userId/regrasImportacao');

  Future<List<ImportRule>> getRules(String userId) async {
    final snapshot = await _ref(userId).get();
    final map = RtdbHelper.toStringKeyMap(snapshot.value);
    return [
      for (final entry in map.entries)
        if (entry.value is Map)
          _fromMap(Map<String, dynamic>.from(entry.value as Map)),
    ];
  }

  Future<void> saveRules(String userId, List<ImportRule> rules) async {
    if (rules.isEmpty) return;
    await _ref(userId).update({
      for (final rule in rules) _id(rule.text): _toMap(rule),
    });
  }

  Map<String, Object> _toMap(ImportRule rule) {
    return {
      'texto': rule.text,
      'papel': rule.role.name,
      'categoria': rule.category,
      'tipo': rule.type.name,
    };
  }

  ImportRule _fromMap(Map<String, dynamic> map) {
    return ImportRule(
      text: map['texto'] as String? ?? '',
      role: StatementRole.values.firstWhere(
        (role) => role.name == map['papel'],
        orElse: () => StatementRole.transaction,
      ),
      category: map['categoria'] as String? ?? 'Outros',
      type: TransactionType.values.firstWhere(
        (type) => type.name == map['tipo'],
        orElse: () => TransactionType.expense,
      ),
    );
  }

  String _id(String text) {
    final safe = text.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final trimmed = safe.replaceAll(RegExp(r'^_|_$'), '');
    if (trimmed.isEmpty) return 'regra';
    return trimmed.length <= 180 ? trimmed : trimmed.substring(0, 180);
  }
}
