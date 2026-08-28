import '../../domain/entities/investment_entity.dart';
import '../../domain/entities/reserve_movement_entity.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/entities/transfer_entity.dart';
import 'investment_calculator.dart';
import 'monthly_balance_calculator.dart';
import 'reserve_calculator.dart';

/// Totais de patrimônio em um instante. Fonte única para saldo, caixinhas e
/// investimentos, evitando fórmulas divergentes entre dashboard, relatórios,
/// transferências e Formigueiro.
class PatrimonySnapshot {
  const PatrimonySnapshot({
    required this.balance,
    required this.reserves,
    required this.investments,
    required this.reserveYield,
    required this.investmentYield,
    required this.investedPrincipal,
  });

  final double balance;
  final double reserves;
  final double investments;
  final double reserveYield;
  final double investmentYield;
  final double investedPrincipal;

  double get netWorth => balance + reserves + investments;

  double get totalYield => reserveYield + investmentYield;
}

abstract final class PatrimonyCalculator {
  /// Saldo disponível acumulado até [until] (padrão: agora).
  static double balance({
    required List<TransactionEntity> transactions,
    required List<TransferEntity> transfers,
    DateTime? until,
  }) {
    if (transactions.isEmpty && transfers.isEmpty) return 0;

    final reference = until ?? DateTime.now();
    final summaries = MonthlyBalanceCalculator.compute(
      transactions: transactions,
      transfers: transfers,
      fromMonth: earliestMonth(transactions, transfers, reference),
      toMonth: reference,
    );

    if (summaries.isEmpty) return 0;
    return summaries.last.closingBalance;
  }

  /// Valor atualizado das caixinhas, considerando aportes, resgates e rendimento.
  static ({double total, double accumulatedYield}) reserves({
    required List<ReserveWithMovements> reserves,
    required double cdiRate,
    DateTime? referenceDate,
  }) {
    var total = 0.0;
    var accumulated = 0.0;

    for (final item in reserves) {
      final result = ReserveCalculator.compute(
        reserve: item.reserve,
        movements: item.movements,
        cdiRate: cdiRate,
        referenceDate: referenceDate,
      );
      total += result.currentValue;
      accumulated += result.totalAccumulated;
    }

    return (total: total, accumulatedYield: accumulated);
  }

  /// Valor atualizado da carteira de investimentos.
  ///
  /// Ativos com rendimento configurado (% do CDI ou taxa fixa) são projetados
  /// pelo [InvestmentCalculator]; os demais usam o valor já registrado.
  static ({double total, double accumulatedYield, double principal}) investments({
    required List<InvestmentEntity> investments,
    required double cdiRate,
    DateTime? referenceDate,
  }) {
    var total = 0.0;
    var accumulated = 0.0;
    var principal = 0.0;

    for (final investment in investments) {
      principal += investment.initialValue;

      final hasYieldConfig =
          investment.cdiPercent != null || investment.fixedRate != null;

      if (hasYieldConfig) {
        final result = InvestmentCalculator.calculate(
          initialValue: investment.initialValue,
          startDate: investment.startDate,
          cdiRate: cdiRate,
          cdiPercent: investment.cdiPercent,
          fixedRate: investment.fixedRate,
          monthlyContribution: investment.monthlyContribution,
          referenceDate: referenceDate,
        );
        total += result.currentValue;
        accumulated += result.totalAccumulated;
      } else {
        total += investment.currentValue;
      }
    }

    return (total: total, accumulatedYield: accumulated, principal: principal);
  }

  static PatrimonySnapshot compute({
    required List<TransactionEntity> transactions,
    required List<TransferEntity> transfers,
    required List<ReserveWithMovements> reservesWithMovements,
    required List<InvestmentEntity> investments,
    required double cdiRate,
    DateTime? until,
  }) {
    final reserveTotals = reserves(
      reserves: reservesWithMovements,
      cdiRate: cdiRate,
      referenceDate: until,
    );
    final investmentTotals = PatrimonyCalculator.investments(
      investments: investments,
      cdiRate: cdiRate,
      referenceDate: until,
    );

    return PatrimonySnapshot(
      balance: balance(
        transactions: transactions,
        transfers: transfers,
        until: until,
      ),
      reserves: reserveTotals.total,
      investments: investmentTotals.total,
      reserveYield: reserveTotals.accumulatedYield,
      investmentYield: investmentTotals.accumulatedYield,
      investedPrincipal: investmentTotals.principal,
    );
  }

  static DateTime earliestMonth(
    List<TransactionEntity> transactions,
    List<TransferEntity> transfers,
    DateTime fallback,
  ) {
    final dates = <DateTime>[
      ...transactions.map((t) => t.date),
      ...transfers.map((t) => t.date),
    ];
    if (dates.isEmpty) return fallback;
    final earliest = dates.reduce((a, b) => a.isBefore(b) ? a : b);
    return DateTime(earliest.year, earliest.month);
  }
}
