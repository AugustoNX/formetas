import '../../core/utils/investment_calculator.dart';
import '../../core/utils/monthly_balance_calculator.dart';
import '../../domain/entities/dashboard_entity.dart';
import '../../domain/entities/investment_entity.dart';
import '../../domain/entities/reserve_movement_entity.dart';
import '../../core/utils/reserve_calculator.dart';
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

    var totalInvestments = 0.0;
    var totalYield = 0.0;

    for (final inv in investments) {
      final hasYieldConfig = inv.cdiPercent != null || inv.fixedRate != null;
      if (hasYieldConfig) {
        final result = InvestmentCalculator.calculate(
          initialValue: inv.initialValue,
          startDate: inv.startDate,
          cdiRate: settings.cdiRate,
          cdiPercent: inv.cdiPercent,
          fixedRate: inv.fixedRate,
          monthlyContribution: inv.monthlyContribution,
        );
        totalInvestments += result.currentValue;
        totalYield += result.totalAccumulated;
      } else {
        totalInvestments += inv.currentValue;
      }
    }

    var totalReserves = 0.0;
    var reserveYield = 0.0;

    for (final item in reservesWithMovements) {
      final result = ReserveCalculator.compute(
        reserve: item.reserve,
        movements: item.movements,
        cdiRate: settings.cdiRate,
      );
      totalReserves += result.currentValue;
      reserveYield += result.totalAccumulated;
    }

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
      netWorth: closingBalance + totalReserves,
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

    final months = AppDateUtils.last12Months();
    final summaries = MonthlyBalanceCalculator.compute(
      transactions: transactions,
      transfers: transfers,
      fromMonth: months.first,
      toMonth: months.last,
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

    var totalInvested = 0.0;
    var totalYield = 0.0;
    var totalInvestmentsValue = 0.0;

    for (final inv in investments) {
      final hasYieldConfig = inv.cdiPercent != null || inv.fixedRate != null;
      if (hasYieldConfig) {
        final result = InvestmentCalculator.calculate(
          initialValue: inv.initialValue,
          startDate: inv.startDate,
          cdiRate: settings.cdiRate,
          cdiPercent: inv.cdiPercent,
          fixedRate: inv.fixedRate,
          monthlyContribution: inv.monthlyContribution,
        );
        totalInvested += inv.initialValue;
        totalYield += result.totalAccumulated;
        totalInvestmentsValue += result.currentValue;
      } else {
        totalInvested += inv.initialValue;
        totalInvestmentsValue += inv.currentValue;
      }
    }

    var totalReserves = 0.0;
    var reserveYield = 0.0;

    for (final item in reservesWithMovements) {
      final result = ReserveCalculator.compute(
        reserve: item.reserve,
        movements: item.movements,
        cdiRate: settings.cdiRate,
      );
      totalReserves += result.currentValue;
      reserveYield += result.totalAccumulated;
    }

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
  ) {
    final dates = <DateTime>[
      ...transactions.map((t) => t.date),
      ...transfers.map((t) => t.date),
    ];
    if (dates.isEmpty) return selectedMonth;
    final earliest = dates.reduce((a, b) => a.isBefore(b) ? a : b);
    return AppDateUtils.startOfMonth(earliest);
  }

  String _topCategory(Map<String, double> map) {
    if (map.isEmpty) return '-';
    return map.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }
}
