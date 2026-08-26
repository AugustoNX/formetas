import 'package:equatable/equatable.dart';

import 'transaction_entity.dart';

class DashboardStats extends Equatable {
  const DashboardStats({
    required this.totalBalance,
    required this.monthlyIncome,
    required this.monthlyExpense,
    required this.monthlySavings,
    required this.availableBalance,
    required this.totalInvestments,
    required this.totalReserves,
    required this.netWorth,
    required this.investmentYield,
    required this.reserveYield,
    required this.recentTransactions,
    required this.expensesByCategory,
    required this.incomeByCategory,
    required this.monthlyTrend,
    required this.openingBalance,
  });

  final double totalBalance;
  final double monthlyIncome;
  final double monthlyExpense;
  final double monthlySavings;
  final double availableBalance;
  final double totalInvestments;
  final double totalReserves;
  final double netWorth;
  final double investmentYield;
  final double reserveYield;
  final double openingBalance;
  final List<TransactionEntity> recentTransactions;
  final Map<String, double> expensesByCategory;
  final Map<String, double> incomeByCategory;
  final List<MonthlyTrendPoint> monthlyTrend;

  @override
  List<Object?> get props => [totalBalance, monthlyIncome, monthlyExpense];
}

class MonthlyTrendPoint extends Equatable {
  const MonthlyTrendPoint({
    required this.month,
    required this.income,
    required this.expense,
    required this.balance,
  });

  final DateTime month;
  final double income;
  final double expense;
  final double balance;

  @override
  List<Object?> get props => [month, income, expense, balance];
}

class StatisticsSummary extends Equatable {
  const StatisticsSummary({
    required this.largestExpense,
    required this.largestIncome,
    required this.averageMonthlyExpense,
    required this.averageMonthlySavings,
    required this.topExpenseCategory,
    required this.topIncomeCategory,
    required this.totalInvested,
    required this.totalYield,
    required this.totalReserves,
    required this.reserveYield,
    required this.netWorth,
    required this.currentBalance,
  });

  final TransactionEntity? largestExpense;
  final TransactionEntity? largestIncome;
  final double averageMonthlyExpense;
  final double averageMonthlySavings;
  final String topExpenseCategory;
  final String topIncomeCategory;
  final double totalInvested;
  final double totalYield;
  final double totalReserves;
  final double reserveYield;
  final double netWorth;
  final double currentBalance;

  @override
  List<Object?> get props => [netWorth, currentBalance];
}
