import '../entities/statement_import.dart';
import '../entities/transaction_entity.dart';

abstract final class StatementImporter {
  static List<TransactionEntity> build({
    required String userId,
    required List<StatementEntry> entries,
    required String Function() nextId,
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime.now();
    return [
      for (final entry in entries)
        if (entry.included &&
            entry.amount > 0 &&
            entry.description.trim().isNotEmpty &&
            (entry.type == TransactionType.income ||
                entry.type == TransactionType.expense))
          TransactionEntity(
            id: nextId(),
            userId: userId,
            type: entry.type,
            category: entry.category.trim().isEmpty ? 'Outros' : entry.category.trim(),
            value: entry.amount,
            description: entry.description.trim(),
            date: DateTime(entry.date.year, entry.date.month, entry.date.day),
            sourceId: entry.sourceId?.trim().isEmpty ?? true
                ? null
                : entry.sourceId!.trim(),
            createdAt: now,
          ),
    ];
  }
}
