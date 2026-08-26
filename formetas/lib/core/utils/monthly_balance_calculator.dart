import '../../domain/entities/transaction_entity.dart';
import '../../domain/entities/transfer_entity.dart';
import 'date_utils.dart';

class MonthlySummary {
  const MonthlySummary({
    required this.month,
    required this.openingBalance,
    required this.income,
    required this.expense,
    required this.investment,
    required this.closingBalance,
    required this.savings,
  });

  final DateTime month;
  final double openingBalance;
  final double income;
  final double expense;
  final double investment;
  final double closingBalance;
  final double savings;
}

abstract final class MonthlyBalanceCalculator {
  static List<MonthlySummary> compute({
    required List<TransactionEntity> transactions,
    required DateTime fromMonth,
    required DateTime toMonth,
    double initialBalance = 0,
    List<TransferEntity> transfers = const [],
  }) {
    final summaries = <MonthlySummary>[];
    var runningBalance = initialBalance;
    var current = AppDateUtils.startOfMonth(fromMonth);
    final end = AppDateUtils.startOfMonth(toMonth);

    while (!current.isAfter(end)) {
      final monthStart = AppDateUtils.startOfMonth(current);
      final monthEnd = AppDateUtils.endOfMonth(current);

      final monthTx = transactions.where((t) {
        return !t.date.isBefore(monthStart) && !t.date.isAfter(monthEnd);
      });

      final income = monthTx
          .where((t) => t.type == TransactionType.income)
          .fold(0.0, (s, t) => s + t.value);

      final expense = monthTx
          .where((t) => t.type == TransactionType.expense)
          .fold(0.0, (s, t) => s + t.value);

      final investment = monthTx
          .where((t) => t.type == TransactionType.investment)
          .fold(0.0, (s, t) => s + t.value);

      final monthTransfers = transfers.where((t) {
        return !t.date.isBefore(monthStart) && !t.date.isAfter(monthEnd);
      });

      final transferIn = monthTransfers
          .where((t) => t.toType == WalletType.balance)
          .fold(0.0, (s, t) => s + t.amount);

      final transferOut = monthTransfers
          .where((t) => t.fromType == WalletType.balance)
          .fold(0.0, (s, t) => s + t.amount);

      final opening = runningBalance;
      final closing =
          opening + income - expense - investment + transferIn - transferOut;
      final savings = income - expense;

      summaries.add(MonthlySummary(
        month: current,
        openingBalance: opening,
        income: income,
        expense: expense,
        investment: investment,
        closingBalance: closing,
        savings: savings,
      ));

      runningBalance = closing;
      current = DateTime(current.year, current.month + 1);
    }

    return summaries;
  }

  static MonthlySummary? forMonth({
    required List<TransactionEntity> transactions,
    required DateTime month,
    required double openingBalance,
  }) {
    final result = compute(
      transactions: transactions,
      fromMonth: month,
      toMonth: month,
      initialBalance: openingBalance,
    );
    return result.isEmpty ? null : result.first;
  }
}
