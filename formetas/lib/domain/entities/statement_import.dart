import 'package:equatable/equatable.dart';

import 'transaction_entity.dart';

class StatementEntry extends Equatable {
  const StatementEntry({
    required this.line,
    required this.date,
    required this.amount,
    required this.type,
    required this.description,
    this.category = 'Outros',
    this.sourceId,
    this.included = true,
    this.duplicate = false,
  });

  final int line;
  final DateTime date;
  final double amount;
  final TransactionType type;
  final String description;
  final String category;
  final String? sourceId;
  final bool included;
  final bool duplicate;

  StatementEntry copyWith({
    DateTime? date,
    double? amount,
    TransactionType? type,
    String? description,
    String? category,
    bool? included,
    bool? duplicate,
  }) {
    return StatementEntry(
      line: line,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      description: description ?? this.description,
      category: category ?? this.category,
      sourceId: sourceId,
      included: included ?? this.included,
      duplicate: duplicate ?? this.duplicate,
    );
  }

  @override
  List<Object?> get props => [
        line,
        date,
        amount,
        type,
        description,
        category,
        sourceId,
        included,
        duplicate,
      ];
}

class StatementRejection extends Equatable {
  const StatementRejection({
    required this.line,
    required this.reason,
    required this.raw,
  });

  final int line;
  final String reason;
  final String raw;

  @override
  List<Object?> get props => [line, reason, raw];
}

class StatementParseResult extends Equatable {
  const StatementParseResult({
    this.entries = const [],
    this.rejected = const [],
    this.message,
    this.dateColumn,
    this.descriptionColumn,
    this.amountColumn,
  });

  final List<StatementEntry> entries;
  final List<StatementRejection> rejected;
  final String? message;
  final String? dateColumn;
  final String? descriptionColumn;
  final String? amountColumn;

  bool get failed => message != null && entries.isEmpty;

  @override
  List<Object?> get props => [
        entries,
        rejected,
        message,
        dateColumn,
        descriptionColumn,
        amountColumn,
      ];
}
