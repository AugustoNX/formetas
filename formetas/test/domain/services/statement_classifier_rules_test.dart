import 'package:flutter_test/flutter_test.dart';
import 'package:formetas/domain/entities/import_rule.dart';
import 'package:formetas/domain/entities/statement_import.dart';
import 'package:formetas/domain/entities/transaction_entity.dart';
import 'package:formetas/domain/services/statement_classifier.dart';

void main() {
  test('regra antiga (texto exato) continua valendo e casa com ruído novo', () {
    final rule = ImportRule(
      text: StatementClassifier.normalize('Compra no débito - PADARIA PÃO QUENTE 05/03'),
      role: StatementRole.transaction,
      category: 'Alimentação',
      type: TransactionType.expense,
    );
    final entries = [
      StatementEntry(
        line: 2,
        date: DateTime(2026, 4, 7),
        description: 'Compra no débito - Padaria Pao Quente 07/04',
        amount: 12.5,
        type: TransactionType.expense,
      ),
    ];
    final result = StatementClassifier.classify(entries, rules: [rule]);
    expect(result.single.category, 'Alimentação');
  });
}
