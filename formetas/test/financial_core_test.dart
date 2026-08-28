import 'package:flutter_test/flutter_test.dart';
import 'package:formetas/core/utils/patrimony_calculator.dart';
import 'package:formetas/domain/entities/investment_entity.dart';
import 'package:formetas/domain/entities/reserve_entity.dart';
import 'package:formetas/domain/entities/reserve_movement_entity.dart';
import 'package:formetas/domain/entities/settings_entity.dart';
import 'package:formetas/domain/entities/transaction_entity.dart';
import 'package:formetas/domain/entities/transfer_entity.dart';
import 'package:formetas/domain/services/dashboard_service.dart';

/// Garante que a camada de gamificação não mexeu nas regras financeiras.
void main() {
  final service = DashboardService();
  final month = DateTime(2026, 8);
  final day = DateTime(2026, 8, 10);
  const settings = SettingsEntity();

  TransactionEntity tx(TransactionType type, double value, {String id = 'tx'}) {
    return TransactionEntity(
      id: id,
      userId: 'u1',
      type: type,
      category: 'Geral',
      value: value,
      description: '',
      date: day,
      createdAt: day,
    );
  }

  final reserves = [
    ReserveWithMovements(
      reserve: ReserveEntity(
        id: 'r1',
        userId: 'u1',
        name: 'Reserva',
        type: ReserveType.caixinha,
        initialValue: 2000,
        currentValue: 2000,
        startDate: day,
        createdAt: day,
      ),
      movements: const [],
    ),
  ];

  final investments = [
    InvestmentEntity(
      id: 'i1',
      userId: 'u1',
      name: 'CDB',
      type: InvestmentType.cdb,
      initialValue: 1500,
      currentValue: 1500,
      startDate: day,
      createdAt: day,
    ),
  ];

  final transactions = [
    tx(TransactionType.income, 5000, id: 'a'),
    tx(TransactionType.expense, 1200, id: 'b'),
    tx(TransactionType.investment, 300, id: 'c'),
  ];

  final transfers = [
    TransferEntity(
      id: 't1',
      userId: 'u1',
      amount: 500,
      fromType: WalletType.balance,
      toType: WalletType.reserve,
      toId: 'r1',
      date: day,
      createdAt: day,
    ),
  ];

  test('saldo desconta despesas, aportes e transferências que saem', () {
    final stats = service.compute(
      transactions: transactions,
      investments: const [],
      reservesWithMovements: const [],
      transfers: transfers,
      settings: settings,
      selectedMonth: month,
    );

    expect(stats.totalBalance, 5000 - 1200 - 300 - 500);
    expect(stats.monthlyIncome, 5000);
    expect(stats.monthlyExpense, 1200);
    expect(stats.monthlySavings, 3800);
  });

  test('patrimônio soma saldo, caixinhas e investimentos', () {
    final stats = service.compute(
      transactions: transactions,
      investments: investments,
      reservesWithMovements: reserves,
      transfers: transfers,
      settings: settings,
      selectedMonth: month,
    );

    expect(
      stats.netWorth,
      closeTo(stats.totalBalance + stats.totalReserves + stats.totalInvestments, 0.01),
    );
  });

  test('dashboard e relatórios chegam ao mesmo patrimônio', () {
    final stats = service.compute(
      transactions: transactions,
      investments: investments,
      reservesWithMovements: reserves,
      transfers: transfers,
      settings: settings,
      selectedMonth: month,
    );
    final statistics = service.computeStatistics(
      transactions: transactions,
      investments: investments,
      reservesWithMovements: reserves,
      transfers: transfers,
      settings: settings,
    );

    expect(statistics.netWorth, closeTo(stats.netWorth, 0.01));
    expect(statistics.currentBalance, closeTo(stats.totalBalance, 0.01));
  });

  test('o cálculo central de patrimônio confere com o dashboard', () {
    final stats = service.compute(
      transactions: transactions,
      investments: investments,
      reservesWithMovements: reserves,
      transfers: transfers,
      settings: settings,
      selectedMonth: month,
    );

    // O saldo é do mês selecionado; caixinhas e investimentos são sempre
    // atualizados até hoje, exatamente como o dashboard sempre fez.
    final balance = PatrimonyCalculator.balance(
      transactions: transactions,
      transfers: transfers,
      until: month,
    );
    final reserveTotals = PatrimonyCalculator.reserves(
      reserves: reserves,
      cdiRate: settings.cdiRate,
    );
    final investmentTotals = PatrimonyCalculator.investments(
      investments: investments,
      cdiRate: settings.cdiRate,
    );

    expect(balance, closeTo(stats.totalBalance, 0.01));
    expect(reserveTotals.total, closeTo(stats.totalReserves, 0.01));
    expect(investmentTotals.total, closeTo(stats.totalInvestments, 0.01));
    expect(
      balance + reserveTotals.total + investmentTotals.total,
      closeTo(stats.netWorth, 0.01),
    );
  });

  test('transferência de volta ao saldo devolve o valor', () {
    final back = [
      ...transfers,
      TransferEntity(
        id: 't2',
        userId: 'u1',
        amount: 500,
        fromType: WalletType.reserve,
        toType: WalletType.balance,
        fromId: 'r1',
        date: day,
        createdAt: day,
      ),
    ];

    final balance = PatrimonyCalculator.balance(
      transactions: transactions,
      transfers: back,
      until: month,
    );

    expect(balance, 5000 - 1200 - 300);
  });
}
