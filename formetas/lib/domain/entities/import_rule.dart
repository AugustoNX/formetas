import 'package:equatable/equatable.dart';

import 'statement_import.dart';
import 'transaction_entity.dart';

class ImportRule extends Equatable {
  const ImportRule({
    required this.text,
    required this.role,
    required this.category,
    required this.type,
  });

  final String text;
  final StatementRole role;
  final String category;
  final TransactionType type;

  @override
  List<Object?> get props => [text, role, category, type];
}
