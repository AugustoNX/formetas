import '../../core/utils/monthly_balance_calculator.dart';
import '../../core/utils/patrimony_calculator.dart';
import '../../domain/entities/dashboard_entity.dart';
import '../../domain/entities/investment_entity.dart';
import '../../domain/entities/reserve_movement_entity.dart';
import '../../domain/entities/settings_entity.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/entities/transfer_entity.dart';
import '../../core/utils/date_utils.dart';

class DashboardService {
  DashboardStats compute({
    required List<TransactionEntity> transactions,
    required List<InvestmentEntity> investments,
    required List<ReserveWithMovements> reservesWithMovements,
    required List<TransferEntity> transfers,
    required SettingsEntity settings,
    required DateTime selectedMonth,
  }) {
    final monthStart = AppDateUtils.startOfMonth(selectedMonth);
    final monthEnd = AppDateUtils.endOfMonth(selectedMonth);

    final allMonths = MonthlyBalanceCalculator.compute(
      transactions: transactions,
      transfers: transfers,
      fromMonth: _earliestMonth(transactions, transfers, selectedMonth),
      toMonth: selectedMonth,
    );

    final currentSummary = allMonths.isNotEmpty ? allMonths.last : null;
    final openingBalance = currentSummary?.openingBalance ?? 0;
    final closingBalance = currentSummary?.closingBalance ?? 0;

    final monthTransactions = transactions.where((t) {
      return !t.date.isBefore(monthStart) && !t.date.isAfter(monthEnd);
    }).toList();

    final monthlyIncome = monthTransactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + t.value);

    final monthlyExpense = monthTransactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + t.value);

    final monthlySavings = monthlyIncome - monthlyExpense;

    final investmentTotals = PatrimonyCalculator.investments(
      investments: investments,
      cdiRate: settings.cdiRate,
    );
    final totalInvestments = investmentTotals.total;
    final totalYield = investmentTotals.accumulatedYield;

    final reserveTotals = PatrimonyCalculator.reserves(
      reserves: reservesWithMovements,
      cdiRate: settings.cdiRate,
    );
    final totalReserves = reserveTotals.total;
    final reserveYield = reserveTotals.accumulatedYield;

    final expensesByCategory = <String, double>{};
    final incomeByCategory = <String, double>{};

    for (final t in monthTransactions) {
      if (t.type == TransactionType.expense) {
        expensesByCategory[t.category] =
            (expensesByCategory[t.category] ?? 0) + t.value;
      } else if (t.type == TransactionType.income) {
        incomeByCategory[t.category] =
            (incomeByCategory[t.category] ?? 0) + t.value;
      }
    }

    final monthlyTrend = allMonths
        .map((m) => MonthlyTrendPoint(
              month: m.month,
              income: m.income,
              expense: m.expense,
              balance: m.closingBalance,
            ))
        .toList();

    final recent = transactions.take(10).toList();

    return DashboardStats(
      totalBalance: closingBalance,
      monthlyIncome: monthlyIncome,
      monthlyExpense: monthlyExpense,
      monthlySavings: monthlySavings,
      availableBalance: closingBalance,
      totalInvestments: totalInvestments,
      totalReserves: totalReserves,
      netWorth: closingBalance + totalReserves + totalInvestments,
      investmentYield: totalYield,
      reserveYield: reserveYield,
      openingBalance: openingBalance,
      recentTransactions: recent,
      expensesByCategory: expensesByCategory,
      incomeByCategory: incomeByCategory,
      monthlyTrend: monthlyTrend,
    );
  }

  StatisticsSummary computeStatistics({
    required List<TransactionEntity> transactions,
    required List<InvestmentEntity> investments,
    required List<ReserveWithMovements> reservesWithMovements,
    required List<TransferEntity> transfers,
    required SettingsEntity settings,
  }) {
    final expenses = transactions.where((t) => t.type == TransactionType.expense);
    final incomes = transactions.where((t) => t.type == TransactionType.income);

    TransactionEntity? largestExpense;
    TransactionEntity? largestIncome;

    for (final t in expenses) {
      if (largestExpense == null || t.value > largestExpense.value) {
        largestExpense = t;
      }
    }

    for (final t in incomes) {
      if (largestIncome == null || t.value > largestIncome.value) {
        largestIncome = t;
      }
    }

    final now = DateTime.now();
    final fromMonth = _earliestMonth(transactions, transfers, now);
    final summaries = MonthlyBalanceCalculator.compute(
      transactions: transactions,
      transfers: transfers,
      fromMonth: fromMonth,
      toMonth: now,
    );

    final avgExpense = summaries.isEmpty
        ? 0.0
        : summaries.map((m) => m.expense).reduce((a, b) => a + b) /
            summaries.length;

    final avgSavings = summaries.isEmpty
        ? 0.0
        : summaries.map((m) => m.savings).reduce((a, b) => a + b) /
            summaries.length;

    final expenseByCat = <String, double>{};
    final incomeByCat = <String, double>{};

    for (final t in transactions) {
      if (t.type == TransactionType.expense) {
        expenseByCat[t.category] = (expenseByCat[t.category] ?? 0) + t.value;
      } else if (t.type == TransactionType.income) {
        incomeByCat[t.category] = (incomeByCat[t.category] ?? 0) + t.value;
      }
    }

    final investmentTotals = PatrimonyCalculator.investments(
      investments: investments,
      cdiRate: settings.cdiRate,
    );
    final totalInvested = investmentTotals.principal;
    final totalYield = investmentTotals.accumulatedYield;
    final totalInvestmentsValue = investmentTotals.total;

    final reserveTotals = PatrimonyCalculator.reserves(
      reserves: reservesWithMovements,
      cdiRate: settings.cdiRate,
    );
    final totalReserves = reserveTotals.total;
    final reserveYield = reserveTotals.accumulatedYield;

    final currentBalance = summaries.isEmpty ? 0.0 : summaries.last.closingBalance;
    final netWorth = currentBalance + totalInvestmentsValue + totalReserves;

    return StatisticsSummary(
      largestExpense: largestExpense,
      largestIncome: largestIncome,
      averageMonthlyExpense: avgExpense,
      averageMonthlySavings: avgSavings,
      topExpenseCategory: _topCategory(expenseByCat),
      topIncomeCategory: _topCategory(incomeByCat),
      totalInvested: totalInvested,
      totalYield: totalYield,
      totalReserves: totalReserves,
      reserveYield: reserveYield,
      netWorth: netWorth,
      currentBalance: currentBalance,
    );
  }

  DateTime _earliestMonth(
    List<TransactionEntity> transactions,
    List<TransferEntity> transfers,
    DateTime selectedMonth,
  ) =>
      PatrimonyCalculator.earliestMonth(transactions, transfers, selectedMonth);

  String _topCategory(Map<String, double> map) {
    if (map.isEmpty) return '-';
    return map.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }
}
