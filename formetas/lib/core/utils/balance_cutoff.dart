import '../../domain/entities/transaction_entity.dart';

/// A data em que a pessoa disse quanto tinha na conta.
///
/// Lançamento anterior a esse dia fica só no histórico. A partir dele, o valor
/// entra no saldo. Se a data não foi salva nas configurações, vale o dia do
/// lançamento de abertura, quando existir.
abstract final class BalanceCutoff {
  static DateTime day(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool counts(DateTime date, DateTime? from) {
    if (from == null) return true;
    return !day(date).isBefore(day(from));
  }

  static DateTime? resolve({
    DateTime? saved,
    Iterable<TransactionEntity> transactions = const [],
  }) {
    if (saved != null) return day(saved);
    DateTime? opening;
    for (final transaction in transactions) {
      if (transaction.type != TransactionType.opening) continue;
      final date = day(transaction.date);
      if (opening == null || date.isBefore(opening)) opening = date;
    }
    return opening;
  }
}
